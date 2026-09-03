/// Menú: la diaria y el modo libre.
///
/// La diaria va primero y ocupa más: es el juego. El modo libre está debajo, a
/// mano para quien ya hizo la de hoy o quiere practicar sin que cuente.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';

import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../nona_config.dart';
import 'settings_tab.dart';
import '../services/progress_controller.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/result_overlay.dart' show difficultyLabel;
import 'game_screen.dart';
import 'practice_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.daily,
    required this.practice,
    required this.locale,
    required this.theme,
    required this.progress,
    required this.auth,
    required this.friends,
    required this.purchases,
    required this.notifications,
    required this.prefs,
    required this.leaderboard,
    this.banner,
  });

  final DailyController daily;
  final PracticeController practice;
  final LocaleController locale;
  final ThemeController theme;
  final ProgressController progress;
  final AuthController auth;
  final FriendsService friends;
  final PurchaseService purchases;
  final NotificationsService notifications;

  /// Hace falta para poder LIMPIAR lo que Nona guarda al salirse de la cuenta.
  final SharedPreferences prefs;

  /// De dónde salen los puntos de la clasificación. `null` sin Firebase.
  final LeaderboardSource? leaderboard;

  /// El banner de anuncios, ya construido.
  ///
  /// Se INYECTA en vez de montarse aquí por las pruebas: `AdBanner` pregunta su
  /// tamaño por un canal de plataforma que en una prueba de widgets no existe,
  /// y montarlo dentro reventaría cualquier prueba que monte el menú. Quien lo
  /// construye es `main.dart`, una sola vez; las pruebas pasan `null`.
  final Widget? banner;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Qué se ve dentro de la pestaña Jugar.
enum _Play { menu, daily, practice }

class _HomeScreenState extends State<HomeScreen> {
  SendaTab _tab = SendaTab.play;
  _Play _play = _Play.menu;

  void _goPlay(_Play v) => setState(() {
    _play = v;
    _tab = SendaTab.play;
  });

  /// Hay tablero delante dentro de Jugar. Suelto porque lo necesita también
  /// `SendaBackToMenu`, que pone por su cuenta el término de la pestaña:
  /// contarlo dos veces haría que el mismo argumento significara cosas
  /// distintas en cada juego.
  bool get _boardUp => _play != _Play.menu;

  /// Se está jugando: ni menú ni otras pestañas. La barra se va justo aquí.
  bool get _inGame => _tab == SendaTab.play && _boardUp;

  @override
  void initState() {
    super.initState();
    widget.notifications.abrirAmigosPara.addListener(_abrirAmigos);
    // **Y una vez más al montarse.** Con la app CERRADA, el toque llega por
    // `getInitialMessage`, que resuelve antes de que esta pantalla exista: el
    // valor ya está puesto y el listener nunca se dispara. Sin esto se perdería
    // justo el caso más común —tocar el aviso sin tener la app abierta—, y sin
    // más síntoma que «no pasa nada».
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirAmigos());
  }

  @override
  void dispose() {
    widget.notifications.abrirAmigosPara.removeListener(_abrirAmigos);
    super.dispose();
  }

  /// Lleva a Amigos, señalando a quien provocó el aviso.
  ///
  /// Nona escuchaba los toques (`wireInviteTaps`) pero no leía el resultado, así
  /// que tocar «X te agregó» abría la app y ahí se acababa. Ahora aterriza en la
  /// tarjeta correcta, parpadeando: buscar en una lista qué te habían dicho es
  /// exactamente lo que el aviso venía a ahorrar.
  void _abrirAmigos() {
    final uid = widget.notifications.abrirAmigosPara.value;
    if (uid == null || !mounted) return;
    // Se consume ANTES de navegar. Si no, al volver atrás el listener dispara
    // otra vez y la pantalla se reabre sola.
    widget.notifications.abrirAmigosPara.value = null;
    // Amigos cuelga de la Social, así que la pestaña se mueve también: cerrar
    // la pantalla completa tiene que dejar debajo el sitio del que salió, no
    // el tablero.
    setState(() => _tab = SendaTab.social);
    // Sin sesión no hay Amigos que enseñar —ni amistades cargadas—, y una lista
    // vacía no explica nada. La Social ya invita a entrar; ahí se queda. Pasa
    // con un aviso viejo en la bandeja después de cerrar sesión.
    if (!widget.auth.signedIn) return;
    Navigator.of(context)
        .push(_rutaDeAmigos(destacar: uid.isEmpty ? null : uid));
  }

  /// La única forma de abrir Amigos. Suelta porque la abren dos sitios —el
  /// icono de persona de la Social y el toque de un aviso— y dos copias de esta
  /// construcción se separan: la que se toca a mano quedaría bien y la del
  /// aviso llevaría meses abriendo otra cosa sin que nadie lo note.
  Route<void> _rutaDeAmigos({String? destacar}) => MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => SendaFriendsScreen(
      friends: widget.friends,
      gameId: nonaGameId,
      notifications: widget.notifications,
      // Las invitaciones cruzadas necesitan la Function y las reglas
      // desplegadas. Hasta entonces la sección no se pinta: un "+" que no
      // envía nada promete algo que no cumple.
      invitesEnabled: kInvitesEnabled,
      destacar: destacar,
    ),
  );

  @override
  Widget build(BuildContext context) {
    // **El gesto de volver saca del tablero al menú.**
    //
    // Lo que se juega es un estado dentro de esta pantalla y no una ruta
    // empujada —a propósito, para que ir a Social a mitad de puzle no reinicie
    // el tablero ni el cronómetro—, así que el gesto no tenía nada que cerrar
    // y en Android sacaba al escritorio. La regla vive en el paquete: es la
    // misma en todos los juegos.
    return SendaBackToMenu(
      pestana: _tab,
      tableroDelante: _boardUp,
      onMenu: () => _goPlay(_Play.menu),
      child: Scaffold(
        // El aviso flota POR ENCIMA, en un Stack, y no empuja nada. Un banner
        // que hiciera reflow movería el tablero bajo los dedos de quien está
        // rellenando una casilla.
        body: Stack(
          children: [
            // IndexedStack y no un `switch`: mantiene VIVAS las tres pestañas,
            // así que ir a Más a mitad de un puzle y volver no reinicia el
            // tablero ni el cronómetro. Con un switch, cada cambio de pestaña
            // destruiría la partida en curso.
            IndexedStack(
              index: SendaTab.values.indexOf(_tab),
              children: [
                switch (_play) {
                  _Play.menu => _Menu(
                    daily: widget.daily,
                    locale: widget.locale,
                    progress: widget.progress,
                    onDaily: () => _goPlay(_Play.daily),
                    onPractice: () {
                      // Se carga al entrar, no al arrancar la app: generar un puzle
                      // en el arranque en frío retrasaría la diaria, que es a lo que
                      // viene la gente.
                      if (widget.practice.board == null) widget.practice.load();
                      _goPlay(_Play.practice);
                    },
                  ),
                  _Play.daily => GameScreen(
                    controller: widget.daily,
                    progress: widget.progress,
                    theme: widget.theme,
                    onExit: () => _goPlay(_Play.menu),
                    onPractice: () {
                      if (widget.practice.board == null) widget.practice.load();
                      _goPlay(_Play.practice);
                    },
                  ),
                  _Play.practice => PracticeScreen(
                    controller: widget.practice,
                    theme: widget.theme,
                    onExit: () => _goPlay(_Play.menu),
                  ),
                },

                // Lo social es lo único que necesita cuenta: sin ella no hay con
                // quién compararse.
                //
                // Con sesión, la pestaña lleva a Amigos. La CLASIFICACIÓN todavía no
                // —necesita `LeaderboardService`, que es de la fase B—, pero enseñar
                // la invitación a entrar a alguien que YA entró sería pedirle que
                // haga algo que acaba de hacer.
                //
                // `onInvite` va nulo a propósito hasta el guardarraíl #3: con un solo
                // `fcmToken` por persona, una invitación desde Nona llega a la app
                // que registró el token la última vez — una moneda al aire.
                // La pestaña Social es el MARCADOR. Las solicitudes y las
                // invitaciones viven detrás del icono de persona, en Amigos, que se
                // abre como pantalla completa (§15).
                ListenableBuilder(
                  listenable: Listenable.merge([widget.auth, widget.progress]),
                  builder: (context, _) =>
                      widget.auth.signedIn && widget.leaderboard != null
                      ? SendaLeaderboardScreen(
                          friends: widget.friends,
                          leaderboard: widget.leaderboard!,
                          gameId: nonaGameId,
                          myUid: widget.auth.user!.uid,
                          mySummary: widget.progress.summaryAsOf(
                            DateTime.now(),
                          ),
                          // Tu fila sale con tu nombre, como las de tus amigos. La
                          // identidad la aporta Nona porque ya la tiene en la
                          // sesión: pedírsela a Firestore sería pagar una lectura
                          // por algo que está en memoria.
                          myName: widget.auth.displayName,
                          myUsername: widget.auth.username,
                          myAvatar: widget.auth.avatarId,
                          myCountry: widget.auth.country,
                          // Sin nadie que señalar: aquí se entra a mirar, no
                          // porque te hayan avisado de algo.
                          onOpenFriends: () =>
                              Navigator.of(context).push(_rutaDeAmigos()),
                        )
                      : SendaSocialSignedOut(onSignIn: widget.auth.exitGuest),
                ),

                SettingsTab(
                  practice: widget.practice,
                  auth: widget.auth,
                  friends: widget.friends,
                  purchases: widget.purchases,
                  notifications: widget.notifications,
                  prefs: widget.prefs,
                  locale: widget.locale,
                  theme: widget.theme,
                  progress: widget.progress,
                ),
              ],
            ),
            // Nona recogía los toques de aviso pero no lo que llega con la app
            // DELANTE: el paquete lo publica en `avisoEnPantalla` y nadie lo
            // pintaba. Y el sistema tampoco —con la app en primer plano iOS no
            // dibuja el banner por su cuenta—, así que una solicitud de amistad
            // que llegaba jugando no se veía en ninguna parte.
            _AvisoFlotante(
              aviso: widget.notifications.avisoEnPantalla,
              onTap: (from) {
                widget.notifications.avisoEnPantalla.value = null;
                // Cadena vacía y no null: abre Amigos sin señalar a nadie. El
                // servidor puede no mandar `fromUid` —o mandarlo de un tipo que
                // no lleva a una tarjeta—, y en ese caso llevar a la lista sigue
                // siendo mejor que no llevar a ningún sitio.
                widget.notifications.abrirAmigosPara.value = from ?? '';
              },
            ),
          ],
        ),
        // Abajo: el banner y, debajo, la barra de pestañas O el hueco del gesto.
        //
        // Mientras se juega la barra **se va del árbol**, no se atenúa: es el
        // alto que le hace falta al tablero, y con `hidden` seguiría ocupándolo.
        // Que dependa de la vista y no de un gesto es lo que hace que sea seguro:
        // la vista solo cambia al navegar, así que nada se mueve bajo los dedos a
        // mitad de una partida.
        //
        // Al quitarla hay que devolver a mano el hueco de la barra de gestos, que
        // hasta ahora cubría ella; si no, el numpad queda debajo de la raya.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En pantallas muy bajas el banner se sacrifica: el tablero manda.
            if (widget.banner != null &&
                MediaQuery.sizeOf(context).height >= 700)
              widget.banner!,
            if (_inGame)
              Container(
                height: MediaQuery.paddingOf(context).bottom,
                color: NonaColors.appBg,
              )
            else
              // Escucha aquí y no en el `build` entero: una solicitud que llega
              // mientras alguien juega no tiene por qué reconstruir el tablero.
              ListenableBuilder(
                listenable: widget.friends,
                builder: (context, _) => SendaBottomNav(
                  current: _tab,
                  onSelect: (t) => setState(() => _tab = t),
                  // Lo mismo que enciende el punto de la cabecera de Social:
                  // nacen y mueren juntos, y no se apagan por MIRAR.
                  alert: widget.friends.hasPendingIncoming,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.daily,
    required this.locale,
    required this.progress,
    required this.onDaily,
    required this.onPractice,
  });

  final DailyController daily;
  final LocaleController locale;
  final ProgressController progress;
  final VoidCallback onDaily;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([daily, progress]),
          builder: (context, _) {
            final done = daily.isComplete;
            final l = L.of(context);
            // La racha VIGENTE, no el contador guardado: si el último día
            // terminado no es ni hoy ni ayer, ya está rota.
            final streak = progress.streakAsOf(DateTime.now());

            return Center(
              child: ConstrainedBox(
                // 520 es el de CINCO (`Adaptive.gameMaxWidth`). En tablet el
                // menú no se estira: se queda de este ancho y centrado.
                constraints: const BoxConstraints(maxWidth: 520),
                child: LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: c.maxHeight - 28),
                      child: Column(
                        // Centrado vertical, que es lo que hace que esto
                        // funcione igual en un iPhone SE y en un iPad sin
                        // casos especiales.
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),
                          // El logo de Nona (Claude Design, 28-8-2026): Figtree
                          // Light con tracking amplio, no una imagen — así sigue
                          // coloreado por el acento del tema, igual que antes.
                          //
                          // letterSpacing e fontWeight leídos del diseño: la
                          // fuente y los valores de tracking (32px sobre el
                          // título, 11px sobre el subtítulo) los dio la propia
                          // sesión de diseño, a la escala en la que se dibujó el
                          // logo (~195px de título) — proporción
                          // letterSpacing/fontSize ≈0.1636. Al agrandar el
                          // título (pedido de André, 28-8-2026) el tracking
                          // escala CON él para no perder esa proporción; la
                          // banda de alto crece igual para que el texto no se
                          // recorte contra el borde.
                          SizedBox(
                            // 80 y no 112: el doble del original se probó y se
                            // descartó por tamaño (André, 3-9-2026). Éste sube
                            // el logo sin que se coma el menú.
                            height: 118,
                            child: Center(
                              child: Text(
                                // En VERSALES, como el diseño: no es un
                                // adorno tipográfico — con Figtree Light el
                                // contraste mayúscula/minúscula queda débil, y
                                // todo en mayúsculas es lo que sostiene la
                                // lectura del logo a este tamaño.
                                l.appName.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 80,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 13.1,
                                  color: NonaColors.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            // En VERSALITAS como CINCO. Se hace aquí y no en
                            // el ARB para no obligar a cada traducción a
                            // acordarse de las mayúsculas.
                            l.appTagline.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 3.6,
                              color: NonaColors.muted,
                            ),
                          ),
                          if (streak > 0) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: NonaColors.accentChip,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                l.menuStreak(streak),
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: NonaColors.accent,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 40),
                          _ModeCard(
                            title: l.menuDaily,
                            subtitle: daily.difficulty == null
                                ? l.menuLoading
                                : done
                                ? l.menuDailyDone(
                                    difficultyLabel(context, daily.difficulty!),
                                  )
                                : l.menuDailyToday(
                                    difficultyLabel(context, daily.difficulty!),
                                  ),
                            icon: Icons.today_rounded,
                            // La recomendada AHORA: la diaria si no se ha
                            // jugado, el modo práctica si ya está hecha.
                            primary: !done,
                            trailing: done
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF3DDC84),
                                    size: 22,
                                  )
                                : null,
                            onTap: onDaily,
                          ),
                          const SizedBox(height: 12),
                          _ModeCard(
                            title: l.menuPractice,
                            subtitle: l.menuPracticeSubtitle,
                            icon: Icons.all_inclusive_rounded,
                            primary: done,
                            onTap: onPractice,
                          ),
                          // 8 de separación + 40 de sesgo. La columna va
                          // centrada, así que un hueco al final empuja el
                          // bloque visible hacia arriba la MITAD: 20 pt.
                          // Centrado óptico — el contenido centrado de verdad
                          // se lee un poco bajo. Copiado de CINCO con su
                          // motivo.
                          const SizedBox(height: 8 + 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tarjeta de modo de juego. Copiada de CINCO con sus medidas: radio 20,
/// relleno 16x18, caja de icono de 46 con radio 14, título de 18 en w800 y
/// subtítulo de 13,5.
///
/// La recomendada se distingue con **borde e icono en acento**, no rellenando
/// la tarjeta de color: rellenarla chocaba con las superficies oscuras del
/// resto (lección de CINCO, copiada con su motivo). Por eso el título va
/// siempre en el color de texto normal, también en la primaria.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primary,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool primary;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NonaColors.sheet,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primary ? NonaColors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primary
                      ? NonaColors.accentDeep
                      : NonaColors.accentChip,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: primary ? NonaColors.accent : NonaColors.muted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23.5,
                        fontWeight: FontWeight.w800,
                        color: NonaColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 17.5,
                        color: NonaColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Icon(
                    Icons.chevron_right_rounded,
                    color: primary ? NonaColors.accent : NonaColors.muted,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El aviso que llega con la app DELANTE.
///
/// Nona ya recogía los toques (`wireInviteTaps`) y ya sabía llevar a Amigos,
/// pero de este canal no leía nada: el paquete publica el aviso en
/// `avisoEnPantalla` y aquí no había quien lo pintara. Y el sistema tampoco lo
/// pinta —con la app en primer plano iOS no dibuja el banner por su cuenta, y
/// el paquete no llama a `setForegroundNotificationPresentationOptions`—, así
/// que una solicitud de amistad que llegaba jugando **no se veía en ninguna
/// parte**. Sin error y sin registro, como los otros dos de esta tanda.
///
/// Calcado del de CINCO, que es la referencia de la familia. El paquete publica
/// la clase de datos pero no el widget, a propósito: dónde va el banner lo
/// decide cada juego.
class _AvisoFlotante extends StatefulWidget {
  const _AvisoFlotante({required this.aviso, required this.onTap});

  final ValueNotifier<AvisoEnPantalla?> aviso;
  final void Function(String? from) onTap;

  @override
  State<_AvisoFlotante> createState() => _AvisoFlotanteState();
}

class _AvisoFlotanteState extends State<_AvisoFlotante> {
  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    widget.aviso.addListener(_programarCierre);
  }

  @override
  void dispose() {
    _cierre?.cancel();
    widget.aviso.removeListener(_programarCierre);
    super.dispose();
  }

  void _programarCierre() {
    _cierre?.cancel();
    if (widget.aviso.value == null) return;
    // Se va solo. Un aviso que hay que descartar a mano es una tarea más, y
    // encima tapando el tablero.
    _cierre = Timer(const Duration(seconds: 6), () {
      if (mounted) widget.aviso.value = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AvisoEnPantalla?>(
      valueListenable: widget.aviso,
      builder: (context, a, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: a == null
            ? const SizedBox.shrink()
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        Haptics.selection();
                        widget.onTap(a.from);
                      },
                      child: Ink(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: NonaColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: NonaColors.accent.withValues(alpha: .45),
                          ),
                          // Sombra, que CINCO no lleva: aquí el banner cae sobre
                          // el TABLERO, y un borde de 1 px compite con las rayas
                          // de la rejilla en vez de separarse de ellas.
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // El icono lo decide el TIPO. Fijo, un aviso de
                            // racha se pintaría con cara de solicitud de
                            // amistad: no falla, engaña — y así se aprende a
                            // ignorar el aviso.
                            Icon(
                              switch (a.tipo) {
                                'nudge' => Icons.notifications_active_rounded,
                                'streak_request' ||
                                'streak_started' ||
                                'streak_danger' =>
                                  Icons.local_fire_department_rounded,
                                _ => Icons.person_add_alt_1_rounded,
                              },
                              size: 20,
                              color: a.tipo.startsWith('streak')
                                  ? const Color(0xFFFFB454)
                                  : NonaColors.accent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    // El texto viene del servidor, ya traducido
                                    // al idioma de quien lo recibe. Por eso este
                                    // widget no toca el ARB: escribir aquí un
                                    // texto fijo sería el ÚNICO sitio de Nona
                                    // que no respeta el idioma elegido.
                                    a.titulo,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: NonaColors.text,
                                    ),
                                  ),
                                  if (a.cuerpo.isNotEmpty)
                                    Text(
                                      a.cuerpo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: NonaColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

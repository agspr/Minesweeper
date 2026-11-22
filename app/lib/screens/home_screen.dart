/// Menú: la diaria y el modo libre.
///
/// La diaria va primero y ocupa más: es el juego. El modo libre está debajo, a
/// mano para quien ya hizo la de hoy o quiere practicar sin que cuente.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/practice_controller.dart';
import '../game/day_key.dart';
import '../l10n/app_localizations.dart';

import 'package:juegos_senda/juegos_senda.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../nona_config.dart';
import 'settings_tab.dart';
import '../services/progress_controller.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/difficulty_label.dart';
import '../widgets/chip_de_racha_de_amigo.dart';
import '../widgets/main_menu_title_tiles.dart';
import '../widgets/sin_anuncios.dart';
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
    this.versiones,
    this.versionActual,
    this.ads,
    this.resenas,
    this.consent,
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

  /// Si hay una versión nueva publicada. Se inyecta solo en las pruebas, para
  /// darle una fuente y una versión propias; en la app se construye aquí.
  final SendaVersiones? versiones;

  /// La versión de este binario, leída en `main` antes de pintar. Es lo que
  /// deja decidir el aviso de versión nueva en el primer fotograma.
  final SendaVersionActual? versionActual;

  /// Los anuncios a pantalla completa. Null en las pruebas que no los miran:
  /// el de verdad habla con AdMob por un canal que en una prueba no existe.
  final AdManager? ads;

  /// La reseña en la tienda: «Califica Nona» en Más y la petición en los días
  /// de hito. Null en las pruebas que no la miran.
  final SendaResenas? resenas;

  /// Para «Privacidad de los anuncios» en Más. Null en las pruebas.
  final ConsentManager? consent;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Qué se ve dentro de la pestaña Jugar.
enum _Play { menu, daily, practice }

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  SendaTab _tab = SendaTab.play;
  _Play _play = _Play.menu;

  void _goPlay(_Play v) {
    setState(() {
      _play = v;
      _tab = SendaTab.play;
    });
    // Volver al menú relee el día: quien terminó la de ayer pasada la medianoche
    // vuelve a un menú que ya enseña la de hoy, y no a uno que la da por hecha.
    if (v == _Play.menu) unawaited(widget.daily.refreshForToday());
    _vigilarLaMedianocheSiHayMenu();
  }

  /// El aviso de medianoche, solo mientras se ve el MENÚ.
  ///
  /// Con una partida delante, no. Si la de ayer está a medias cuando dan las
  /// doce, recargar el día se la quitaría y ya no se podría terminar —lo midió
  /// la revisión—, y antes de este arreglo, con la app delante, sí se podía. Lo
  /// que el aviso arregla es que el MENÚ siguiera diciendo «Hecha» pasada la
  /// medianoche; para eso basta con vigilar mientras se ve el menú y releer el
  /// día al volver a él.
  void _vigilarLaMedianocheSiHayMenu() {
    if (_play == _Play.menu) {
      widget.daily.watchMidnight();
    } else {
      widget.daily.stopWatchingMidnight();
    }
  }

  /// La diaria de hoy ya está terminada en esta cuenta: en este teléfono, o en
  /// otro y lo dice el progreso.
  bool get _terminadaHoy {
    final hoy = dayKeyFor(DateTime.now());
    return (widget.daily.isComplete && widget.daily.dayKey == hoy) ||
        widget.progress.lastCompletedDay == hoy;
  }

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

    WidgetsBinding.instance.addObserver(this);
    _diaActual = widget.daily.dayKey;
    widget.daily.addListener(_alCambiarLaDiaria);
    _vigilarLaMedianocheSiHayMenu();
    // **Y una recarga al montarse, tras el primer fotograma.** El menú no
    // siempre está montado: tras borrar la cuenta o quitar Nona, la puerta de
    // sesión lo desmonta y lo vuelve a montar como invitado, sin estreno de
    // sesión que avise. Sin esto, el invitado veía como hecha la diaria de la
    // cuenta borrada, y abrirla la anotaba en un progreso que la siguiente
    // cuenta subía a su nube (medido en la revisión). Cubre también el menú que
    // se monta cuando el día ya cambió. La guardia de `reloadFromPrefs` la deja
    // en nada si lo guardado sigue siendo lo de hoy. Tras el fotograma y no en
    // el acto porque la carga avisa a sus oyentes en síncrono, y aquí caería en
    // mitad de una construcción.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.daily.reloadFromPrefs());
    });
    // Una vez por arranque, como CINCO. Nunca revienta: sin red, sin Firebase o
    // con el documento raro, el aviso simplemente no sale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_versiones.comprobar());
    });
    // Si se debe el anuncio del día —se cerró la app con la diaria recién
    // terminada—, se CARGA para la próxima pausa. Nunca se enseña al abrir. Y
    // a los 4 s, no antes: el primer arranque del SDK de anuncios bloquea el
    // hilo principal, y al abrir la app caería bajo los dedos de quien toca.
    final ads = widget.ads;
    if (ads != null && ads.debido.hay) {
      _precargaDebida = Timer(
        const Duration(seconds: 4),
        () => unawaited(ads.precargarLoDebido()),
      );
    }
  }

  Timer? _precargaDebida;

  /// Del APARATO, no de la cuenta: la X se guarda en `prefs` fuera de los
  /// prefijos de Nona, así que quien entra con otra cuenta en el mismo teléfono
  /// no vuelve a ver un aviso que ya se descartó.
  late final SendaVersiones _versiones =
      widget.versiones ??
      SendaVersiones(
        gameId: nonaGameId,
        firebaseReady: widget.auth.firebaseReady,
        prefs: widget.prefs,
        tiendaAndroid: nonaConfig.tiendaAndroid,
        tiendaIos: nonaConfig.tiendaIos,
        actualConocida: widget.versionActual,
      );

  /// «Actualizar»: la ficha de Nona en la tienda de esta plataforma.
  Future<void> _actualizar() async {
    final tienda = _versiones.tienda;
    if (tienda == null) return;
    await launchUrl(tienda, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    widget.notifications.abrirAmigosPara.removeListener(_abrirAmigos);
    WidgetsBinding.instance.removeObserver(this);
    widget.daily.removeListener(_alCambiarLaDiaria);
    widget.daily.stopWatchingMidnight();
    _precargaDebida?.cancel();
    // Solo el que es suyo: el de una prueba lo cierra quien lo creó.
    if (widget.versiones == null) _versiones.dispose();
    super.dispose();
  }

  /// El día se relee al volver a primer plano DESDE EL ARMAZÓN, no solo desde
  /// la pantalla de juego.
  ///
  /// Antes solo lo hacía `GameScreen`, y solo mientras estuviera montada: con
  /// el menú delante no lo hacía nadie. Un proceso que sobrevive a la noche
  /// —lo normal en un teléfono— dejaba el menú enseñando la diaria de ayer
  /// como hecha, y como hecha ya no invitaba a entrar en la pantalla que sí la
  /// habría recargado. CINCO lo hace así desde su `home_shell`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(widget.daily.refreshForToday());
    // Y se reprograma el aviso de medianoche: un temporizador que durmió con la
    // app suspendida no es de fiar.
    _vigilarLaMedianocheSiHayMenu();
  }

  String? _diaActual;

  /// Si cambia el día con la diaria de ayer delante, vuelta al menú.
  ///
  /// Se escucha al controlador y no a cada llamante, así que da igual quién
  /// cambie el día: la vuelta de segundo plano o la medianoche con la app
  /// abierta. Sin esto el tablero se cambiaría por otro puzle bajo los dedos de
  /// quien lo estaba resolviendo. Mismo criterio que CINCO.
  void _alCambiarLaDiaria() {
    final dia = widget.daily.dayKey;
    // Durante una carga el día pasa por null; eso no es un cambio de día.
    if (dia == null) return;
    final antes = _diaActual;
    _diaActual = dia;
    if (antes != null && antes != dia && _play == _Play.daily && mounted) {
      // A la vista de menú SIN tocar la pestaña. Con `_goPlay` saltaría a Jugar:
      // si la diaria estaba abierta debajo de Social o de Más —pasa al tocar un
      // aviso de amistad—, la app te sacaría de donde estabas sin que nadie lo
      // pidiera (lo midió la revisión).
      setState(() => _play = _Play.menu);
      _vigilarLaMedianocheSiHayMenu();
    }
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
                    versiones: _versiones,
                    onActualizar: _actualizar,
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
                    friends: widget.friends,
                    purchases: widget.purchases,
                    ads: widget.ads,
                    resenas: widget.resenas,
                    onExit: () => _goPlay(_Play.menu),
                    onPractice: () {
                      if (widget.practice.board == null) widget.practice.load();
                      _goPlay(_Play.practice);
                    },
                  ),
                  _Play.practice => PracticeScreen(
                    controller: widget.practice,
                    ads: widget.ads,
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
                  listenable: Listenable.merge([
                    widget.auth,
                    widget.progress,
                    widget.daily,
                    widget.friends,
                  ]),
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
                          // La racha que llevas con cada amigo, junto a su
                          // bandera, como en CINCO: viva si hoy jugaron los dos.
                          insigniaDeFila: (uid) {
                            final rel = widget.friends.relationWith(uid);
                            final racha = rel == null
                                ? null
                                : widget.friends.rachaCon(rel.id);
                            if (racha == null) return null;
                            final hoy = dayKeyFor(DateTime.now());
                            return ChipDeRachaDeAmigo(
                              n: racha.n,
                              yoJugue: racha.jugoHoy(
                                widget.friends.miUid ?? '',
                                hoy,
                              ),
                              elJugo: racha.jugoHoy(uid, hoy),
                            );
                          },
                          // El empujón, solo si TÚ ya terminaste la de hoy:
                          // meter prisa sin haber jugado es pedir sin dar. Es
                          // la misma regla del servidor, que mira el último día
                          // jugado de Nona; el «y él no» lo comprueba el
                          // paquete. Desde la 0.70.0 el empujón es por juego:
                          // llega a Nona como «Nona te llama».
                          puedeEmpujar: _terminadaHoy,
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
                  consent: widget.consent,
                  resenas: widget.resenas,
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
            // En pantallas muy bajas o dentro de una partida (igual que CINCO,
            // `pie_de_modo.dart`), el banner se desmonta por completo: el tablero
            // manda y gana todo el espacio vertical para que las casillas sean
            // grandes y cómodas al tacto.
            if (widget.banner != null &&
                !_inGame &&
                MediaQuery.sizeOf(context).height >= 700)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FranjaSinAnuncios(
                    compras: widget.purchases,
                    visible: true,
                  ),
                  widget.banner!,
                ],
              ),
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
    required this.versiones,
    required this.onActualizar,
    required this.onDaily,
    required this.onPractice,
  });

  final DailyController daily;
  final LocaleController locale;
  final ProgressController progress;
  final SendaVersiones versiones;
  final VoidCallback onActualizar;
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
            // Hecha si el tablero está terminado, o si la nube dice que ESTA
            // cuenta ya la terminó hoy aunque este teléfono no guarde el tablero.
            // Pasa al volver a tu cuenta el mismo día tras entrar con otra: sin
            // esto el menú la ofrecía sin hacer e invitaba a repetirla, que es
            // justo lo que la guardia de `ProgressController.record` no deja
            // anotar. Tras la medianoche no se queda pegada: el día de la marca
            // ya no es el de la diaria.
            final done =
                daily.isFinished ||
                (daily.dayKey != null &&
                    progress.lastCompletedDay == daily.dayKey);
            final l = L.of(context);
            // La racha VIGENTE, no el contador guardado: si el último día
            // terminado no es ni hoy ni ayer, ya está rota.
            final streak = progress.streakAsOf(DateTime.now());

            return LayoutBuilder(
              builder: (context, c) {
                final isWide =
                    c.maxWidth >= 640 && c.maxWidth > c.maxHeight * 1.08;
                final streakGap = (c.maxHeight * 0.026).clamp(14.0, 24.0);
                final cardGap = (c.maxHeight * 0.020).clamp(12.0, 18.0);

                final heroZone = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MainMenuTitleTiles(
                      tileSize: isWide
                          ? (c.maxWidth * 0.048).clamp(42.0, 52.0)
                          : null,
                    ),
                    if (streak > 0) ...[
                      SizedBox(height: streakGap),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: NonaColors.accentChip,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          l.menuStreak(streak),
                          style: TextStyle(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w700,
                            color: NonaColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                );

                final actionZone = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AvisoSiYaEstaba(
                      versiones: versiones,
                      onActualizar: onActualizar,
                    ),
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
                    SizedBox(height: cardGap),
                    _ModeCard(
                      title: l.menuPractice,
                      subtitle: l.menuPracticeSubtitle,
                      icon: Icons.all_inclusive_rounded,
                      primary: done,
                      onTap: onPractice,
                    ),
                  ],
                );

                if (isWide) {
                  // Plegables abiertos en horizontal, tablets apaisadas,
                  // portátiles y monitores de escritorio: reparto en dos
                  // columnas equilibradas (identidad a la izquierda, tarjetas
                  // de juego a la derecha).
                  final colGap = (c.maxWidth * 0.045).clamp(28.0, 56.0);
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: (c.maxHeight - 32).clamp(0.0, double.infinity),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                flex: 10,
                                child: Center(child: heroZone),
                              ),
                              SizedBox(width: colGap),
                              Expanded(
                                flex: 11,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    child: actionZone,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Teléfonos, plegables verticales y tablets en vertical:
                // distribución proporcional sin texto redundante ni empuje
                // artificial inferior, equilibrando el aire sobre el rótulo,
                // entre el rótulo y las tarjetas, y sobre el banner inferior.
                final maxCardWidth = c.maxWidth >= 540 ? 560.0 : 500.0;
                final heroToCardsGap = (c.maxHeight * 0.095).clamp(24.0, 76.0);
                final topOpticalBalance = (c.maxHeight * 0.022).clamp(4.0, 20.0);

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxCardWidth),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 14,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (c.maxHeight - 28).clamp(0.0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: topOpticalBalance),
                            heroZone,
                            SizedBox(height: heroToCardsGap),
                            actionZone,
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// El aviso de versión nueva, **decidido al pintarse el menú**.
///
/// La comprobación va por red y contesta con el menú ya en pantalla. Si el
/// aviso entrara entonces, empujaría las dos tarjetas —el menú va centrado—
/// justo cuando alguien va a tocarlas, y el toque podría acabar en el aviso,
/// que abre la tienda. Así que sale si ya se sabía al pintarse (lo guarda el
/// paquete de la vez anterior) y, mientras está en pantalla, solo lo cambia
/// la X. Tampoco se retira solo: quitarlo movería las tarjetas igual que
/// meterlo. Si se entera tarde, sale la próxima vez que se pinte el menú.
/// Mismo arreglo que CINCO (`_AvisoSiYaEstaba`, 19-9-2026).
class _AvisoSiYaEstaba extends StatefulWidget {
  const _AvisoSiYaEstaba({required this.versiones, required this.onActualizar});

  final SendaVersiones versiones;
  final VoidCallback onActualizar;

  @override
  State<_AvisoSiYaEstaba> createState() => _AvisoSiYaEstabaState();
}

class _AvisoSiYaEstabaState extends State<_AvisoSiYaEstaba> {
  // Sin tienda no sale: decir que hay algo nuevo sin decir dónde está es peor
  // que callarse.
  late final bool _yaEstaba =
      widget.versiones.hayNueva && widget.versiones.tienda != null;
  bool _cerrado = false;

  @override
  Widget build(BuildContext context) {
    if (!_yaEstaba || _cerrado) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _AvisoDeVersion(
        onActualizar: widget.onActualizar,
        onDescartar: () {
          setState(() => _cerrado = true);
          widget.versiones.descartar();
        },
      ),
    );
  }
}

/// «Hay una versión nueva», encima de las dos tarjetas. Copiado de CINCO con
/// sus medidas (André, 17-9-2026).
///
/// Ni diálogo ni bloqueo: quien abre la app viene a jugar. Con su X, que lo
/// calla hasta que se publique otra más nueva todavía. Solo vive en el menú,
/// nunca encima del tablero.
class _AvisoDeVersion extends StatelessWidget {
  const _AvisoDeVersion({
    required this.onActualizar,
    required this.onDescartar,
  });

  final VoidCallback onActualizar;
  final VoidCallback onDescartar;

  @override
  Widget build(BuildContext context) {
    final l = SendaL.of(context);
    return Material(
      color: NonaColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onActualizar,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                Icons.system_update_rounded,
                size: 22,
                color: NonaColors.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                // En una fila si cabe, como en CINCO —así queda en un iPhone
                // actual con la letra normal—; si no, «Actualizar» baja debajo
                // del texto. La fila de CINCO tal cual, con la letra del
                // sistema al máximo, se salía 46 px en un 320, y donde no se
                // salía «Actualizar» se comía la fila (208 de 225 px en un 375)
                // y el aviso quedaba en unos puntos suspensivos. Medido con
                // Figtree el 19-9-2026. Nona no topa la escala en el menú.
                child: OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  spacing: 8,
                  overflowSpacing: 2,
                  children: [
                    Text(
                      l.updateAvailable,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: NonaColors.text,
                      ),
                    ),
                    Text(
                      l.updateNow,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: NonaColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onDescartar,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: NonaColors.muted,
                ),
                tooltip: l.close,
              ),
            ],
          ),
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

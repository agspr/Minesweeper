/// Menú: la diaria y el modo libre.
///
/// La diaria va primero y ocupa más: es el juego. El modo libre está debajo, a
/// mano para quien ya hizo la de hoy o quiere practicar sin que cuente.
library;

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';

import 'package:juegos_senda/juegos_senda.dart';

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

  /// Se está jugando: ni menú ni otras pestañas.
  bool get _inGame => _tab == SendaTab.play && _play != _Play.menu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack y no un `switch`: mantiene VIVAS las tres pestañas, así
      // que ir a Más a mitad de un puzle y volver no reinicia el tablero ni el
      // cronómetro. Con un switch, cada cambio de pestaña destruiría la partida
      // en curso.
      body: IndexedStack(
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
                    mySummary: widget.progress.summaryAsOf(DateTime.now()),
                    onOpenFriends: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => SendaFriendsScreen(
                          friends: widget.friends,
                          gameId: nonaGameId,
                          notifications: widget.notifications,
                          // Las invitaciones cruzadas necesitan la Function y
                          // las reglas desplegadas. Hasta entonces la sección
                          // no se pinta: un "+" que no envía nada promete algo
                          // que no cumple.
                          invitesEnabled: kInvitesEnabled,
                        ),
                      ),
                    ),
                  )
                : SendaSocialSignedOut(onSignIn: widget.auth.exitGuest),
          ),

          SettingsTab(
            auth: widget.auth,
            friends: widget.friends,
            purchases: widget.purchases,
            locale: widget.locale,
            theme: widget.theme,
            progress: widget.progress,
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
          if (widget.banner != null && MediaQuery.sizeOf(context).height >= 700)
            widget.banner!,
          if (_inGame)
            Container(
              height: MediaQuery.paddingOf(context).bottom,
              color: NonaColors.appBg,
            )
          else
            SendaBottomNav(
              current: _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
        ],
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
                          // Banda de 64 de alto: es el tamaño del logo de
                          // CINCO. El logo de Nona todavía no existe, así que
                          // va la palabra dentro de la MISMA banda — así los
                          // huecos de abajo son los de CINCO hoy y lo seguirán
                          // siendo cuando llegue el logo de verdad.
                          SizedBox(
                            height: 64,
                            child: Center(
                              child: Text(
                                l.appName,
                                style: TextStyle(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
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
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
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

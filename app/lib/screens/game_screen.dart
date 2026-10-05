/// La pantalla de la diaria: cabecera, tablero, numpad y resultado.
///
/// El reloj corre mientras la pantalla está en primer plano y se para al irse al
/// fondo, así que mide tiempo de juego y no de calendario. Al volver se
/// comprueba si ya es otro día: un proceso móvil sobrevive a medianoche sin
/// problema, y sin esa comprobación seguiría mostrando el puzle de ayer.
///
/// **El reloj ya no se ENSEÑA mientras se juega**, solo al final, en el
/// resultado. No puntúa (§1) y no se compite con él contra nadie: en la
/// cabecera solo servía para meter prisa. Sigue corriendo porque el resultado y
/// el registro del día lo piden.
///
/// **La X de la cabecera es la única salida.** La barra inferior desaparece
/// mientras se juega, así que no hay pestañas debajo a las que volver: por eso
/// la cabecera se dibuja también mientras carga y cuando el día no está en el
/// banco, donde antes no había nada. Sin ella, esos dos estados encerraban a
/// quien los viera.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart'
    show AdManager, Analytics, FriendsService, PurchaseService, SendaResenas;

import '../game/daily_controller.dart';
import '../game/scoring.dart';
import '../l10n/app_localizations.dart';
import '../services/progress_controller.dart';
import '../services/theme_controller.dart';
import '../services/share_service.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/numpad.dart';
import '../widgets/puzzle_layout.dart';
import '../nona_config.dart';
import '../widgets/difficulty_label.dart';
import '../widgets/escenas_del_final.dart';
import '../widgets/sudoku_board_view.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.progress,
    required this.theme,
    required this.onExit,
    required this.onPractice,
    required this.friends,
    required this.purchases,
    this.ads,
    this.resenas,
  });

  final DailyController controller;
  final ProgressController progress;
  final ThemeController theme;

  /// De aquí salen las rachas de amigos de la última escena del final.
  final FriendsService friends;

  /// «Jugar sin anuncios», en la primera escena del final.
  final PurchaseService purchases;

  /// El anuncio del día, entre el tablero resuelto y la celebración. Null en
  /// las pruebas que no lo miran.
  final AdManager? ads;

  /// La reseña en la tienda, los días de hito: va EN LUGAR del anuncio.
  final SendaResenas? resenas;

  /// Volver al menú. No es `Navigator.pop`: la pantalla no es una ruta, vive
  /// dentro de la pestaña Jugar (ver `home_screen.dart`).
  final VoidCallback onExit;

  /// "Seguir jugando": lleva al modo práctica. La diaria ya está hecha, así que
  /// quien quiera seguir solo puede seguir ahí, y mandarlo al menú a buscarlo
  /// es un paso de más.
  final VoidCallback onPractice;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  bool _wasComplete = false;

  /// Si la diaria ya estaba terminada al verla por primera vez en esta
  /// pantalla, o se terminó delante. Null hasta que hay tablero.
  ///
  /// Es lo que separa CELEBRAR de ENSEÑAR: quien acaba de terminar ve la
  /// celebración entera —con su hito, sus vibraciones y el evento de partida
  /// terminada—; quien abre una diaria que ya hizo ve una repetición, con su X.
  /// Antes no se distinguía, y cada vez que se abría una diaria hecha salía
  /// otra vez `diaria_terminada`.
  bool? _completaAlVer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.startTimer();
    // El anuncio del día se carga mientras se juega, para que al resolver esté
    // listo. A los 4 s y no al abrir: el primer arranque del SDK de anuncios
    // bloquea el hilo principal, y caería bajo los dedos de quien empieza.
    _precarga = Timer(const Duration(seconds: 4), () {
      final c = widget.controller;
      if (mounted && !c.isComplete && c.dayKey != null) {
        unawaited(widget.ads?.preloadFor(c.dayKey!));
      }
    });
    // Aquí vivía un tic por segundo cuyo único trabajo era repintar el reloj de
    // la cabecera. Sin reloj a la vista, repintar la pantalla entera una vez
    // por segundo no dibujaba nada nuevo. El tiempo lo sigue llevando el
    // controlador con su propio reloj, y se lee cuando hace falta.
  }

  Timer? _precarga;
  Timer? _respiro;

  @override
  void dispose() {
    _precarga?.cancel();
    _respiro?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.pauseTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = widget.controller;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      c.pauseTimer();
    } else if (state == AppLifecycleState.resumed) {
      c.refreshForToday().then((changed) {
        if (!mounted) return;
        // Otro día: lo que se sabía de la diaria de ayer ya no vale.
        if (changed) {
          setState(() {
            _wasComplete = false;
            _completaAlVer = null;
          });
        }
        if (!c.isComplete) c.startTimer();
      });
    }
  }

  void _share(BuildContext context, DailyController c) {
    // El MISMO evento y los mismos valores que CINCO ('compartio', tipo
    // 'resultado'): la política §3.8 los declara para la familia entera, y
    // durante veintiséis versiones Nona no lo emitió — el hueco lo encontró
    // el agente de ficha de PRende cotejando la política contra el código.
    Analytics.compartio('resultado');
    final score = scoreDaily(c.outcome!);
    final date = DateTime.parse(c.dayKey!);
    shareText(
      buildShareText(
        l: L.of(context),
        score: score,
        difficulty: c.difficulty!,
        dayLabel: MaterialLocalizations.of(context).formatShortDate(date),
        streak: widget.progress.streakAsOf(date),
      ),
    );
  }

  /// Las rachas de amigos tal como están leídas.
  List<RachaEnLaEscena> _amigosDeLaEscena() => rachasParaLaEscena(
    widget.friends,
    yo: widget.friends.miUid,
    hoy: widget.controller.dayKey ?? '',
  );

  /// Las mismas, releídas hasta que el servidor haya contado la partida de hoy
  /// en todas. Sin sesión no hay nada que releer.
  Future<List<RachaEnLaEscena>> _recargarAmigos() async {
    if (widget.friends.miUid == null) return _amigosDeLaEscena();
    return releerHastaQueCuente(
      recargar: widget.friends.recargarRachas,
      leer: _amigosDeLaEscena,
    );
  }

  /// «Recordar» desde el final de la diaria: el empujón de Nona a ese amigo.
  /// Sin `origen`: la política de Nona declara el empujón, no desde dónde se
  /// manda.
  Future<void> _recordar(String pairId) async {
    for (final f in widget.friends.friendships) {
      if (f.id == pairId) {
        await widget.friends.nudge(f);
        return;
      }
    }
  }

  /// El final de la diaria: la celebración al terminarla, o su repetición al
  /// abrir una ya hecha.
  Future<void> _abrirElFinal({required bool repeticion}) async {
    final c = widget.controller;
    if (!mounted || !c.isComplete || c.outcome == null) return;
    final score = scoreDaily(c.outcome!);
    // El día de la diaria, no el reloj: en la app son el mismo día, y así la
    // racha, la semana y el hito se cuentan sobre el día que se acaba de
    // jugar aunque el reloj diga otra cosa (en una prueba, o un instante
    // pasada la medianoche).
    final ahora = DateTime.parse(c.dayKey!);
    // La racha YA está registrada: la partida se guarda al completarse, así
    // que este número incluye el día de hoy.
    final racha = widget.progress.streakAsOf(ahora);
    final hito = hitoDeHoy(
      score: score,
      racha: racha,
      hitos: nonaConfig.streakMilestones,
    );
    // **El día de un hito, la reseña en la tienda si toca, y ENTONCES SIN EL
    // ANUNCIO**: dos cosas a pantalla completa seguidas en el mejor momento
    // del juego, no (André, en CINCO, 29-9-2026). Se decide aquí, antes del
    // anuncio; la reseña se pide después de la celebración. Una repetición no
    // tiene ni lo uno ni lo otro.
    final conResena =
        !repeticion && hito != null && (widget.resenas?.toca ?? false);
    final ads = widget.ads;
    if (!repeticion && ads != null) {
      // **El anuncio, entre el tablero resuelto y la celebración** (André,
      // 4-10-2026): la racha y los amigos esperan detrás, así que nadie los
      // pierde por cerrarlo, y nadie se salta el anuncio cerrando la
      // celebración. Si no está listo en un segundo no se espera: queda
      // debido para la próxima pausa.
      if (conResena) {
        await ads.saldarDelDia();
      } else {
        await ads.maybeShowAfterPuzzle(c.dayKey!);
      }
      if (!mounted) return;
    }
    final accion = await mostrarEscenasDelFinal(
      context,
      score: score,
      difficulty: c.difficulty!,
      elapsed: c.elapsed,
      racha: racha,
      weekDone: widget.progress.weekDoneAsOf(ahora),
      todayIndex: ahora.weekday - 1,
      purchases: widget.purchases,
      onShare: () async => _share(context, c),
      hito: hito,
      amigos: _amigosDeLaEscena(),
      recargarAmigos: _recargarAmigos,
      onRecordar: _recordar,
      repeticion: repeticion,
    );
    // La reseña, después de la celebración y nunca pegada a un anuncio: hoy
    // no lo hubo, se cambió por esto.
    if (conResena) unawaited(widget.resenas!.pedirSiToca());
    if (!mounted) return;
    switch (accion) {
      case AccionDelFinal.practica:
        widget.onPractice();
      case AccionDelFinal.menu:
        widget.onExit();
      // Cerrar la repetición deja la pantalla como estaba: el tablero
      // resuelto, con su X arriba. Cerrar la celebración con el gesto de
      // volver es irse, como en CINCO.
      case null:
        if (!repeticion) widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // `bottom: false` porque debajo manda el armazón: mientras se juega, la
      // barra inferior deja sitio a una franja del alto del gesto (ver
      // `home_screen.dart`), y volver a descontar el hueco aquí lo contaría dos
      // veces.
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            final l = L.of(context);

            // La MISMA cabecera en los tres estados —error, carga y partida—,
            // porque la X es la única forma de salir y no puede faltar en
            // ninguno. Lo que cambia es cuánto sabe: sin puzle cargado no hay
            // dificultad que poner de subtítulo ni fallos que contar.
            final header = GameHeader(
              title: l.appTagline,
              subtitle: c.difficulty == null
                  ? null
                  : difficultyLabel(context, c.difficulty!),
              onClose: widget.onExit,
              trailing: c.board == null
                  ? null
                  // Los fallos se ven SIEMPRE, también en cero: es lo que se
                  // está puntuando, y esconderlo hasta el primer fallo haría
                  // que la primera resta pareciera salir de la nada. Lo que
                  // cambió es CÓMO: una equis y el número, sin la frase. Las
                  // palabras siguen ahí para quien use un lector de pantalla.
                  : HeaderChip(
                      icon: Icons.close_rounded,
                      count: c.board!.mistakes,
                      highlight: c.board!.mistakes > 0,
                      capped: c.board!.mistakes >= maxCountedMistakes,
                      semanticsLabel: c.board!.mistakes == 0
                          ? l.noMistakes
                          : l.mistakeCount(c.board!.mistakes) +
                                (c.board!.mistakes >= maxCountedMistakes
                                    ? l.mistakeCapSuffix
                                    : ''),
                    ),
            );

            if (c.loadError != null) {
              return PuzzleLayout(
                header: header,
                board: const _BankGap(),
                numpad: const SizedBox.shrink(),
              );
            }
            if (!c.ready || c.board == null) {
              return PuzzleLayout(
                header: header,
                board: const CircularProgressIndicator(strokeWidth: 2.5),
                numpad: const SizedBox.shrink(),
              );
            }

            _completaAlVer ??= c.isComplete;

            // Al completarse, el reloj se para, se registra el día y sale el
            // final. El registro es idempotente, así que que esto viva en un
            // `build` no duplica puntos aunque la pantalla se reconstruya, y
            // se hace también al abrir una diaria ya hecha: si la app murió
            // justo al terminar, es aquí donde el día acaba apuntado.
            if (c.isComplete && !_wasComplete) {
              _wasComplete = true;
              final score = scoreDaily(c.outcome!);
              widget.progress.record(
                score,
                DateTime.parse(c.dayKey!),
                seconds: c.elapsed.inSeconds,
              );
              final repeticion = _completaAlVer!;
              // El evento de juego de Nona, hermano del diaria_terminada de
              // CINCO. Solo agregados de la partida — dificultad y fallos —
              // nunca nada que identifique a la persona. Y solo al TERMINARLA
              // delante: abrir una diaria ya hecha no es terminarla otra vez.
              // GATE: la política §3.8 dice "estas y ninguna más" (orden
              // acordado con André: la política se ensancha primero).
              if (!repeticion) {
                Analytics.gameEvent('diaria_terminada', {
                  'dificultad': c.difficulty!.name,
                  'fallos': score.countedMistakes,
                });
              }
              if (repeticion) {
                // Tras el fotograma: abrir una ruta en mitad de un `build` no
                // se puede.
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _abrirElFinal(repeticion: true),
                );
              } else {
                // **El anuncio del día se DEBE desde este instante**, antes del
                // respiro: quien cierre la app con el tablero recién resuelto
                // lo verá en la próxima pausa. CINCO lo apunta tras su respiro
                // de 2 s, y esos 2 s eran una rendija; aquí no.
                final dia = c.dayKey!;
                final ads = widget.ads;
                if (ads != null) {
                  unawaited(ads.deberElDelDia(dia));
                  // Por si no se precargó (se resolvió antes de 4 s, o falló):
                  // quedan los 2 s del respiro.
                  unawaited(ads.preloadFor(dia));
                }
                // Un respiro para ver el tablero resuelto antes del anuncio y
                // de la celebración, como CINCO tras su última fila.
                _respiro = Timer(
                  const Duration(seconds: 2),
                  () => _abrirElFinal(repeticion: false),
                );
              }
            }

            final board = c.board!;
            // El final ya no se pinta encima: va en su propia ruta, a
            // pantalla completa (`escenas_del_final.dart`).
            return PuzzleLayout(
              header: header,
              board: SudokuBoardView(
                board: board,
                selected: c.selected,
                onTapCell: c.select,
              ),
              numpad: Numpad(
                board: board,
                notesMode: c.notesMode,
                enabled: !c.isComplete,
                onDigit: c.tapDigit,
                onErase: c.erase,
                onToggleNotes: c.toggleNotesMode,
                onUndo: c.undo,
                boardColourOn: widget.theme.boardColour,
                onToggleBoardColour: widget.theme.toggleBoardColour,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// El día pedido no está en el banco. Solo debería verse si se agota el
/// horizonte horneado (2026–2030) o si el reloj del aparato está en otra era.
class _BankGap extends StatelessWidget {
  const _BankGap();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          L.of(context).bankGap,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.5,
            color: NonaColors.muted,
          ),
        ),
      ),
    );
  }
}

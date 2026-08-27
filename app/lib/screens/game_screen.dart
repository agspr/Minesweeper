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

import 'package:flutter/material.dart';
import 'package:juegos_senda/juegos_senda.dart' show Analytics;

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
import '../widgets/result_overlay.dart';
import '../widgets/sudoku_board_view.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.controller,
    required this.progress,
    required this.theme,
    required this.onExit,
    required this.onPractice,
  });

  final DailyController controller;
  final ProgressController progress;
  final ThemeController theme;

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
  bool _resultDismissed = false;
  bool _wasComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.startTimer();
    // Aquí vivía un tic por segundo cuyo único trabajo era repintar el reloj de
    // la cabecera. Sin reloj a la vista, repintar la pantalla entera una vez
    // por segundo no dibujaba nada nuevo. El tiempo lo sigue llevando el
    // controlador con su propio reloj, y se lee cuando hace falta.
  }

  @override
  void dispose() {
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
        if (changed) setState(() => _resultDismissed = false);
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

            // Al completarse, el reloj se para, se registra el día y sale el
            // resultado. El registro es idempotente, así que que esto viva en
            // un `build` no duplica puntos aunque la pantalla se reconstruya.
            if (c.isComplete && !_wasComplete) {
              _wasComplete = true;
              _resultDismissed = false;
              widget.progress.record(
                scoreDaily(c.outcome!),
                DateTime.parse(c.dayKey!),
                seconds: c.elapsed.inSeconds,
              );
            }

            final board = c.board!;
            return Stack(
              children: [
                PuzzleLayout(
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
                ),
                if (c.isComplete && !_resultDismissed)
                  Positioned.fill(
                    child: ResultOverlay(
                      score: scoreDaily(c.outcome!),
                      elapsed: c.elapsed,
                      // La racha YA está registrada cuando esto se pinta: la
                      // partida se guarda al completarse, así que este número
                      // incluye el día de hoy.
                      streak: widget.progress.streakAsOf(DateTime.now()),
                      weekDone: widget.progress.weekDoneAsOf(DateTime.now()),
                      todayIndex: DateTime.now().weekday - 1,
                      onShare: () => _share(context, c),
                      onPractice: widget.onPractice,
                      onMenu: widget.onExit,
                    ),
                  ),
              ],
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

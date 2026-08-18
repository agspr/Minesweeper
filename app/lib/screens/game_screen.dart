/// La pantalla de la diaria: cabecera, tablero, numpad y resultado.
///
/// El reloj corre mientras la pantalla está en primer plano y se para al irse al
/// fondo, así que mide tiempo de juego y no de calendario. Al volver se
/// comprueba si ya es otro día: un proceso móvil sobrevive a medianoche sin
/// problema, y sin esa comprobación seguiría mostrando el puzle de ayer.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../game/daily_controller.dart';
import '../game/scoring.dart';
import '../l10n/app_localizations.dart';
import 'package:juegos_senda/juegos_senda.dart';

import '../services/progress_controller.dart';
import '../services/theme_controller.dart';
import '../services/share_service.dart';
import '../theme.dart';
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
  });

  final DailyController controller;
  final ProgressController progress;
  final ThemeController theme;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  Timer? _ticker;
  bool _resultDismissed = false;
  bool _wasComplete = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.startTimer();
    // Un tic por segundo solo para repintar el reloj. El tiempo real lo lleva
    // el controlador con su propio reloj, así que perder un tic no descuadra
    // nada.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !widget.controller.isComplete) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
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
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;

            if (c.loadError != null) return const _BankGap();
            if (!c.ready || c.board == null) {
              return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
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
                  header: _Header(
                    difficulty: difficultyLabel(context, c.difficulty!),
                    mistakes: board.mistakes,
                    elapsed: c.elapsed,
                    theme: widget.theme,
                  ),
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
                  ),
                ),
                if (c.isComplete && !_resultDismissed)
                  Positioned.fill(
                    child: ResultOverlay(
                      score: scoreDaily(c.outcome!),
                      elapsed: c.elapsed,
                      onClose: () => setState(() => _resultDismissed = true),
                      onShare: () => _share(context, c),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.difficulty,
    required this.mistakes,
    required this.elapsed,
  });

  final ThemeController theme;
  final String difficulty;
  final int mistakes;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      // Flexible + FittedBox porque esta fila desbordaba en TODOS los móviles
      // (43 px en un iPhone SE) y en un iPad no se veía: lo cazó
      // `layout_test.dart`. Ahora el título se recorta con puntos suspensivos y
      // el grupo de chips se encoge en bloque antes que salirse, así que
      // aguanta también el texto del sistema ampliado al máximo.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              difficulty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: NonaColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Los fallos se ven SIEMPRE, también en cero: es lo que se
                  // está puntuando, y esconderlo hasta el primer fallo haría
                  // que la primera resta pareciera salir de la nada.
                  _Chip(
                    label: mistakes == 0
                        ? l.noMistakes
                        : l.mistakeCount(mistakes) +
                              (mistakes >= 5 ? l.mistakeCapSuffix : ''),
                    highlight: mistakes > 0,
                  ),
                  const SizedBox(width: 8),
                  _Chip(label: _clock(elapsed)),
                ],
              ),
            ),
          ),
          // Fuera del FittedBox a propósito: ahí dentro se encogería con los
          // chips y un área de toque encogida deja de poder tocarse. Aquí
          // conserva sus 40x40 pase lo que pase con el resto de la fila.
          _BoardColourButton(theme: theme),
        ],
      ),
    );
  }
}

/// Apagar o encender el color del tablero, sin salir del tablero.
///
/// Va aquí y no en ajustes porque es una decisión que se toma MIRÁNDOLO: quien
/// lo encuentre chillón lo piensa jugando, y mandarle a otra pantalla para
/// volver a comprobar el efecto sería pedirle que recuerde dos estados a la
/// vez. Es el mismo criterio por el que el selector de color SÍ vive en Más:
/// allí se elige identidad, aquí se ajusta lo que se está mirando.
class _BoardColourButton extends StatelessWidget {
  const _BoardColourButton({required this.theme});

  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final on = theme.boardColour;
    return IconButton(
      onPressed: () {
        Haptics.selection();
        theme.toggleBoardColour();
      },
      visualDensity: VisualDensity.compact,
      // El icono dice en qué ESTADO está, no qué pasará al pulsarlo: un icono
      // que anuncia la acción obliga a deducir el estado actual por descarte.
      icon: Icon(
        on ? Icons.palette_rounded : Icons.palette_outlined,
        size: 20,
        color: on ? NonaColors.accent : NonaColors.muted,
      ),
      tooltip: on ? l.boardColourOn : l.boardColourOff,
      // Lo que leen los lectores de pantalla: el estado, no el icono.
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? NonaColors.cellWrong : NonaColors.surface,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlight ? NonaColors.wrong : NonaColors.muted,
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

String _clock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

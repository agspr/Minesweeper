/// Modo libre: elegir dificultad, jugar, pedir pista, otro puzle.
///
/// Sin reloj y sin contador de fallos en la cabecera, a propósito. No puntúa
/// (§1), así que enseñar fallos aquí sería regañar por nada; el rojo de la
/// casilla ya avisa de que ese número no va.
///
/// Misma cabecera que la diaria —X, título en versalitas, chip— porque son la
/// misma clase de pantalla y llevaban dos cromos distintos por accidente. Las
/// pastillas de dificultad van en una fila propia DEBAJO y no dentro de la
/// cabecera: ahí se encogerían con el resto de la fila, y una pastilla encogida
/// deja de poder tocarse.
library;

import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import '../game/practice_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/haptics.dart';
import '../services/theme_controller.dart';
import '../theme.dart';
import '../widgets/game_header.dart';
import '../widgets/numpad.dart';
import '../widgets/puzzle_layout.dart';
import '../widgets/result_overlay.dart' show difficultyLabel;
import '../widgets/sudoku_board_view.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({
    super.key,
    required this.controller,
    required this.theme,
    required this.onExit,
  });

  final PracticeController controller;

  /// Para la tecla de color del numpad.
  final ThemeController theme;

  /// Volver al menú. Obligatorio: con la barra inferior escondida mientras se
  /// juega, una pantalla de juego sin salida no tendría forma de abandonarse.
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ver la nota de `game_screen.dart`: el hueco de abajo lo pone el armazón.
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            return PuzzleLayout(
              header: _Header(
                difficulty: c.difficulty,
                hintsUsed: c.hintsUsed,
                onPick: c.setDifficulty,
                onExit: onExit,
              ),
              board: c.generating || c.board == null
                  ? const CircularProgressIndicator(strokeWidth: 2.5)
                  : SudokuBoardView(
                      board: c.board!,
                      selected: c.selected,
                      onTapCell: c.select,
                    ),
              // El modo práctica mete una barra de acciones —pista, otro
              // puzle— entre el tablero y el numpad. Van juntos en la misma
              // ranura: en tablet apaisada bajan los dos a la columna de la
              // derecha, que es donde deben estar los controles.
              numpad: c.board == null || c.generating
                  ? const SizedBox.shrink()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.isComplete)
                          _SolvedBar(onNew: c.newPuzzle)
                        else
                          _PracticeActions(onHint: c.hint, onNew: c.newPuzzle),
                        const SizedBox(height: 10),
                        Numpad(
                          board: c.board!,
                          notesMode: c.notesMode,
                          enabled: !c.isComplete,
                          onDigit: c.tapDigit,
                          onErase: c.erase,
                          onToggleNotes: c.toggleNotesMode,
                          onUndo: c.undo,
                          boardColourOn: theme.boardColour,
                          onToggleBoardColour: theme.toggleBoardColour,
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.difficulty,
    required this.hintsUsed,
    required this.onPick,
    required this.onExit,
  });

  final Difficulty difficulty;
  final int hintsUsed;
  final ValueChanged<Difficulty> onPick;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameHeader(
          title: l.menuPractice,
          onClose: onExit,
          // Las pistas solo cuando las hay: aquí no se puntúa, así que un "0
          // pistas" permanente sería un reproche por adelantado. El hueco del
          // chip existe igual, así que el título no se mueve al pedir la
          // primera.
          trailing: hintsUsed > 0
              ? HeaderChip(label: l.hintCount(hintsUsed))
              : null,
        ),
        const SizedBox(height: 8),
        // Fila propia y a todo lo ancho: dentro de la cabecera se encogerían
        // con el resto y el dedo dejaría de acertarlas.
        Row(
          children: [
            for (final d in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTapDown: (_) => NonaHaptics.tap(),
                    onTap: () => onPick(d),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: d == difficulty
                            ? NonaColors.accentChip
                            : NonaColors.surface,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          difficultyLabel(context, d),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: d == difficulty
                                ? NonaColors.accent
                                : NonaColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PracticeActions extends StatelessWidget {
  const _PracticeActions({required this.onHint, required this.onNew});

  final VoidCallback onHint;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Bar(
            icon: Icons.lightbulb_outline_rounded,
            label: L.of(context).hint,
            onTap: onHint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Bar(
            icon: Icons.refresh_rounded,
            label: L.of(context).newPuzzle,
            onTap: onNew,
          ),
        ),
      ],
    );
  }
}

class _SolvedBar extends StatelessWidget {
  const _SolvedBar({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            L.of(context).solved,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: NonaColors.accent,
            ),
          ),
        ),
        SizedBox(
          width: 160,
          child: _Bar(
            icon: Icons.refresh_rounded,
            label: L.of(context).newPuzzle,
            onTap: onNew,
            filled: true,
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? NonaColors.accentDeep : NonaColors.keyFg;
    return GestureDetector(
      onTapDown: (_) => NonaHaptics.tap(),
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: filled ? NonaColors.accent : NonaColors.keyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modo libre: elegir dificultad, jugar, pedir pista, otro puzle.
///
/// Sin reloj y sin contador de fallos en la cabecera, a propósito. No puntúa
/// (§1), así que enseñar fallos aquí sería regañar por nada; el rojo de la
/// casilla ya avisa de que ese número no va.
library;

import 'package:flutter/material.dart';

import '../game/difficulty.dart';
import '../game/practice_controller.dart';
import '../theme.dart';
import '../widgets/numpad.dart';
import '../widgets/result_overlay.dart' show difficultyLabel;
import '../widgets/sudoku_board_view.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.controller, this.onExit});

  final PracticeController controller;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      _Header(
                        difficulty: c.difficulty,
                        hintsUsed: c.hintsUsed,
                        onPick: c.setDifficulty,
                        onExit: onExit,
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Center(
                          child: c.generating || c.board == null
                              ? const CircularProgressIndicator(strokeWidth: 2.5)
                              : SudokuBoardView(
                                  board: c.board!,
                                  selected: c.selected,
                                  onTapCell: c.select,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (c.board != null && !c.generating) ...[
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
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
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
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onExit != null)
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.arrow_back_rounded, size: 22),
            color: NonaColors.muted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final d in Difficulty.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onPick(d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: d == difficulty
                              ? NonaColors.accentChip
                              : NonaColors.surface,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          difficultyLabel(d),
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
              ],
            ),
          ),
        ),
        if (hintsUsed > 0)
          Text(
            hintsUsed == 1 ? '1 pista' : '$hintsUsed pistas',
            style: const TextStyle(fontSize: 12, color: NonaColors.muted),
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
            label: 'Pista',
            onTap: onHint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Bar(
            icon: Icons.refresh_rounded,
            label: 'Otro puzle',
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
        const Expanded(
          child: Text(
            '¡Resuelto!',
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
            label: 'Otro puzle',
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

/// Numpad: los nueve dígitos y las tres acciones.
///
/// Cada tecla lleva **cuántas veces queda por colocar** ese dígito, y cuando ya
/// están las nueve la tecla se apaga. Es la ayuda más útil de un sudoku
/// asistido y ahorra recorrer el tablero contando; apagarla en vez de
/// esconderla mantiene el numpad quieto, porque una fila de teclas que se
/// reordena sola hace fallar el dedo.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../game/grid.dart';
import '../game/sudoku_board.dart';
import '../theme.dart';

class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.board,
    required this.notesMode,
    required this.enabled,
    required this.onDigit,
    required this.onErase,
    required this.onToggleNotes,
    required this.onUndo,
  });

  final SudokuBoard board;
  final bool notesMode;

  /// `false` con la partida ya terminada: las teclas siguen visibles pero
  /// apagadas, para que la pantalla no dé un salto al acabar.
  final bool enabled;

  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Column(
      children: [
        Row(
          children: [
            for (var digit = 1; digit <= boardSize; digit++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _DigitKey(
                    digit: digit,
                    remaining: board.remainingOf(digit),
                    notesMode: notesMode,
                    enabled: enabled,
                    onTap: () => onDigit(digit),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionKey(
                icon: Icons.undo_rounded,
                label: l.undo,
                enabled: enabled && board.canUndo,
                onTap: onUndo,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionKey(
                icon: Icons.backspace_outlined,
                label: l.erase,
                enabled: enabled,
                onTap: onErase,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionKey(
                icon: Icons.edit_outlined,
                label: l.notes,
                enabled: enabled,
                active: notesMode,
                onTap: onToggleNotes,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({
    required this.digit,
    required this.remaining,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
  });

  final int digit;
  final int remaining;
  final bool notesMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = remaining <= 0;
    final live = enabled && !done;
    return GestureDetector(
      onTap: live ? onTap : null,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: done ? NonaColors.keyDone : NonaColors.keyBg,
          borderRadius: BorderRadius.circular(10),
          // En modo notas el numpad se enmarca en el acento: hay que poder
          // saber en qué modo estás sin probar una tecla.
          border: notesMode && live
              ? Border.all(color: NonaColors.accent, width: 1.5)
              : null,
        ),
        // Nueve teclas en una fila es lo más apretado de la pantalla, así que
        // el contenido se encoge antes que desbordar. Con el texto del sistema
        // al máximo, un dígito a tamaño completo no cabe en 31 px de ancho.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$digit',
                style: TextStyle(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  // El modo notas lo dice el borde de arriba, no el color del
                  // dígito: las teclas van siempre en el acento.
                  color: done ? NonaColors.keyDoneFg : NonaColors.keyDigitFg,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                done ? '·' : '$remaining',
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: done ? NonaColors.keyDoneFg : NonaColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? NonaColors.keyDoneFg
        : active
        ? NonaColors.accent
        : NonaColors.keyFg;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: active ? NonaColors.accentChip : NonaColors.keyBg,
          borderRadius: BorderRadius.circular(10),
        ),
        // FittedBox porque icono + texto no caben en un tercio de un móvil
        // estrecho: desbordaba 37 px en un iPhone SE y en el iPad no se notaba.
        // Encogerse es preferible a recortar la palabra, que dejaría un
        // "Desha…" ilegible.
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

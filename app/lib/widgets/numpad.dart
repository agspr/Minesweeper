/// Controles de Buscaminas: selector de modo (Cavar / Bandera), deshacer y contador de minas.
///
/// Diseñado bajo Material 3 Expressive: controles táctiles ergonómicos situados
/// en la zona cómoda del pulgar, con respuesta háptica y estados claramente
/// diferenciados por forma, tono e icono.
library;

import 'package:flutter/material.dart';

import '../game/sudoku_board.dart';
import '../l10n/app_localizations.dart';
import '../services/haptics.dart';
import '../theme.dart';

typedef MinesweeperControls = Numpad;

class Numpad extends StatelessWidget {
  const Numpad({
    super.key,
    required this.board,
    required this.notesMode,
    required this.enabled,
    this.onDigit,
    this.onErase,
    required this.onToggleNotes,
    this.onUndo,
    required this.boardColourOn,
    required this.onToggleBoardColour,
  });

  final SudokuBoard board;

  /// `true` = Modo Bandera; `false` = Modo Cavar / Descubrir.
  final bool notesMode;

  /// `false` con la partida ya terminada.
  final bool enabled;

  /// Conservado por compatibilidad de firma.
  final bool Function(int digit)? onDigit;
  final VoidCallback? onErase;

  final VoidCallback onToggleNotes;
  final VoidCallback? onUndo;
  final bool boardColourOn;
  final VoidCallback onToggleBoardColour;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final isFlagMode = notesMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B22),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFF2C2C38),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Selector interactivo Cavar / Bandera (Material 3 Expressive Segmented Pill)
            Expanded(
              child: _ModeSelectorPill(
                isFlagMode: isFlagMode,
                enabled: enabled,
                onToggle: onToggleNotes,
              ),
            ),

            const SizedBox(width: 8),

            // Contador de minas restantes
            _MineCounterPill(
              remainingMines: board.remainingMines,
              isFlagMode: isFlagMode,
            ),

            const SizedBox(width: 6),

            // Botón de color del tablero: permanece activo aun terminada la partida
            _ControlButton(
              icon: Icons.palette_outlined,
              tooltip: boardColourOn ? l.boardColourOn : l.boardColourOff,
              enabled: true,
              active: boardColourOn,
              onTap: onToggleBoardColour,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSelectorPill extends StatelessWidget {
  const _ModeSelectorPill({
    required this.isFlagMode,
    required this.enabled,
    required this.onToggle,
  });

  final bool isFlagMode;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF141419),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF282834),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Segmento CAVAR
          Expanded(
            child: _SegmentItem(
              icon: Icons.explore_rounded,
              label: 'Cavar',
              isSelected: !isFlagMode,
              enabled: enabled,
              onTap: () {
                if (isFlagMode && enabled) {
                  NonaHaptics.select();
                  onToggle();
                }
              },
            ),
          ),

          // Segmento BANDERA
          Expanded(
            child: _SegmentItem(
              icon: Icons.flag_rounded,
              label: 'Marcar',
              iconColor: isFlagMode ? const Color(0xFFFF5252) : null,
              isSelected: isFlagMode,
              enabled: enabled,
              onTap: () {
                if (!isFlagMode && enabled) {
                  NonaHaptics.select();
                  onToggle();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final Color bg = isSelected ? NonaColors.cellSelected : Colors.transparent;
    final Color fg = !enabled
        ? NonaColors.muted.withValues(alpha: 0.35)
        : isSelected
        ? NonaColors.text
        : NonaColors.muted;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: NonaColors.cellSelectedBorder,
                  width: 1.5,
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: iconColor ?? fg,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: fg,
                    letterSpacing: 0.2,
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

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled
          ? () {
              NonaHaptics.tap();
              onTap();
            }
          : null,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: active
            ? NonaColors.accent
            : enabled
            ? NonaColors.text
            : NonaColors.muted.withValues(alpha: 0.3),
        backgroundColor: const Color(0xFF22222C),
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _MineCounterPill extends StatelessWidget {
  const _MineCounterPill({
    required this.remainingMines,
    required this.isFlagMode,
  });

  final int remainingMines;
  final bool isFlagMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF22222C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFlagMode
              ? const Color(0xFFFF5252).withValues(alpha: 0.5)
              : const Color(0xFF2E2E3C),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.flag_rounded,
            size: 16,
            color: Color(0xFFFF5252),
          ),
          const SizedBox(width: 5),
          Text(
            '$remainingMines',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: NonaColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

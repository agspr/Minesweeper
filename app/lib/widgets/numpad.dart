/// Numpad: los nueve dígitos y las cuatro acciones.
///
/// **Sin contador debajo de cada tecla.** Lo llevaba, y era información que ya
/// está en el tablero: quien quiere saber cuántos cincos faltan mira, no lee un
/// número diminuto. Quitarlo devuelve la tecla a lo que es —un dígito grande y
/// tocable— y baja el bloque entero. Cuando un dígito ya está las nueve veces,
/// la tecla se apaga por BRILLO (fondo y tinta más oscuros); apagarla en vez de
/// esconderla mantiene el numpad quieto, porque una fila de teclas que se
/// reordena sola hace fallar el dedo.
///
/// **Las acciones son solo iconos.** Deshacer, borrar, notas y color no
/// necesitan que se lo cuenten dos veces: el icono lo dice, y la etiqueta
/// costaba alto en la pantalla más apretada. El nombre sigue estando para quien
/// lo necesita —en el tooltip, que es además lo que leen los lectores de
/// pantalla— y el estado activo se dice por DOS canales, relleno del icono y
/// fondo, nunca solo por color: el acento lo elige quien juega y no puede ser
/// el único que distinga un modo de otro.
///
/// Todas las teclas vibran al BAJAR el dedo (`onTapDown`), no al soltar. Ver
/// `NonaHaptics`.
library;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../game/grid.dart';
import '../game/sudoku_board.dart';
import '../services/haptics.dart';
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
    required this.boardColourOn,
    required this.onToggleBoardColour,
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

  /// Estado del color del tablero, para la cuarta tecla de acción.
  final bool boardColourOn;
  final VoidCallback onToggleBoardColour;

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
                    done: board.remainingOf(digit) <= 0,
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
                // Relleno cuando está activo, contorno cuando no: el modo
                // notas no puede distinguirse solo por el color del fondo.
                icon: notesMode ? Icons.edit_rounded : Icons.edit_outlined,
                label: l.notes,
                enabled: enabled,
                active: notesMode,
                onTap: onToggleNotes,
              ),
            ),
            const SizedBox(width: 8),
            // Apagar o encender el color del tablero, sin salir del tablero.
            //
            // Va aquí y no en ajustes porque es una decisión que se toma
            // MIRÁNDOLO: quien lo encuentre chillón lo piensa jugando, y
            // mandarle a otra pantalla para volver a comprobar el efecto sería
            // pedirle que recuerde dos estados a la vez. Es el mismo criterio
            // por el que el selector de color SÍ vive en Más: allí se elige
            // identidad, aquí se ajusta lo que se está mirando.
            //
            // Sigue viva con la partida terminada: es una preferencia de
            // VISTA, no una jugada, y el tablero se sigue viendo debajo del
            // resultado.
            Expanded(
              child: _ActionKey(
                // El icono dice en qué ESTADO está, no qué pasará al pulsarlo:
                // un icono que anuncia la acción obliga a deducir el estado
                // actual por descarte.
                icon: boardColourOn
                    ? Icons.palette_rounded
                    : Icons.palette_outlined,
                label: boardColourOn ? l.boardColourOn : l.boardColourOff,
                enabled: true,
                active: boardColourOn,
                onTap: onToggleBoardColour,
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
    required this.done,
    required this.notesMode,
    required this.enabled,
    required this.onTap,
  });

  final int digit;

  /// Ese dígito ya está las nueve veces en el tablero.
  final bool done;

  final bool notesMode;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final live = enabled && !done;
    return GestureDetector(
      // Vibra al bajar el dedo, y solo si la tecla hace algo: un tic significa
      // "ha entrado", así que una tecla apagada tiene que quedarse muda.
      onTapDown: live ? (_) => NonaHaptics.tap() : null,
      onTap: live ? onTap : null,
      child: Container(
        height: 62,
        alignment: Alignment.center,
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
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w700,
              color: done ? NonaColors.keyDoneFg : NonaColors.keyDigitFg,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una tecla de acción: solo el icono, con el nombre en el tooltip.
///
/// 40 de alto y no 48: sin etiqueta debajo no hace falta más, y los 8 puntos
/// que sobran se los queda el tablero. De ancho pasan de 68, así que el área de
/// toque sigue siendo cómoda aunque el alto baje del mínimo de Apple.
class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;

  /// Nombre de la acción. No se pinta: es el tooltip y el nombre accesible.
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
    return Semantics(
      button: true,
      enabled: enabled,
      // El estado, no el icono: un lector de pantalla tiene que poder decir si
      // el modo notas está puesto.
      toggled: active,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTapDown: enabled ? (_) => NonaHaptics.tap() : null,
          onTap: enabled ? onTap : null,
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? NonaColors.accentChip : NonaColors.keyBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: fg),
          ),
        ),
      ),
    );
  }
}

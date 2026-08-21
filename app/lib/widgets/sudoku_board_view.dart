/// El tablero 9×9.
///
/// **Sin líneas.** Cada casilla es una superelipse —la curva de esquina que
/// entra en el lado recto de forma continua, no un arco pegado— y las cajas de
/// 3×3 se leen por el RITMO de los huecos: casi juntas dentro de una caja,
/// separadas entre cajas. Lo que antes decía un trazo grueso cada tres
/// columnas ahora lo dice el espacio.
///
/// El precio de ese cambio es que la estructura pasa de estar dibujada a estar
/// calculada, así que la aritmética vive en [BoardMetrics] y se comprueba en
/// `test/board_metrics_test.dart`. Una línea mal puesta se ve; un ritmo mal
/// repartido no revienta nada, solo deja un tablero ilegible.
///
/// Los COLORES no cambiaron con la forma, y a propósito: cada tono del tablero
/// está razonado contra los demás en `theme.dart` y medido en
/// `board_colour_test.dart`. Esto es un cambio de silueta, no de paleta.
///
/// Dos decisiones de disposición que evitan fallos concretos:
///
/// 1. **Siempre cuadrado y del tamaño que quepa.** El lado sale de la
///    restricción más pequeña, así que el tablero nunca desborda ni en un móvil
///    bajo ni en una tablet.
/// 2. **La tipografía del tablero NO sigue el ajuste del sistema.** En el resto
///    de la app sí, faltaría más, pero aquí los dígitos se dimensionan a partir
///    del lado de la casilla: con el texto ampliado al máximo, un dígito con
///    escala de sistema se sale de su casilla y las anotaciones se convierten en
///    puré. Se envuelve en un MediaQuery con `TextScaler.noScaling` y cada
///    tamaño se calcula en proporción a la celda.
library;

import 'package:flutter/material.dart';

import '../game/board_metrics.dart';
import '../game/grid.dart';
import '../game/sudoku_board.dart';
import '../theme.dart';

class SudokuBoardView extends StatelessWidget {
  const SudokuBoardView({
    super.key,
    required this.board,
    required this.selected,
    required this.onTapCell,
  });

  final SudokuBoard board;

  /// Casilla seleccionada, o -1.
  final int selected;

  final ValueChanged<int> onTapCell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        final m = BoardMetrics(side);
        final selDigit = selected >= 0 ? board.valueAt(selected) : 0;

        return MediaQuery(
          // Ver la nota 2 de la cabecera.
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.noScaling),
          child: SizedBox.square(
            dimension: side,
            child: Stack(
              children: [
                for (var index = 0; index < cellCount; index++)
                  Positioned.fromRect(
                    rect: m.rectOf(index),
                    child: _Cell(
                      board: board,
                      index: index,
                      metrics: m,
                      isSelected: index == selected,
                      isPeer: selected >= 0 && peers[selected].contains(index),
                      isSameDigit:
                          selDigit != 0 &&
                          index != selected &&
                          board.valueAt(index) == selDigit,
                      onTap: () => onTapCell(index),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.board,
    required this.index,
    required this.metrics,
    required this.isSelected,
    required this.isPeer,
    required this.isSameDigit,
    required this.onTap,
  });

  final SudokuBoard board;
  final int index;
  final BoardMetrics metrics;
  final bool isSelected;
  final bool isPeer;
  final bool isSameDigit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = metrics.cell;
    final value = board.valueAt(index);
    final given = board.isGiven(index);
    final wrong = board.isWrong(index);

    // El orden importa: lo equivocado y lo seleccionado mandan sobre las
    // ayudas de orientación, que son las que menos deben pesar.
    final bg = wrong
        ? NonaColors.cellWrong
        : isSelected
        ? NonaColors.cellSelected
        : isSameDigit
        ? NonaColors.cellSameDigit
        : isPeer
        ? NonaColors.cellPeer
        : NonaColors.cell;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedSuperellipseBorder(
            // La seleccionada se redondea MÁS que las demás: así seleccionar
            // cambia la forma y no solo el color, que es un canal que no
            // depende del tema ni de la vista de nadie.
            borderRadius: BorderRadius.circular(
              isSelected ? metrics.selectedRadius : metrics.radius,
            ),
            // Borde solo en la seleccionada. La separa de la equivocada por
            // PRESENCIA y no por tono, que es lo que hace falta con Coral: su
            // chip y el rojo de error quedan a 22,7 de distancia, el par más
            // justo del tablero. Con borde, da igual el tema.
            side: isSelected && !wrong
                ? BorderSide(color: NonaColors.cellSelectedBorder, width: 2)
                : BorderSide.none,
          ),
        ),
        child: value != 0
            ? Text(
                '$value',
                style: TextStyle(
                  fontSize: size * 0.56,
                  height: 1,
                  // Las pistas van en negrita y en blanco; lo escrito, más
                  // ligero y en el acento. Se distinguen por peso además de por
                  // color, no solo por color.
                  //
                  // Lo EQUIVOCADO también va en negrita, y no por énfasis: con
                  // el tema Coral el acento es #FF8A93 y el rojo de error
                  // #FF7A8A — el mismo color a ojo. Separados solo por tono, un
                  // dígito correcto y uno equivocado se verían idénticos en ese
                  // tema. Con el peso, no.
                  fontWeight: given || wrong
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: wrong
                      ? NonaColors.wrong
                      : given
                      ? NonaColors.given
                      : NonaColors.entered,
                ),
              )
            : _Notes(mask: board.notes[index], size: size),
      ),
    );
  }
}

/// Las nueve anotaciones en una mini-rejilla 3×3 dentro de la casilla, cada
/// dígito en su sitio fijo: se buscan por posición, no leyendo.
class _Notes extends StatelessWidget {
  const _Notes({required this.mask, required this.size});

  final int mask;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (mask == 0) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.all(size * 0.06),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Center(
                        child: Text(
                          mask & bitOf(row * 3 + col + 1) != 0
                              ? '${row * 3 + col + 1}'
                              : '',
                          style: TextStyle(
                            fontSize: size * 0.22,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            color: NonaColors.note,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

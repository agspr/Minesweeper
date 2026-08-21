/// El tablero 9×9.
///
/// Casillas que son superelipses —la curva de esquina que entra en el lado
/// recto de forma continua, no un arco pegado— sentadas sobre una rejilla
/// clásica: línea fina entre casillas, gruesa entre cajas de 3×3 y un marco
/// alrededor. Las líneas corren por el CENTRO de los huecos que separan las
/// casillas, así que la estructura se dice dos veces y las dos coinciden: el
/// ritmo de los huecos —casi juntas dentro de una caja, separadas entre cajas—
/// y el trazo que pasa por ellos.
///
/// Que se diga dos veces no es adorno. Quien ha hecho sudokus en papel toda la
/// vida reconoce un tablero por su rejilla, y un tablero de baldosas sueltas,
/// por bien repartido que esté, le pide aprender a leerlo. La rejilla es lo que
/// hace que esto parezca un sudoku antes de mirarlo dos veces; las
/// superelipses son lo que hace que no parezca una hoja de cuadrícula.
///
/// El precio de calcular la estructura en vez de solo dibujarla es que la
/// aritmética vive en [BoardMetrics] y se comprueba en
/// `test/board_metrics_test.dart`: una línea desviada medio hueco pisa la
/// curva de una casilla sin que nada reviente.
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

import 'dart:math' show max;

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
                // La rejilla va DEBAJO de las casillas: las líneas corren por
                // los huecos y nunca deberían tocar una casilla, pero si la
                // aritmética fallara, mejor una línea tapada que una casilla
                // tachada.
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(
                      metrics: m,
                      thin: NonaColors.gridThin,
                      thick: NonaColors.gridThick,
                      pixelRatio: MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
                ),
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

/// La rejilla clásica: fina entre casillas, gruesa entre cajas, marco fuera.
///
/// Cada línea se ajusta a píxeles FÍSICOS antes de pintarse. Una línea de un
/// píxel lógico centrada en una coordenada fraccionaria se reparte entre dos
/// filas de píxeles y sale gris y borrosa; la misma línea ajustada a la rejilla
/// física sale nítida. El marco no se ajusta: es grueso y curvo, y ahí el
/// suavizado ayuda en vez de estorbar.
class _GridPainter extends CustomPainter {
  const _GridPainter({
    required this.metrics,
    required this.thin,
    required this.thick,
    required this.pixelRatio,
  });

  final BoardMetrics metrics;
  final Color thin;
  final Color thick;
  final double pixelRatio;

  double _snap(double v) => (v * pixelRatio).roundToDouble() / pixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final m = metrics;
    final side = m.side;

    // Primero las finas y luego las gruesas: donde se cruzan, manda la gruesa.
    for (final boxLines in [false, true]) {
      final paint = Paint()..color = boxLines ? thick : thin;
      for (var i = 0; i < boardSize - 1; i++) {
        if (m.isBoxLine(i) != boxLines) continue;
        final w = m.lineWidthAfter(i);
        final a = _snap(m.lineAt(i) - w / 2);
        // Nunca por debajo de un píxel físico, aunque el ajuste redondee a 0.
        final b = max(_snap(m.lineAt(i) + w / 2), a + 1 / pixelRatio);
        canvas.drawRect(Rect.fromLTRB(a, 0, b, side), paint); // vertical
        canvas.drawRect(Rect.fromLTRB(0, a, side, b), paint); // horizontal
      }
    }

    final frame = Paint()
      ..color = thick
      ..style = PaintingStyle.stroke
      ..strokeWidth = m.thick;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, side, side).deflate(m.thick / 2),
        Radius.circular(m.frameRadius),
      ),
      frame,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.metrics.side != metrics.side ||
      old.thin != thin ||
      old.thick != thick ||
      old.pixelRatio != pixelRatio;
}

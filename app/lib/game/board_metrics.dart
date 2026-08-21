/// Dónde cae cada casilla dentro del tablero, y por dónde pasan las líneas.
///
/// Vive fuera del widget porque **esta aritmética es lo que dice dónde están
/// las cajas de 3×3**. La estructura se dice dos veces, a propósito: las
/// casillas se agrupan por el ritmo de los huecos —casi juntas dentro de una
/// caja, separadas entre cajas— y por esos mismos huecos corre una rejilla
/// dibujada, fina entre casillas y gruesa entre cajas, con un marco alrededor.
/// Las dos señales tienen que coincidir al píxel, y un reparto mal calculado
/// no revienta ni desborda: deja una línea pisando una casilla o una caja
/// agrupada 4-3-2. Sacarlo aquí es lo que permite medirlo en una prueba en vez
/// de mirarlo.
///
/// Nueve columnas, ocho separaciones internas —seis pequeñas y dos grandes— y
/// un margen a cada lado para el marco.
library;

import 'dart:math' show max;
import 'dart:ui' show Rect;

import 'grid.dart';

class BoardMetrics {
  const BoardMetrics(this.side);

  /// Lado del tablero en píxeles lógicos. Todo lo demás sale de aquí, así que
  /// el tablero se ve igual en un móvil bajo que en una tablet.
  final double side;

  // ── Líneas ─────────────────────────────────────────────

  /// Grosor de la línea fina, entre casillas de la misma caja. Nunca baja de
  /// un píxel lógico: por debajo se convierte en una sombra gris.
  double get thin => max(1.0, side * 0.0030);

  /// Grosor de la línea gruesa, entre cajas y en el marco.
  double get thick => max(2.0, side * 0.0065);

  // ── Huecos ─────────────────────────────────────────────
  //
  // Cada hueco lleva su línea por el centro y tiene que sobrarle aire a los dos
  // lados: una línea que roza la superelipse se come la curva de la esquina y
  // la casilla vuelve a parecer un bloque.

  /// Hueco entre casillas de la misma caja. Lleva dentro la línea fina.
  double get cellGap => side * 0.012;

  /// Hueco entre cajas. Lleva dentro la línea gruesa y **tiene que verse
  /// claramente mayor que [cellGap]**: el ritmo dice las cajas igual que las
  /// líneas, y para quien no lea la línea tiene que bastar el espacio.
  double get boxGap => side * 0.032;

  /// Margen entre el borde del tablero y la primera casilla. El marco va
  /// pegado al borde, por dentro, y a la primera casilla le queda el mismo
  /// aire que a cualquier casilla le queda de una línea gruesa.
  double get edge => (boxGap + thick) / 2;

  double get cell => (side - 2 * edge - 6 * cellGap - 2 * boxGap) / boardSize;

  // ── Formas ─────────────────────────────────────────────

  /// Radio de la casilla. Superelipse, no rectángulo redondeado: la curva
  /// entra en el lado recto de forma continua y es lo que quita el aspecto de
  /// bloque sin llegar a parecer una pastilla.
  double get radius => cell * 0.26;

  /// Radio de la casilla seleccionada. Más redondo que el resto, para que
  /// seleccionar cambie la FORMA y no solo el color.
  double get selectedRadius => cell * 0.42;

  /// Radio del marco. Concéntrico con las casillas de las esquinas: el radio
  /// de fuera es el de dentro más la distancia entre ambos, que es la regla
  /// que hace que dos curvas anidadas parezcan la misma curva.
  double get frameRadius => radius + edge;

  // ── Posiciones ─────────────────────────────────────────

  /// Distancia desde el borde del tablero hasta el inicio de la fila o columna
  /// `i`. Cuenta cuántas separaciones de cada clase han quedado detrás.
  double offsetOf(int i) =>
      edge + i * cell + (i - i ~/ boxSize) * cellGap + (i ~/ boxSize) * boxGap;

  Rect rectOf(int index) =>
      Rect.fromLTWH(offsetOf(colOf(index)), offsetOf(rowOf(index)), cell, cell);

  /// Si la separación que sigue a la fila o columna `i` (0..7) es un salto de
  /// caja, y por tanto lleva línea gruesa.
  bool isBoxLine(int i) => (i + 1) % boxSize == 0;

  /// Grosor de la línea que corre por la separación que sigue a `i`.
  double lineWidthAfter(int i) => isBoxLine(i) ? thick : thin;

  /// Centro de la línea que corre por la separación que sigue a `i`: justo a
  /// mitad del hueco, sea del tamaño que sea.
  double lineAt(int i) {
    final gap = isBoxLine(i) ? boxGap : cellGap;
    return offsetOf(i + 1) - gap / 2;
  }
}

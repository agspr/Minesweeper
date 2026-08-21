/// Dónde cae cada casilla dentro del tablero.
///
/// Vive fuera del widget porque desde que la rejilla no tiene líneas, **esta
/// aritmética es lo único que dice dónde están las cajas de 3×3**. Antes la
/// estructura la dibujaba un trazo grueso cada tres columnas; ahora la dibuja
/// el ritmo de los huecos, y un ritmo mal calculado no revienta ni desborda:
/// simplemente deja un tablero que no se puede leer. Sacarlo aquí es lo que
/// permite medirlo en una prueba en vez de mirarlo.
///
/// El reparto: dentro de una caja las casillas casi se tocan; entre cajas hay
/// un hueco visiblemente mayor. Nueve columnas, ocho separaciones internas —
/// seis pequeñas y dos grandes.
library;

import 'dart:ui' show Rect;

import 'grid.dart';

class BoardMetrics {
  const BoardMetrics(this.side);

  /// Lado del tablero en píxeles lógicos. Todo lo demás sale de aquí, así que
  /// el tablero se ve igual en un móvil bajo que en una tablet.
  final double side;

  /// Hueco entre casillas de la misma caja.
  double get cellGap => side * 0.006;

  /// Hueco entre cajas. **Tiene que verse claramente mayor que [cellGap]**: es
  /// el único canal que queda para las cajas de 3×3.
  double get boxGap => side * 0.020;

  double get cell => (side - 6 * cellGap - 2 * boxGap) / boardSize;

  /// Radio de la casilla. Superelipse, no rectángulo redondeado: la curva
  /// entra en el lado recto de forma continua y es lo que quita el aspecto de
  /// bloque sin llegar a parecer una pastilla.
  double get radius => cell * 0.26;

  /// Radio de la casilla seleccionada. Más redondo que el resto, para que
  /// seleccionar cambie la FORMA y no solo el color.
  double get selectedRadius => cell * 0.42;

  /// Distancia desde el borde del tablero hasta el inicio de la fila o columna
  /// `i`. Cuenta cuántas separaciones de cada clase han quedado detrás.
  double offsetOf(int i) =>
      i * cell + (i - i ~/ boxSize) * cellGap + (i ~/ boxSize) * boxGap;

  Rect rectOf(int index) =>
      Rect.fromLTWH(offsetOf(colOf(index)), offsetOf(rowOf(index)), cell, cell);
}

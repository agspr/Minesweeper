/// Dónde cae cada casilla dentro del tablero de Buscaminas, y por dónde pasan las líneas.
///
/// Cuadrícula 100% uniforme con casillas perfectamente cuadradas, separación
/// idéntica entre todas las filas y columnas, y marcos concéntricos sin
/// divisiones de Sudoku ni líneas gruesas asimétricas.
library;

import 'dart:math' show max, min;
import 'dart:ui' show Offset, Rect;

import 'grid.dart';

class BoardMetrics {
  const BoardMetrics(
    this.side, {
    this.cols = boardSize,
    this.rows = boardSize,
  });

  /// Ajusta el tablero rectangular `cols × rows` dentro de una caja disponible
  /// de `maxWidth × maxHeight` sin desbordar jamás en ninguna orientación.
  factory BoardMetrics.fit({
    required double maxWidth,
    required double maxHeight,
    int cols = boardSize,
    int rows = boardSize,
  }) {
    final byW = BoardMetrics(maxWidth, cols: cols, rows: rows);
    if (byW.height <= maxHeight) return byW;
    final ratio = maxHeight / byW.height;
    var scaled = BoardMetrics(maxWidth * ratio, cols: cols, rows: rows);
    if (scaled.height > maxHeight && scaled.height > 0) {
      scaled = BoardMetrics(
        scaled.side * (maxHeight / scaled.height),
        cols: cols,
        rows: rows,
      );
    }
    return scaled;
  }

  /// Ancho de referencia del tablero en píxeles lógicos.
  final double side;
  final int cols;
  final int rows;

  // ── Líneas y separaciones (100% uniformes) ──────────────

  /// Grosor de las líneas separadoras entre casillas (idéntico en toda la cuadrícula).
  double get thin => max(1.0, side * 0.0035);

  /// Grosor del marco perimetral exterior.
  double get thick => max(2.0, side * 0.0070);

  /// Espaciado uniforme e idéntico entre casillas consecutivas (tanto filas como columnas).
  double get cellGap => max(2.0, side * 0.012);

  /// Margen uniforme exterior entre el borde del tablero y la primera casilla.
  double get edge => cellGap + thick;

  /// Tamaño de cada casilla individual cuadrada.
  double get cell => (side - 2 * edge - (cols - 1) * cellGap) / cols;

  /// Ancho total del tablero en píxeles lógicos.
  double get width => 2 * edge + cols * cell + (cols - 1) * cellGap;

  /// Alto total del tablero en píxeles lógicos.
  double get height => 2 * edge + rows * cell + (rows - 1) * cellGap;

  double get shortestSide => min(width, height);

  // ── Formas Material 3 Expressive ─────────────────────────

  /// Radio micro-superelíptico (~10%) para evitar huecos romboidales en las
  /// intersecciones de 4 casillas cubiertas, manteniendo esquinas suaves.
  double get radius => max(2.5, cell * 0.10);

  /// Radio expresivo ampliado al seleccionar o activar una casilla.
  double get selectedRadius => max(4.5, cell * 0.22);

  double get frameRadius => max(8.0, radius + edge);

  // ── Posiciones ───────────────────────────────────────────

  /// Coordenada lógica de inicio de la casilla `i` en cualquier eje.
  double offsetOf(int i) => edge + i * (cell + cellGap);

  Rect rectOf(int index) => Rect.fromLTWH(
    offsetOf(colOf(index, cols)),
    offsetOf(rowOf(index, cols)),
    cell,
    cell,
  );

  /// Resuelve cualquier coordenada `(dx, dy)` dentro del tablero a la casilla
  /// más cercana sin zonas muertas en los canales (`cellGap`) ni en el borde (`edge`).
  /// Devuelve `-1` únicamente si el toque cae fuera del rectángulo del tablero.
  int cellAt(Offset localPosition) {
    final dx = localPosition.dx;
    final dy = localPosition.dy;
    if (dx < 0 || dy < 0 || dx > width || dy > height) return -1;
    final step = cell + cellGap;
    final c = ((dx - edge + cellGap / 2) / step).floor().clamp(0, cols - 1);
    final r = ((dy - edge + cellGap / 2) / step).floor().clamp(0, rows - 1);
    return r * cols + c;
  }

  /// En Buscaminas no existen subdivisiones de caja: todas las líneas son uniformes.
  bool isBoxLine(int i) => false;

  /// Ancho de línea entre casillas: uniforme en todo el tablero.
  double lineWidthAfter(int i) => thin;

  /// Posición central de la línea separadora tras el índice `i`.
  double lineAt(int i) => offsetOf(i) + cell + cellGap / 2;

  /// Alias de compatibilidad hacia atrás.
  double get boxGap => cellGap;
}

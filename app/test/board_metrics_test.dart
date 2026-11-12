import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/board_metrics.dart';
import 'package:nona/game/grid.dart';

/// Pruebas métricas de la cuadrícula de Buscaminas:
/// - 100% uniforme: misma separación y mismas líneas en todas las filas y columnas.
/// - Sin cajas asimétricas ni líneas más gruesas que otras.
/// - Casillas perfectamente cuadradas concéntricas al marco exterior.
void main() {
  const lados = [280.0, 360.0, 720.0];

  for (final lado in lados) {
    final m = BoardMetrics(lado);

    group('lado $lado', () {
      test('todas las casillas caben exactas con margen simétrico', () {
        expect(
          m.offsetOf(boardSize - 1) + m.cell,
          closeTo(lado - m.edge, 0.001),
        );
        expect(m.offsetOf(0), closeTo(m.edge, 0.001));
      });

      test('todas las líneas intermedias tienen grosor uniforme', () {
        for (var i = 0; i < boardSize - 1; i++) {
          final w = m.lineWidthAfter(i);
          expect(w, equals(m.thin), reason: 'la línea $i no es uniforme');

          final antes = m.offsetOf(i) + m.cell;
          final despues = m.offsetOf(i + 1);
          expect(
            m.lineAt(i) - w / 2 - antes,
            greaterThanOrEqualTo(0.5),
            reason: 'la línea tras la columna $i roza la casilla de antes',
          );
          expect(
            despues - (m.lineAt(i) + w / 2),
            greaterThanOrEqualTo(0.5),
            reason: 'la línea tras la columna $i roza la casilla de después',
          );
        }
      });

      test('todos los huecos entre casillas son idénticos (sin saltos de caja)', () {
        double hueco(int i) => m.offsetOf(i + 1) - (m.offsetOf(i) + m.cell);
        for (var i = 0; i < boardSize - 1; i++) {
          expect(hueco(i), closeTo(m.cellGap, 0.001));
          expect(m.isBoxLine(i), isFalse);
        }
      });

      test('ninguna casilla se solapa con la siguiente', () {
        for (var i = 0; i < boardSize - 1; i++) {
          expect(
            m.offsetOf(i) + m.cell,
            lessThan(m.offsetOf(i + 1)),
            reason: 'la columna $i pisa a la ${i + 1}',
          );
        }
      });

      test('cada casilla cae dentro del tablero y es perfectamente cuadrada', () {
        for (var index = 0; index < cellCount; index++) {
          final r = m.rectOf(index);
          expect(r.left, greaterThanOrEqualTo(0));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.right, lessThanOrEqualTo(lado + 0.001));
          expect(r.bottom, lessThanOrEqualTo(lado + 0.001));
          expect(
            r.width,
            closeTo(r.height, 0.001),
            reason: 'casilla no cuadrada',
          );
        }
      });

      test('la seleccionada se redondea más sin llegar a círculo', () {
        expect(m.selectedRadius, greaterThan(m.radius * 1.3));
        expect(m.selectedRadius, lessThan(m.cell / 2));
      });

      test('cellAt resuelve el 100% del tablero sin zonas muertas en canales ni bordes', () {
        // Centro de cada casilla
        for (var index = 0; index < cellCount; index++) {
          expect(m.cellAt(m.rectOf(index).center), equals(index));
        }
        // Borde exterior izquierdo/superior cae en la casilla 0
        expect(m.cellAt(const Offset(1, 1)), equals(0));
        // Canal entre casilla 0 y casilla 1 cae en la más cercana sin devolver -1
        final midGap = m.offsetOf(0) + m.cell + m.cellGap * 0.4;
        expect(m.cellAt(Offset(midGap, m.rectOf(0).center.dy)), equals(0));
        final pastMidGap = m.offsetOf(0) + m.cell + m.cellGap * 0.6;
        expect(m.cellAt(Offset(pastMidGap, m.rectOf(0).center.dy)), equals(1));
      });
    });
  }
}

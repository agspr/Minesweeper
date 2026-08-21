import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/board_metrics.dart';
import 'package:nona/game/grid.dart';

/// El ritmo del tablero, medido.
///
/// Desde que la rejilla no tiene líneas, **las cajas de 3×3 solo existen en
/// esta aritmética**. Un reparto mal hecho no revienta, no desborda y compila
/// igual: deja un tablero que no se puede leer, y eso no lo caza ninguna de las
/// pruebas de disposición, que miran si algo se sale.
void main() {
  // Un móvil bajo, un móvil normal y una tablet. La aritmética es proporcional,
  // así que lo que valga en los tres vale en todos.
  const lados = [280.0, 360.0, 720.0];

  for (final lado in lados) {
    final m = BoardMetrics(lado);

    group('lado $lado', () {
      test('las 81 casillas caben exactas, sin sobrar ni faltar', () {
        // La última casilla termina justo en el borde. Si sobrara, el tablero
        // quedaría descentrado; si faltara, se saldría.
        expect(m.offsetOf(boardSize - 1) + m.cell, closeTo(lado, 0.001));
        expect(m.offsetOf(0), 0);
      });

      test('el hueco entre cajas se ve claramente mayor que el de casillas', () {
        // ESTA es la prueba que sustituye a la línea gruesa. Si los dos huecos
        // se parecieran, las cajas de 3×3 desaparecerían y el tablero se
        // volvería una cuadrícula plana de 81 casillas.
        expect(m.boxGap, greaterThan(m.cellGap * 2.5));
        // Y un hueco por debajo de un píxel no es un hueco.
        expect(m.cellGap, greaterThan(1.0));
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

      test('los saltos de caja caen entre la 2ª y la 3ª, y la 5ª y la 6ª', () {
        // Que el hueco grande esté en el sitio EQUIVOCADO es el fallo que peor
        // se ve y más fácil es de escribir: un `~/` mal puesto agrupa 4-3-2 en
        // vez de 3-3-3 y el tablero sigue pareciendo un tablero.
        double hueco(int i) => m.offsetOf(i + 1) - (m.offsetOf(i) + m.cell);
        for (var i = 0; i < boardSize - 1; i++) {
          final esSaltoDeCaja = (i + 1) % boxSize == 0;
          expect(
            hueco(i),
            closeTo(esSaltoDeCaja ? m.boxGap : m.cellGap, 0.001),
            reason: esSaltoDeCaja
                ? 'falta el salto de caja tras la columna $i'
                : 'sobra un salto de caja tras la columna $i',
          );
        }
      });

      test('cada casilla cae dentro del tablero', () {
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

      test('la seleccionada se redondea más, pero no llega a círculo', () {
        // El canal de forma solo sirve si se distingue del resto...
        expect(m.selectedRadius, greaterThan(m.radius * 1.4));
        // ...y deja de servir si la casilla se convierte en un botón redondo,
        // porque entonces pierde el sitio donde caben las anotaciones.
        expect(m.selectedRadius, lessThan(m.cell / 2));
      });
    });
  }
}

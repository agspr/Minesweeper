import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/board_metrics.dart';
import 'package:nona/game/grid.dart';

/// El ritmo del tablero y sus líneas, medidos.
///
/// **Las cajas de 3×3 solo existen en esta aritmética**, que las dice dos
/// veces: por el ritmo de los huecos y por las líneas que corren por ellos. Un
/// reparto mal hecho no revienta, no desborda y compila igual: deja una línea
/// pisando la curva de una casilla, o una caja agrupada 4-3-2, y eso no lo caza
/// ninguna de las pruebas de disposición, que miran si algo se sale.
void main() {
  // Un móvil bajo, un móvil normal y una tablet. La aritmética es proporcional,
  // así que lo que valga en los tres vale en todos.
  const lados = [280.0, 360.0, 720.0];

  for (final lado in lados) {
    final m = BoardMetrics(lado);

    group('lado $lado', () {
      test('las 81 casillas caben exactas, con el mismo margen a cada lado', () {
        // La última casilla termina a la misma distancia del borde que empieza
        // la primera. Si no, el tablero queda descentrado dentro de su marco.
        expect(
          m.offsetOf(boardSize - 1) + m.cell,
          closeTo(lado - m.edge, 0.001),
        );
        expect(m.offsetOf(0), closeTo(m.edge, 0.001));
      });

      test('cada línea cabe en su hueco con aire a los dos lados', () {
        // Una línea que roza la superelipse se come la curva de la esquina y
        // la casilla vuelve a parecer un bloque. Al menos un píxel de aire.
        for (var i = 0; i < boardSize - 1; i++) {
          final w = m.lineWidthAfter(i);
          final antes = m.offsetOf(i) + m.cell;
          final despues = m.offsetOf(i + 1);
          expect(
            m.lineAt(i) - w / 2 - antes,
            greaterThanOrEqualTo(1.0),
            reason: 'la línea tras la columna $i roza la casilla de antes',
          );
          expect(
            despues - (m.lineAt(i) + w / 2),
            greaterThanOrEqualTo(1.0),
            reason: 'la línea tras la columna $i roza la casilla de después',
          );
          // Y centrada: el mismo aire a cada lado.
          expect(
            m.lineAt(i) - antes,
            closeTo(despues - m.lineAt(i), 0.001),
            reason: 'la línea tras la columna $i no va por el centro',
          );
        }
        // El marco también: pegado al borde y con aire hasta la primera.
        expect(m.edge - m.thick, greaterThanOrEqualTo(1.0));
      });

      test('la gruesa se distingue de la fina, y la fina se ve', () {
        expect(m.thick, greaterThanOrEqualTo(m.thin * 1.8));
        expect(m.thin, greaterThanOrEqualTo(1.0));
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
        // vez de 3-3-3 y el tablero sigue pareciendo un tablero. Y el hueco
        // grande y la línea gruesa tienen que caer en el MISMO sitio: si el
        // ritmo dijera una cosa y el trazo otra, el tablero mentiría.
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
          expect(m.isBoxLine(i), esSaltoDeCaja);
          expect(m.lineWidthAfter(i), esSaltoDeCaja ? m.thick : m.thin);
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

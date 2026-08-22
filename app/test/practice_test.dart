import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/practice_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El modo libre **no puntúa** (§1), y de ahí sale casi todo lo que se prueba
/// aquí: existen pistas porque no hay puntos que falsear, y ningún camino de
/// este fichero toca `scoring.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PracticeController> make() async {
    final c = PracticeController(await SharedPreferences.getInstance());
    await c.load();
    return c;
  }

  test('arranca con un puzle jugable', () async {
    final c = await make();
    expect(c.board, isNotNull);
    expect(c.generating, isFalse);
    expect(c.board!.completionPercent, 0);
    expect(c.difficulty, Difficulty.easy);
  });

  test('cambiar de dificultad trae un puzle nuevo de ese grado', () async {
    final c = await make();
    final antes = c.board!.givens.join();
    await c.setDifficulty(Difficulty.hard);
    expect(c.difficulty, Difficulty.hard);
    expect(c.board!.givens.join(), isNot(antes));
    // Un difícil lleva menos pistas que un fácil: es la señal de que de verdad
    // cambió de grado y no solo de etiqueta.
    expect(c.board!.givens.where((v) => v != 0).length, lessThan(35));
  });

  test('"otro puzle" cambia el tablero y limpia el progreso', () async {
    final c = await make();
    final cell = _firstEmpty(c);
    c.select(cell);
    c.tapDigit(c.board!.solution[cell]);
    expect(c.board!.correctCount, 1);
    final antes = c.board!.givens.join();

    await c.newPuzzle();
    expect(c.board!.givens.join(), isNot(antes));
    expect(c.board!.correctCount, 0);
    expect(c.board!.mistakes, 0);
    expect(c.selected, -1);
  });

  group('pistas (solo en el modo libre)', () {
    test('rellenan la casilla seleccionada con el dígito correcto', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      c.hint();
      expect(c.board!.entries[cell], c.board!.solution[cell]);
      expect(c.hintsUsed, 1);
    });

    test('una pista NUNCA cuenta como fallo', () async {
      final c = await make();
      c.select(_firstEmpty(c));
      c.hint();
      c.hint();
      c.hint();
      expect(c.board!.mistakes, 0, reason: 'una pista pone el dígito correcto');
      expect(c.hintsUsed, 3);
    });

    test('sin selección, elige una casilla sin resolver', () async {
      final c = await make();
      expect(c.selected, -1);
      c.hint();
      expect(c.selected, greaterThanOrEqualTo(0));
      expect(c.board!.entries[c.selected], c.board!.solution[c.selected]);
    });

    test('sobre una casilla ya correcta, va a otra sin resolver', () async {
      final c = await make();
      final cell = _firstEmpty(c);
      c.select(cell);
      c.tapDigit(c.board!.solution[cell]);
      c.hint();
      expect(
        c.board!.correctCount,
        2,
        reason: 'no debe malgastarse en una ya hecha',
      );
    });

    test('a base de pistas se termina el puzle', () async {
      final c = await make();
      var guard = 0;
      while (!c.isComplete && guard++ < 200) {
        c.hint();
      }
      expect(c.isComplete, isTrue);
      expect(c.board!.mistakes, 0);
    });
  });

  test('los fallos se cuentan igual, aunque no puntúen', () async {
    // El tablero es el mismo objeto que en la diaria: sigue marcando el error
    // en rojo, que es lo que enseña. Lo que no hay aquí es puntuación.
    final c = await make();
    final cell = _firstEmpty(c);
    c.select(cell);
    final right = c.board!.solution[cell];
    c.tapDigit(right == 9 ? 1 : right + 1);
    expect(c.board!.mistakes, 1);
    expect(c.board!.isWrong(cell), isTrue);
  });

  test('el puzle a medias sobrevive a cerrar la app', () async {
    final prefs = await SharedPreferences.getInstance();
    final c1 = PracticeController(prefs);
    await c1.load();
    final cell = _firstEmpty(c1);
    c1.select(cell);
    c1.tapDigit(c1.board!.solution[cell]);
    final givens = c1.board!.givens.join();

    final c2 = PracticeController(prefs);
    await c2.load();
    expect(c2.board!.givens.join(), givens, reason: 'debe ser el MISMO puzle');
    expect(c2.board!.correctCount, 1);
  });

  test('un guardado corrupto no deja al jugador sin puzle', () async {
    SharedPreferences.setMockInitialValues({
      'game.nona.practice': 'no es json',
    });
    final c = PracticeController(await SharedPreferences.getInstance());
    await c.load();
    expect(c.board, isNotNull, reason: 'debe generar uno limpio');
  });
}

int _firstEmpty(PracticeController c) {
  for (var i = 0; i < cellCount; i++) {
    if (!c.board!.isGiven(i) && c.board!.entries[i] == 0) return i;
  }
  throw StateError('sin casillas vacías');
}

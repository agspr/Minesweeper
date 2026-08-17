import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/sudoku_board.dart';

void main() {
  // Un puzle real del generador, no uno inventado: así las pruebas se apoyan en
  // un tablero con solución única de verdad.
  final puzzle = generate(seed: 2026, target: Difficulty.easy)!;
  SudokuBoard fresh() => SudokuBoard.fromStrings(
    givens: puzzle.givens,
    solution: puzzle.solution,
  );

  /// Primera casilla vacía, y el dígito que le toca.
  (int, int) firstEmpty(SudokuBoard b) {
    for (var cell = 0; cell < cellCount; cell++) {
      if (!b.isGiven(cell)) return (cell, b.solution[cell]);
    }
    throw StateError('el puzle no tiene casillas vacías');
  }

  group('pistas', () {
    test('no se pueden escribir, borrar ni anotar', () {
      final b = fresh();
      final given = List.generate(cellCount, (i) => i).firstWhere(b.isGiven);
      final before = b.valueAt(given);
      b.place(given, before == 1 ? 2 : 1);
      b.erase(given);
      b.toggleNote(given, 5);
      expect(b.valueAt(given), before);
      expect(b.notes[given], 0);
      expect(b.mistakes, 0);
    });
  });

  group('fallos (diseño §4)', () {
    test('escribir mal cuenta un fallo; escribir bien no', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      final wrong = right == 9 ? 1 : right + 1;
      expect(b.place(cell, wrong), isTrue);
      expect(b.mistakes, 1);
      expect(b.place(cell, right), isFalse);
      expect(b.mistakes, 1);
    });

    test('CADA entrada equivocada cuenta: 3 y luego 7 son dos fallos', () {
      // La decisión está tomada: es la lectura literal de "una casilla escrita
      // que no coincide con la solución", y es lo que hace alcanzable el suelo
      // de 5 fallos.
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      final wrongs = [1, 2, 3, 4, 5, 6, 7, 8, 9].where((d) => d != right).toList();
      b.place(cell, wrongs[0]);
      b.place(cell, wrongs[1]);
      expect(b.mistakes, 2);
    });

    test('repetir la MISMA tecla equivocada no penaliza dos veces', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      final wrong = right == 9 ? 1 : right + 1;
      b.place(cell, wrong);
      b.place(cell, wrong);
      expect(b.mistakes, 1);
    });

    test('borrar NO descuenta el fallo', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      b.place(cell, right == 9 ? 1 : right + 1);
      b.erase(cell);
      expect(b.mistakes, 1, reason: 'borrar no puede lavar un fallo');
    });

    test('deshacer NO descuenta el fallo', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      b.place(cell, right == 9 ? 1 : right + 1);
      b.undo();
      expect(b.entries[cell], 0);
      expect(b.mistakes, 1, reason: 'deshacer no puede lavar un fallo');
    });

    test('las anotaciones nunca cuentan como fallo', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      for (var d = 1; d <= 9; d++) {
        b.toggleNote(cell, d);
      }
      expect(b.mistakes, 0);
      expect(b.isWrong(cell), isFalse);
      expect(right, isNotNull);
    });
  });

  group('avance', () {
    test('se mide en casillas correctas, y la basura no cuenta', () {
      final b = fresh();
      expect(b.completionPercent, 0);
      var filled = 0;
      for (var cell = 0; cell < cellCount && filled < 3; cell++) {
        if (b.isGiven(cell)) continue;
        final right = b.solution[cell];
        b.place(cell, right == 9 ? 1 : right + 1); // mal a propósito
        filled++;
      }
      expect(
        b.completionPercent,
        0,
        reason: 'llenar de basura no puede subir el avance',
      );
      expect(b.mistakes, 3);
    });

    test('llega a 100 y se marca resuelto al completarlo bien', () {
      final b = fresh();
      for (var cell = 0; cell < cellCount; cell++) {
        if (!b.isGiven(cell)) b.place(cell, b.solution[cell]);
      }
      expect(b.completionPercent, 100);
      expect(b.isComplete, isTrue);
      expect(b.mistakes, 0);
    });

    test('no está resuelto mientras quede una casilla mal', () {
      final b = fresh();
      int? last;
      for (var cell = 0; cell < cellCount; cell++) {
        if (!b.isGiven(cell)) {
          last = cell;
          b.place(cell, b.solution[cell]);
        }
      }
      final right = b.solution[last!];
      b.place(last, right == 9 ? 1 : right + 1);
      expect(b.isComplete, isFalse);
      expect(b.isWrong(last), isTrue);
    });
  });

  group('anotaciones', () {
    test('se ponen y se quitan', () {
      final b = fresh();
      final (cell, _) = firstEmpty(b);
      b.toggleNote(cell, 4);
      expect(b.hasNote(cell, 4), isTrue);
      b.toggleNote(cell, 4);
      expect(b.hasNote(cell, 4), isFalse);
    });

    test('escribir un dígito lo borra de las anotaciones vecinas', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      final peer = peers[cell].firstWhere((p) => !b.isGiven(p));
      b.toggleNote(peer, right);
      expect(b.hasNote(peer, right), isTrue);
      b.place(cell, right);
      expect(
        b.hasNote(peer, right),
        isFalse,
        reason: 'la anotación vecina debería limpiarse sola',
      );
    });

    test('deshacer devuelve también las anotaciones vecinas', () {
      // Es el motivo de que una jugada guarde el mapa completo y no solo la
      // casilla escrita.
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      final peer = peers[cell].firstWhere((p) => !b.isGiven(p));
      b.toggleNote(peer, right);
      b.place(cell, right);
      b.undo();
      expect(b.entries[cell], 0);
      expect(
        b.hasNote(peer, right),
        isTrue,
        reason: 'deshacer tiene que restaurar la anotación arrastrada',
      );
    });

    test('no se anota sobre una casilla ya escrita', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      b.place(cell, right);
      b.toggleNote(cell, 3);
      expect(b.hasNote(cell, 3), isFalse);
    });
  });

  group('deshacer', () {
    test('sin jugadas no hace nada', () {
      final b = fresh();
      expect(b.canUndo, isFalse);
      b.undo();
      expect(b.mistakes, 0);
    });

    test('varias jugadas se deshacen en orden inverso', () {
      final b = fresh();
      final empties = [
        for (var c = 0; c < cellCount; c++)
          if (!b.isGiven(c)) c,
      ].take(3).toList();
      for (final c in empties) {
        b.place(c, b.solution[c]);
      }
      expect(b.correctCount, 3);
      b.undo();
      expect(b.entries[empties[2]], 0);
      expect(b.correctCount, 2);
      b.undo();
      b.undo();
      expect(b.correctCount, 0);
      expect(b.canUndo, isFalse);
    });
  });

  group('numpad', () {
    test('cuenta cuántas quedan de cada dígito', () {
      final b = fresh();
      final placed = b.givens.where((v) => v == 1).length;
      expect(b.remainingOf(1), 9 - placed);
      final (cell, right) = firstEmpty(b);
      b.place(cell, right);
      expect(b.remainingOf(right), 9 - b.givens.where((v) => v == right).length - 1);
    });
  });

  group('guardar y restaurar', () {
    test('ida y vuelta conserva entradas, anotaciones y fallos', () {
      final b = fresh();
      final (cell, right) = firstEmpty(b);
      b.place(cell, right);
      final other = [
        for (var c = 0; c < cellCount; c++)
          if (!b.isGiven(c) && c != cell) c,
      ].first;
      b.toggleNote(other, 7);
      b.place(other, right == 9 ? 1 : right + 1); // un fallo
      // place() borra las anotaciones de su propia casilla, así que se anota en
      // una tercera para comprobar que sobreviven al guardado.
      final third = [
        for (var c = 0; c < cellCount; c++)
          if (!b.isGiven(c) && c != cell && c != other) c,
      ].first;
      b.toggleNote(third, 2);
      b.toggleNote(third, 9);

      final restored = SudokuBoard.restore(
        givens: puzzle.givens,
        solution: puzzle.solution,
        saved: b.toJson(),
      );
      expect(restored.entries, b.entries);
      expect(restored.notes, b.notes);
      expect(restored.mistakes, b.mistakes);
      expect(restored.completionPercent, b.completionPercent);
    });

    test('un guardado corrupto no rompe: se empieza limpio', () {
      final restored = SudokuBoard.restore(
        givens: puzzle.givens,
        solution: puzzle.solution,
        saved: const {'entries': 'basura', 'notes': 'x,y', 'mistakes': null},
      );
      expect(restored.mistakes, 0);
      expect(restored.completionPercent, 0);
    });

    test('un guardado no puede sobrescribir una pista', () {
      // Defensa contra un fichero manipulado o un rehorneado del banco: las
      // pistas mandan siempre sobre lo guardado.
      final b = fresh();
      final given = List.generate(cellCount, (i) => i).firstWhere(b.isGiven);
      final fake = List<int>.filled(cellCount, 0);
      fake[given] = b.givens[given] == 9 ? 1 : b.givens[given] + 1;
      final restored = SudokuBoard.restore(
        givens: puzzle.givens,
        solution: puzzle.solution,
        saved: {'entries': encodeGrid(fake), 'mistakes': 0},
      );
      expect(restored.entries[given], 0);
      expect(restored.valueAt(given), b.givens[given]);
    });
  });
}

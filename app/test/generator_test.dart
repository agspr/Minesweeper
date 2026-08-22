import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/prng.dart';
import 'package:nona/game/solver.dart';

void main() {
  group('Prng', () {
    test('misma semilla, misma secuencia', () {
      final a = Prng(12345);
      final b = Prng(12345);
      expect(
        List.generate(200, (_) => a.next()),
        List.generate(200, (_) => b.next()),
      );
    });

    test('semillas distintas divergen', () {
      final a = Prng(1);
      final b = Prng(2);
      expect(
        List.generate(50, (_) => a.next()),
        isNot(List.generate(50, (_) => b.next())),
      );
    });

    test('semillas contiguas y pequeñas no producen secuencias parecidas', () {
      // Es lo que motiva el sembrado con SplitMix32: sin él, Prng(0), Prng(1),
      // Prng(2)… arrancan con estados casi idénticos.
      final first = [for (var s = 0; s < 8; s++) Prng(s).next()];
      expect(first.toSet().length, 8);
    });

    test('nextInt se mantiene en rango', () {
      final p = Prng(7);
      for (var i = 0; i < 1000; i++) {
        final v = p.nextInt(9);
        expect(v, inInclusiveRange(0, 8));
      }
    });

    test('shuffle es una permutación', () {
      final list = List.generate(81, (i) => i);
      Prng(99).shuffle(list);
      expect(list.length, 81);
      expect(list.toSet().length, 81);
      expect(list, isNot(List.generate(81, (i) => i)));
    });
  });

  group('rejilla completa', () {
    test('es válida y determinista por semilla', () {
      for (var seed = 0; seed < 12; seed++) {
        final g = generateFullGrid(Prng(seed));
        expect(isSolved(g), isTrue, reason: 'semilla $seed');
        expect(g, generateFullGrid(Prng(seed)));
      }
    });

    test('semillas distintas dan rejillas distintas', () {
      expect(generateFullGrid(Prng(1)), isNot(generateFullGrid(Prng(2))));
    });
  });

  group('codificación', () {
    test('ida y vuelta', () {
      final g = generateFullGrid(Prng(3));
      expect(decodeGrid(encodeGrid(g)), g);
    });

    test('rechaza longitudes que no son 81', () {
      expect(() => decodeGrid('123'), throwsFormatException);
    });
  });

  group('countSolutions', () {
    test('una rejilla resuelta tiene exactamente una solución', () {
      expect(countSolutions(generateFullGrid(Prng(5))), 1);
    });

    test('el tablero vacío tiene muchas (corta en el límite)', () {
      expect(countSolutions(List.filled(cellCount, 0), limit: 2), 2);
    });

    test('detecta una rejilla contradictoria', () {
      final g = List.filled(cellCount, 0);
      g[0] = 5;
      g[1] = 5; // Mismo dígito dos veces en la fila 0.
      expect(countSolutions(g), 0);
    });

    test('detecta la ambigüedad al quitar una casilla de más', () {
      // Quitando las cuatro esquinas de un "rectángulo" de dos dígitos, esos
      // dos dígitos se pueden intercambiar: dos soluciones.
      final full = generateFullGrid(Prng(11));
      final g = List<int>.of(full);
      // Busca dos filas y dos columnas cuyos cuatro cruces usen solo 2 dígitos.
      var found = false;
      outer:
      for (var r1 = 0; r1 < 9 && !found; r1++) {
        for (var r2 = r1 + 1; r2 < 9; r2++) {
          for (var c1 = 0; c1 < 9; c1++) {
            for (var c2 = c1 + 1; c2 < 9; c2++) {
              final a = full[r1 * 9 + c1], b = full[r1 * 9 + c2];
              final c = full[r2 * 9 + c1], d = full[r2 * 9 + c2];
              if (a == d && b == c && a != b) {
                g[r1 * 9 + c1] = 0;
                g[r1 * 9 + c2] = 0;
                g[r2 * 9 + c1] = 0;
                g[r2 * 9 + c2] = 0;
                found = true;
                break outer;
              }
            }
          }
        }
      }
      expect(found, isTrue, reason: 'no se halló un rectángulo de prueba');
      expect(countSolutions(g, limit: 2), 2);
    });
  });

  group('generate', () {
    test('produce cada grado pedido, con solución única', () {
      for (final target in Difficulty.values) {
        final p = generate(seed: 2026, target: target);
        expect(p, isNotNull, reason: '$target no se generó');
        expect(p!.difficulty, target);
        expect(countSolutions(decodeGrid(p.givens), limit: 2), 1);
        // Las pistas son un subconjunto exacto de la solución.
        final givens = decodeGrid(p.givens);
        final solution = decodeGrid(p.solution);
        expect(isSolved(solution), isTrue);
        for (var i = 0; i < cellCount; i++) {
          if (givens[i] != 0) expect(givens[i], solution[i]);
        }
      }
    });

    test('es reproducible: misma semilla y grado → puzle idéntico', () {
      final a = generate(seed: 4242, target: Difficulty.medium)!;
      final b = generate(seed: 4242, target: Difficulty.medium)!;
      expect(a.givens, b.givens);
      expect(a.solution, b.solution);
      expect(a.seed, b.seed);
    });

    test('se resuelve sin adivinar y con la técnica propia de su grado', () {
      for (final target in Difficulty.values) {
        final p = generate(seed: 77, target: target)!;
        final report = solveLogically(decodeGrid(p.givens));
        expect(report.solved, isTrue, reason: '$target exigiría adivinar');
        expect(gradeFor(report, p.clueCount), target);
      }
    });

    test('el vaciado es simétrico a 180°', () {
      final p = generate(seed: 8, target: Difficulty.hard)!;
      final g = decodeGrid(p.givens);
      for (var i = 0; i < cellCount; i++) {
        expect(
          g[i] == 0,
          g[cellCount - 1 - i] == 0,
          reason: 'casilla $i y su simétrica no coinciden',
        );
      }
    });

    test('cada grado respeta su banda de pistas', () {
      // Son las bandas de digTargetFor, y las fija la prueba porque son lo que
      // hace que el grado signifique algo: un "fácil" de 26 pistas no sería
      // fácil por mucho que se resuelva con únicos.
      for (var seed = 300; seed < 312; seed++) {
        expect(
          generate(seed: seed, target: Difficulty.easy)!.clueCount,
          greaterThanOrEqualTo(32),
        );
        expect(
          generate(seed: seed, target: Difficulty.medium)!.clueCount,
          inInclusiveRange(28, 33),
        );
        expect(
          generate(seed: seed, target: Difficulty.hard)!.clueCount,
          greaterThanOrEqualTo(17),
        );
      }
    });

    test('en conjunto, los difíciles llevan menos pistas que los fáciles', () {
      // Por puzle suelto no tiene por qué cumplirse —un difícil puede llevar
      // muchas pistas si exige un X-Wing—, así que se compara la mediana.
      int median(Difficulty d) {
        final clues = [
          for (var seed = 400; seed < 412; seed++)
            generate(seed: seed, target: d)!.clueCount,
        ]..sort();
        return clues[clues.length ~/ 2];
      }

      expect(median(Difficulty.hard), lessThan(median(Difficulty.easy)));
    });

    test('ida y vuelta por JSON', () {
      final p = generate(seed: 5, target: Difficulty.easy)!;
      final back = SudokuPuzzle.fromJson(p.toJson());
      expect(back.givens, p.givens);
      expect(back.solution, p.solution);
      expect(back.difficulty, p.difficulty);
      expect(back.hardest, p.hardest);
      expect(back.seed, p.seed);
    });
  });

  group('lote: la unicidad se comprueba en TODOS, nunca por muestreo', () {
    test('40 puzles seguidos, todos únicos y del grado pedido', () {
      var generated = 0;
      for (var seed = 100; seed < 140; seed++) {
        final target = Difficulty.values[seed % 3];
        final p = generate(seed: seed, target: target);
        expect(p, isNotNull, reason: 'semilla $seed no convergió');
        expect(
          countSolutions(decodeGrid(p!.givens), limit: 2),
          1,
          reason: 'semilla $seed no es única',
        );
        expect(p.difficulty, target);
        generated++;
      }
      expect(generated, 40);
    });
  });

  group('gradeFor: técnica y presión de pistas', () {
    const singles = SolveReport(solved: true, hardest: Technique.hiddenSingle);
    const locked = SolveReport(
      solved: true,
      hardest: Technique.lockedCandidates,
    );
    const pair = SolveReport(solved: true, hardest: Technique.nakedPair);

    test('con únicos, mandan las pistas', () {
      expect(gradeFor(singles, 32), Difficulty.easy);
      expect(gradeFor(singles, 40), Difficulty.easy);
      expect(gradeFor(singles, 31), Difficulty.medium);
      expect(gradeFor(singles, 25), Difficulty.medium);
    });

    test('con candidatos confinados, medio holgado y difícil apretado', () {
      expect(gradeFor(locked, 28), Difficulty.medium);
      expect(gradeFor(locked, 27), Difficulty.hard);
    });

    test('de par desnudo en adelante, difícil pase lo que pase', () {
      expect(gradeFor(pair, 45), Difficulty.hard);
      expect(gradeFor(pair, 20), Difficulty.hard);
    });

    test('lo que exigiría adivinar no tiene grado', () {
      const guessy = SolveReport(solved: false, hardest: Technique.xWing);
      expect(gradeFor(guessy, 24), isNull);
    });
  });

  group('dificultad por día de la semana (diseño §3)', () {
    test('3 fáciles, 2 medios, 2 difíciles', () {
      expect(difficultyForWeekday(DateTime.monday), Difficulty.easy);
      expect(difficultyForWeekday(DateTime.tuesday), Difficulty.medium);
      expect(difficultyForWeekday(DateTime.wednesday), Difficulty.easy);
      expect(difficultyForWeekday(DateTime.thursday), Difficulty.medium);
      expect(difficultyForWeekday(DateTime.friday), Difficulty.easy);
      expect(difficultyForWeekday(DateTime.saturday), Difficulty.hard);
      expect(difficultyForWeekday(DateTime.sunday), Difficulty.hard);
    });

    test('la semana entera cuadra con el reparto locked', () {
      final week = [for (var d = 1; d <= 7; d++) difficultyForWeekday(d)];
      expect(week.where((d) => d == Difficulty.easy).length, 3);
      expect(week.where((d) => d == Difficulty.medium).length, 2);
      expect(week.where((d) => d == Difficulty.hard).length, 2);
    });

    test('rechaza un día fuera de rango', () {
      expect(() => difficultyForWeekday(0), throwsArgumentError);
      expect(() => difficultyForWeekday(8), throwsArgumentError);
    });
  });
}

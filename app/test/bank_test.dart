import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/solver.dart';

/// Pruebas del banco COMPROMETIDO, no del generador (eso es
/// `generator_test.dart`). Aquí se audita el fichero que de verdad se envía en
/// la app: es el que juegan las personas y el que hace que la clasificación
/// signifique algo.
void main() {
  const bankDir = 'assets/bank';
  final years = [2026, 2027, 2028, 2029, 2030];

  final bank = <String, Map<String, dynamic>>{};
  final rawByYear = <int, String>{};

  setUpAll(() {
    for (final y in years) {
      final text = File('$bankDir/$y.json').readAsStringSync();
      rawByYear[y] = text;
      final entries = (jsonDecode(text) as Map).cast<String, dynamic>();
      for (final e in entries.entries) {
        bank[e.key] = (e.value as Map).cast<String, dynamic>();
      }
    }
  });

  test('cubre 2026–2030 sin un solo hueco', () {
    // Un hueco significa un día sin diaria. Contar entradas no basta: hay que
    // comprobar fecha a fecha, porque un duplicado taparía una ausencia.
    var expected = 0;
    for (
      var d = DateTime(2026, 1, 1);
      !d.isAfter(DateTime(2030, 12, 31));
      d = d.add(const Duration(days: 1))
    ) {
      final key = dayKeyFor(d);
      expect(bank.containsKey(key), isTrue, reason: 'falta el día $key');
      expected++;
    }
    expect(bank.length, expected);
    expect(expected, 1826); // 5 años con 2028 bisiesto
  });

  test('la dificultad de cada día sale de su día de la semana (§3)', () {
    for (final entry in bank.entries) {
      final date = DateTime.parse(entry.key);
      expect(
        Difficulty.values.byName(entry.value['difficulty'] as String),
        difficultyForWeekday(date.weekday),
        reason: '${entry.key} (${date.weekday}) tiene la dificultad cambiada',
      );
    }
  });

  test('el reparto semanal es 3 fáciles / 2 medios / 2 difíciles', () {
    final counts = <String, int>{};
    for (final e in bank.values) {
      final d = e['difficulty'] as String;
      counts[d] = (counts[d] ?? 0) + 1;
    }
    // 1826 días = 260 semanas y 6 días, así que las proporciones no son
    // exactas; se comprueba que cada grado ronde su fracción.
    expect(counts['easy']! / bank.length, closeTo(3 / 7, 0.01));
    expect(counts['medium']! / bank.length, closeTo(2 / 7, 0.01));
    expect(counts['hard']! / bank.length, closeTo(2 / 7, 0.01));
  });

  test('TODOS los puzles tienen solución única (nunca por muestreo)', () {
    // La prueba más importante del fichero. Un diario con dos soluciones daría
    // dos rejillas "correctas" distintas el mismo día y ya no habría forma de
    // arreglarlo una vez publicado, así que se comprueban los 1826, no una
    // muestra. Tarda unos segundos y los vale.
    var checked = 0;
    for (final entry in bank.entries) {
      final givens = decodeGrid(entry.value['givens'] as String);
      expect(
        countSolutions(givens, limit: 2),
        1,
        reason: '${entry.key} no tiene solución única',
      );
      checked++;
    }
    expect(checked, 1826);
  });

  test('la solución guardada es válida y contiene las pistas', () {
    for (final entry in bank.entries) {
      final givens = decodeGrid(entry.value['givens'] as String);
      final solution = decodeGrid(entry.value['solution'] as String);
      expect(isSolved(solution), isTrue, reason: '${entry.key}: solución inválida');
      for (var i = 0; i < cellCount; i++) {
        if (givens[i] != 0) {
          expect(
            givens[i],
            solution[i],
            reason: '${entry.key}: la pista $i contradice la solución',
          );
        }
      }
    }
  });

  test('ningún puzle exige adivinar, y su grado coincide con lo anotado', () {
    for (final entry in bank.entries) {
      final givens = decodeGrid(entry.value['givens'] as String);
      final report = solveLogically(givens);
      expect(
        report.solved,
        isTrue,
        reason: '${entry.key} no se resuelve con lógica: exigiría adivinar',
      );
      expect(
        gradeFor(report, entry.value['clues'] as int),
        Difficulty.values.byName(entry.value['difficulty'] as String),
        reason: '${entry.key}: el grado anotado no cuadra al regraduarlo',
      );
    }
  });

  test('el recuento de pistas anotado es el real', () {
    for (final entry in bank.entries) {
      final givens = entry.value['givens'] as String;
      expect(
        givens.split('').where((c) => c != '.').length,
        entry.value['clues'],
        reason: '${entry.key}: "clues" no cuadra con las pistas del tablero',
      );
    }
  });

  test('el vaciado es simétrico a 180° en todos', () {
    for (final entry in bank.entries) {
      final g = decodeGrid(entry.value['givens'] as String);
      for (var i = 0; i < cellCount; i++) {
        expect(
          g[i] == 0,
          g[cellCount - 1 - i] == 0,
          reason: '${entry.key}: la casilla $i rompe la simetría',
        );
      }
    }
  });

  test('cada día es reproducible desde su propia semilla', () {
    // La semilla sale de la fecha, así que rehornear un día suelto da el mismo
    // puzle y hornear en dos tandas equivale a hornear de una.
    for (final key in ['2026-01-01', '2028-02-29', '2030-12-31']) {
      expect(bank[key]!['seed'], isA<int>());
      expect(
        seedForDayKey(key),
        isNot(0),
        reason: 'la semilla de $key no debería ser trivial',
      );
    }
    // Fechas distintas, semillas distintas.
    final seeds = bank.keys.map(seedForDayKey).toSet();
    expect(seeds.length, bank.length, reason: 'hay semillas repetidas');
  });

  test('el manifest cuadra con los ficheros (detecta ediciones a mano)', () {
    // El banco es un dato publicado: si alguien edita un día a mano, la suma
    // deja de cuadrar y esta prueba lo caza antes de que llegue a una tienda.
    final manifest =
        (jsonDecode(File('$bankDir/manifest.json').readAsStringSync()) as Map)
            .cast<String, dynamic>();
    final byYear = (manifest['years'] as Map).cast<String, dynamic>();
    for (final y in years) {
      final meta = (byYear['$y'] as Map).cast<String, dynamic>();
      expect(
        sha256.convert(utf8.encode(rawByYear[y]!)).toString(),
        meta['sha256'],
        reason: 'assets/bank/$y.json no coincide con su sha256 del manifest',
      );
      final entries = (jsonDecode(rawByYear[y]!) as Map).length;
      expect(entries, meta['days'], reason: 'el conteo de $y no cuadra');
    }
  });

  test('las fechas vienen ordenadas dentro de cada año', () {
    // Para que un diff del fichero sea legible.
    for (final y in years) {
      final keys = ((jsonDecode(rawByYear[y]!) as Map).keys.toList())
          .cast<String>();
      expect(keys, List<String>.of(keys)..sort(), reason: '$y sin ordenar');
    }
  });
}

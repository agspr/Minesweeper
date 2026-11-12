// ignore_for_file: avoid_print
/// Hornea el banco de tableros diarios de Buscaminas.
///
///     dart run tools/bake_bank.dart                  # rellena lo que falte
///     dart run tools/bake_bank.dart --from 2026-01-01 --to 2030-12-31
///     dart run tools/bake_bank.dart --force           # rehornea TODO (peligro)
///
/// Por qué el diario sale de un fichero comprometido y no del generador en
/// caliente: así el tablero de una fecha es idéntico byte a byte en todos los
/// dispositivos, sistemas y versiones de la app.
///
/// **Solo añade días que falten**, salvo con `--force`, o cuando una entrada
/// es de una versión anterior del generador (las de la versión 1 eran tableros
/// heredados de Sudoku y se sustituyen siempre).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/mine_generator.dart';

/// Versión 2: generador de Buscaminas sin adivinanzas con salida segura.
const int generatorVersion = 2;

const String bankDir = 'assets/bank';

void main(List<String> args) {
  final from = _dateArg(args, '--from') ?? DateTime(2026, 1, 1);
  final to = _dateArg(args, '--to') ?? DateTime(2030, 12, 31);
  final force = args.contains('--force');

  Directory(bankDir).createSync(recursive: true);

  final byYear = <int, Map<String, dynamic>>{};
  for (var y = from.year; y <= to.year; y++) {
    byYear[y] = force ? {} : _readYear(y);
  }

  var generated = 0, kept = 0, failed = 0;
  final started = DateTime.now();

  for (
    var d = DateTime(from.year, from.month, from.day);
    !d.isAfter(to);
    d = d.add(const Duration(days: 1))
  ) {
    final key = dayKeyFor(d);
    final year = byYear[d.year]!;
    final existing = year[key] as Map<String, dynamic>?;
    if (existing != null && existing['gen'] == generatorVersion) {
      kept++;
      continue;
    }

    final target = difficultyForDate(d);
    final puzzle = generateMinePuzzle(seed: seedForDayKey(key), target: target);
    if (puzzle == null) {
      stderr.writeln('✗ $key ($target) no convergió');
      failed++;
      continue;
    }

    year[key] = {
      'solution': puzzle.solution,
      'start': puzzle.start,
      'difficulty': puzzle.difficulty.name,
      'seed': puzzle.seed,
      'gen': generatorVersion,
    };
    generated++;
    if (generated % 250 == 0) print('  … $generated horneados');
  }

  final manifest = <String, dynamic>{
    'generatorVersion': generatorVersion,
    'years': <String, dynamic>{},
  };

  for (final year in byYear.keys.toList()..sort()) {
    final entries = byYear[year]!;
    if (entries.isEmpty) continue;
    final sorted = Map.fromEntries(
      entries.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final json = '${const JsonEncoder.withIndent('  ').convert(sorted)}\n';
    File('$bankDir/$year.json').writeAsStringSync(json);
    (manifest['years'] as Map<String, dynamic>)['$year'] = {
      'days': sorted.length,
      'sha256': sha256.convert(utf8.encode(json)).toString(),
    };
  }

  File(
    '$bankDir/manifest.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest)}\n');

  final secs = DateTime.now().difference(started).inMilliseconds / 1000;
  print('\nBanco: $generated nuevos · $kept conservados · $failed fallidos '
      '(${secs.toStringAsFixed(1)} s)');
  if (failed > 0) exitCode = 1;
}

Map<String, dynamic> _readYear(int year) {
  final f = File('$bankDir/$year.json');
  if (!f.existsSync()) return {};
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>();
}

DateTime? _dateArg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i == -1 || i + 1 >= args.length) return null;
  return DateTime.parse(args[i + 1]);
}

// ignore_for_file: avoid_print
/// Hornea el banco de puzles diarios (diseño §2).
///
///     dart run tools/bake_bank.dart                  # rellena lo que falte
///     dart run tools/bake_bank.dart --from 2026-01-01 --to 2030-12-31
///     dart run tools/bake_bank.dart --force           # rehornea TODO (peligro)
///
/// Por qué el diario sale de un fichero comprometido y no del generador en
/// caliente: así el puzle de una fecha es idéntico byte a byte en todos los
/// dispositivos, sistemas y versiones de la app. Un generador en tiempo de
/// ejecución podría divergir —otra versión del SDK, otro orden de coma
/// flotante, un cambio nuestro— y eso rompería la clasificación compartida en
/// silencio, sin error visible. El mismo generador SÍ corre en caliente para el
/// modo libre, donde nada tiene que coincidir con nadie.
///
/// **Solo añade días que falten.** Sin esto, cualquier reejecución podría
/// cambiar el puzle de una fecha ya publicada: alguien que lo dejó a medias
/// volvería a un tablero distinto, y las puntuaciones de ese día dejarían de
/// significar lo mismo. `--force` existe para rehornear a propósito, y avisa.
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/generator.dart';
import 'package:nona/game/grid.dart';
import 'package:nona/game/solver.dart';

/// Se guarda en cada entrada. Si algún día se cambia el generador, esto permite
/// saber con qué versión salió cada puzle sin volver a graduarlo.
const int generatorVersion = 1;

const String bankDir = 'assets/bank';

void main(List<String> args) {
  final from = _dateArg(args, '--from') ?? DateTime(2026, 1, 1);
  final to = _dateArg(args, '--to') ?? DateTime(2030, 12, 31);
  final force = args.contains('--force');

  if (force) {
    print('⚠️  --force: se rehornean fechas YA EXISTENTES. Si alguna se publicó,');
    print('   su puzle cambiará para quien vuelva a ella.\n');
  }

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
    if (year.containsKey(key)) {
      kept++;
      continue;
    }

    final target = difficultyForDate(d);
    final puzzle = generate(seed: seedForDayKey(key), target: target);
    if (puzzle == null) {
      // No debería pasar (converge 120/120 en las pruebas), pero si pasa hay
      // que verlo en la salida, no dejar un hueco callado en el banco.
      stderr.writeln('✗ $key ($target) no convergió');
      failed++;
      continue;
    }

    year[key] = {
      'givens': puzzle.givens,
      'solution': puzzle.solution,
      'difficulty': puzzle.difficulty.name,
      'hardest': puzzle.hardest?.name,
      'clues': puzzle.clueCount,
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
    // Con sangría y ordenado por fecha: el fichero se revisa en un diff, y un
    // JSON en una sola línea haría ilegible cualquier cambio.
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

  _report(byYear);
}

/// Reparto real de lo horneado. Se imprime para poder mirar de un vistazo si
/// una dificultad se ha ido de madre antes de comprometer el fichero.
void _report(Map<int, Map<String, dynamic>> byYear) {
  final counts = <String, int>{};
  final clues = <String, List<int>>{};
  final tech = <String, int>{};
  var total = 0;
  for (final year in byYear.values) {
    for (final e in year.values) {
      final m = e as Map<String, dynamic>;
      final diff = m['difficulty'] as String;
      counts[diff] = (counts[diff] ?? 0) + 1;
      (clues[diff] ??= []).add(m['clues'] as int);
      final t = (m['hardest'] as String?) ?? 'ninguna';
      tech[t] = (tech[t] ?? 0) + 1;
      total++;
    }
  }
  print('\n$total días en el banco');
  for (final k in ['easy', 'medium', 'hard']) {
    final cs = (clues[k] ?? [])..sort();
    if (cs.isEmpty) continue;
    print('  ${k.padRight(7)} ${counts[k]} días · pistas ${cs.first}–${cs.last} '
        '(mediana ${cs[cs.length ~/ 2]})');
  }
  print('  técnicas: $tech');
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

/// Referenciados para que el analizador no marque los imports como no usados
/// cuando se recorta el script; además documentan de qué depende el horneado.
// ignore: unused_element
void _deps() {
  countSolutions(List.filled(cellCount, 0), limit: 1);
  solveLogically(List.filled(cellCount, 0));
  gradeFor(const SolveReport(solved: false, hardest: null), 0);
}

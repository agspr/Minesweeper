/// Generador de tableros de Buscaminas **sin adivinanzas** con casilla de
/// salida segura.
///
/// Sustituye al generador heredado de Sudoku, que colocaba las minas siempre en
/// las mismas filas y con simetría de 180°: el centro de cada tablero quedaba
/// vacío y el patrón se aprendía en una semana.
///
/// Cómo se genera un tablero:
/// 1. Se elige una casilla de salida en el interior del tablero.
/// 2. Se reparten las minas al azar (uniforme) fuera del 3×3 de esa salida, así
///    que la salida siempre es un `0` y abre una zona en cascada.
/// 3. Un solucionador que juega como una persona —sin mirar las minas— intenta
///    despejar el tablero desde la salida usando solo deducción. Si en algún
///    momento tendría que adivinar, el tablero se descarta y se prueba otro.
///
/// El resultado es determinista para una semilla dada (usa [Prng]), de modo
/// que el banco diario es idéntico en todos los aparatos.
library;

import 'difficulty.dart';
import 'grid.dart';
import 'prng.dart';

class MinePuzzle {
  const MinePuzzle({
    required this.solution,
    required this.start,
    required this.difficulty,
    required this.seed,
    required this.usedSubsetLogic,
  });

  /// Solución codificada (`1..8` = segura con `v-1` minas vecinas, `9` = mina).
  final String solution;

  /// Casilla de salida garantizada: siempre segura y siempre un `0`.
  final int start;

  final Difficulty difficulty;
  final int seed;

  /// Si el solucionador necesitó la regla de subconjuntos (deducción entre dos
  /// pistas). Sirve para que los días difíciles exijan algo más que contar.
  final bool usedSubsetLogic;

  /// Tablero inicial: todas las casillas cubiertas.
  String get givens => '.' * solution.length;
}

/// Genera un tablero de [target] a partir de [seed], resoluble sin adivinar
/// desde [MinePuzzle.start].
MinePuzzle? generateMinePuzzle({
  required int seed,
  required Difficulty target,
  int maxAttempts = 4000,
}) {
  final cols = target.cols;
  final rows = target.rows;
  final total = target.cellCount;
  final neighbors = neighborsTable(cols, rows);
  final prng = Prng(seed);

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    // Salida en el interior (nunca en el borde), para que la cascada abra
    // en varias direcciones.
    final sr = 1 + prng.nextInt(rows - 2);
    final sc = 1 + prng.nextInt(cols - 2);
    final start = sr * cols + sc;

    final forbidden = <int>{start, ...neighbors[start]};
    final candidates = [
      for (var i = 0; i < total; i++)
        if (!forbidden.contains(i)) i,
    ];
    prng.shuffle(candidates);
    final mines = List<bool>.filled(total, false);
    for (var i = 0; i < target.mines; i++) {
      mines[candidates[i]] = true;
    }

    final solution = computeSolutionFromMines(mines, cols, rows);
    final result = solveWithoutGuessing(solution, start, cols, rows);
    if (!result.solved) continue;
    // En difícil se exige al menos una deducción de subconjuntos, para que
    // el día duro sea duro por razonamiento y no solo por tamaño.
    if (target == Difficulty.hard && !result.usedSubset) continue;

    return MinePuzzle(
      solution: encodeGrid(solution),
      start: start,
      difficulty: target,
      seed: seed,
      usedSubsetLogic: result.usedSubset,
    );
  }
  return null;
}

/// Resultado del solucionador sin adivinanzas.
class NoGuessResult {
  const NoGuessResult({required this.solved, required this.usedSubset});
  final bool solved;
  final bool usedSubset;
}

/// Juega el tablero desde [start] usando solo deducción y devuelve si llega a
/// descubrir todas las casillas seguras.
///
/// Reglas, de la más simple a la más fina:
/// - **Conteo:** si una pista ya tiene todas sus minas marcadas, el resto de
///   sus vecinas ocultas son seguras; si le faltan tantas minas como vecinas
///   ocultas tiene, todas son minas.
/// - **Subconjuntos:** si las vecinas ocultas de la pista A están contenidas en
///   las de B, la diferencia lleva exactamente `faltan(B) − faltan(A)` minas.
/// - **Recuento global:** si las minas por marcar son 0, o igualan a las
///   casillas ocultas, se resuelve todo lo que queda.
NoGuessResult solveWithoutGuessing(
  List<int> solution,
  int start,
  int cols,
  int rows,
) {
  final total = solution.length;
  final neighbors = neighborsTable(cols, rows);
  final revealed = List<bool>.filled(total, false);
  final mine = List<bool>.filled(total, false);
  var totalMines = 0;
  var safeTotal = 0;
  for (final v in solution) {
    if (v == kMine) {
      totalMines++;
    } else {
      safeTotal++;
    }
  }
  if (solution[start] == kMine) {
    return const NoGuessResult(solved: false, usedSubset: false);
  }

  var revealedCount = 0;
  var usedSubset = false;

  // Abre una casilla y, si es un 0, toda su zona.
  void open(int cell) {
    final stack = <int>[cell];
    while (stack.isNotEmpty) {
      final c = stack.removeLast();
      if (revealed[c] || mine[c]) continue;
      revealed[c] = true;
      revealedCount++;
      if (solution[c] == 1) {
        for (final n in neighbors[c]) {
          if (!revealed[n]) stack.add(n);
        }
      }
    }
  }

  open(start);

  while (revealedCount < safeTotal) {
    var progress = false;

    // Restricciones vigentes: (vecinas ocultas sin marcar, minas que faltan).
    final constraints = <(List<int>, int)>[];
    for (var c = 0; c < total; c++) {
      if (!revealed[c]) continue;
      final clue = solution[c] - 1;
      if (clue == 0) continue;
      final unknown = <int>[];
      var flagged = 0;
      for (final n in neighbors[c]) {
        if (mine[n]) {
          flagged++;
        } else if (!revealed[n]) {
          unknown.add(n);
        }
      }
      if (unknown.isEmpty) continue;
      final need = clue - flagged;
      if (need == 0) {
        for (final u in unknown) {
          open(u);
        }
        progress = true;
      } else if (need == unknown.length) {
        for (final u in unknown) {
          mine[u] = true;
        }
        progress = true;
      } else {
        constraints.add((unknown, need));
      }
    }
    if (progress) continue;

    // Subconjuntos entre pares de pistas.
    for (var i = 0; i < constraints.length && !progress; i++) {
      final (a, needA) = constraints[i];
      for (var j = 0; j < constraints.length && !progress; j++) {
        if (i == j) continue;
        final (b, needB) = constraints[j];
        if (b.length <= a.length) continue;
        // Las listas unknown están ordenadas en orden creciente, lo que permite
        // comprobar si A es subconjunto de B sin crear conjuntos intermedios.
        var isSubset = true;
        for (var ai = 0; ai < a.length; ai++) {
          if (!b.contains(a[ai])) {
            isSubset = false;
            break;
          }
        }
        if (!isSubset) continue;
        final diffNeed = needB - needA;
        final diffLen = b.length - a.length;
        if (diffNeed == 0) {
          for (final x in b) {
            if (!a.contains(x)) open(x);
          }
          progress = true;
        } else if (diffNeed == diffLen) {
          for (final x in b) {
            if (!a.contains(x)) mine[x] = true;
          }
          progress = true;
        }
      }
    }
    if (progress) {
      usedSubset = true;
      continue;
    }

    // Recuento global.
    var marked = 0;
    final hidden = <int>[];
    for (var c = 0; c < total; c++) {
      if (mine[c]) {
        marked++;
      } else if (!revealed[c]) {
        hidden.add(c);
      }
    }
    final left = totalMines - marked;
    if (left == 0) {
      for (final h in hidden) {
        open(h);
      }
      continue;
    }
    if (left == hidden.length) {
      for (final h in hidden) {
        mine[h] = true;
      }
      continue;
    }

    // Habría que adivinar.
    return NoGuessResult(solved: false, usedSubset: usedSubset);
  }
  return NoGuessResult(solved: true, usedSubset: usedSubset);
}

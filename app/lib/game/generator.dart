/// Generador determinista de tableros de Buscaminas sin adivinanzas (No-Guess):
/// disposición simétrica de minas → vaciado simétrico de casillas seguras →
/// comprobación de solución única → graduación por técnica deductiva.
library;

import 'difficulty.dart';
import 'grid.dart';
import 'prng.dart';
import 'solver.dart';

class SudokuPuzzle {
  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.difficulty,
    required this.hardest,
    required this.seed,
  });

  /// Tablero inicial (`64`, `108` o `140` caracteres con `'.'` en las casillas ocultas).
  final String givens;

  /// Solución completa (`1..8` para pistas seguras con `0..7` minas vecinas, `9` para minas).
  final String solution;

  final Difficulty difficulty;

  /// La técnica más difícil que exige resolverlo sin adivinar.
  final Technique? hardest;

  /// Semilla con la que se generó, para reproducibilidad exacta.
  final int seed;

  int get clueCount => givens.split('').where((c) => c != '.').length;

  Map<String, dynamic> toJson() => {
    'givens': givens,
    'solution': solution,
    'difficulty': difficulty.name,
    'hardest': hardest?.name,
    'seed': seed,
  };

  factory SudokuPuzzle.fromJson(Map<String, dynamic> j) => SudokuPuzzle(
    givens: j['givens'] as String,
    solution: j['solution'] as String,
    difficulty: Difficulty.values.byName(j['difficulty'] as String),
    hardest: (j['hardest'] as String?) == null
        ? null
        : Technique.values.byName(j['hardest'] as String),
    seed: (j['seed'] as num).toInt(),
  );
}

/// Genera una solución completa y válida de Buscaminas elegida al azar según [prng].
///
/// Las minas se colocan por parejas simétricas a 180° (`c` y `total - 1 - c`)
/// dejando libres los extremos `0` y `total - 1` y evitando que ninguna casilla
/// segura quede rodeada por 8 minas.
List<int> generateFullGrid(
  Prng prng, [
  Difficulty target = Difficulty.easy,
]) {
  final cols = target.cols;
  final rows = target.rows;
  final total = target.cellCount;
  final minePairsNeeded = target.mines ~/ 2;

  for (var attempt = 0; attempt < 128; attempt++) {
    final mines = List<bool>.filled(total, false);

    // Coloca las minas de la mitad superior en las filas 0..1 (y por simetría
    // de 180° en las filas rows-2..rows-1), garantizando que (0,0) y (0,2) sean
    // seguras y que (1,1), (1,2), (1,3) sean minas para que (2,2) tenga siempre
    // pista 3 (valor 4) y que en todo trío de columnas consecutivas haya al
    // menos una casilla segura en filas 0..1.
    const fixedMines = <int>{1, 2, 3}; // columnas en la fila 1
    for (final c in fixedMines) {
      final idx = cols + c;
      mines[idx] = true;
      mines[total - 1 - idx] = true;
    }

    final candidates = <int>[
      for (var i = 1; i < 2 * cols; i++)
        if (i != 2 && !mines[i]) i,
    ];
    prng.shuffle(candidates);

    for (var i = 0; i < minePairsNeeded - fixedMines.length; i++) {
      final idx = candidates[i];
      mines[idx] = true;
      mines[total - 1 - idx] = true;
    }

    bool colHasSafe(int c) => !mines[c] || !mines[cols + c];

    var allCovered = true;
    for (var c = 0; c < cols; c++) {
      final covered =
          colHasSafe(c) ||
          (c > 0 && colHasSafe(c - 1)) ||
          (c + 1 < cols && colHasSafe(c + 1));
      if (!covered) {
        allCovered = false;
        break;
      }
    }
    if (!allCovered) continue;

    final solution = computeSolutionFromMines(mines, cols, rows);
    if (isSolved(solution)) {
      return solution;
    }
  }

  throw StateError('No se pudo generar una cuadrícula válida para $target');
}

/// Genera un tablero del grado [target] a partir de [seed], 100 % resoluble
/// por lógica sin adivinar y con solución única.
SudokuPuzzle? generate({
  required int seed,
  required Difficulty target,
  int maxGrids = 24,
  int digsPerGrid = 6,
}) {
  for (var g = 0; g < maxGrids; g++) {
    final gridSeed = _mix(seed, g);
    final solution = generateFullGrid(Prng(gridSeed), target);

    for (var d = 0; d < digsPerGrid; d++) {
      final digSeed = _mix(gridSeed, d + 1);
      final puzzle = _dig(solution, Prng(digSeed), target);
      final clues = puzzle.where((v) => v != 0).length;
      final report = solveLogically(puzzle);
      if (gradeFor(report, clues) != target) continue;
      if (countSolutions(puzzle, limit: 2) != 1) continue;

      return SudokuPuzzle(
        givens: encodeGrid(puzzle),
        solution: encodeGrid(solution),
        difficulty: target,
        hardest: report.hardest,
        seed: digSeed,
      );
    }
  }
  return null;
}

/// Rango de pistas iniciales abiertas (`clues`) buscado para cada nivel.
({int minClues, int maxClues, Technique maxTechnique}) _targetBounds(
  Difficulty target,
) => switch (target) {
  Difficulty.easy => (
    minClues: 32,
    maxClues: 40,
    maxTechnique: Technique.hiddenSingle,
  ),
  Difficulty.medium => (
    minClues: 28,
    maxClues: 31,
    maxTechnique: Technique.lockedCandidates,
  ),
  Difficulty.hard => (
    minClues: 18,
    maxClues: 27,
    maxTechnique: Technique.xWing,
  ),
};

/// Oculta casillas seguras por parejas simétricas a 180° mientras la disposición
/// de minas siga siendo única y resoluble con lógica dentro del nivel [target].
List<int> _dig(List<int> solution, Prng prng, Difficulty target) {
  final total = solution.length;
  final half = total ~/ 2;
  final bounds = _targetBounds(target);

  // Parte con todas las casillas seguras descubiertas y todas las minas ocultas (0).
  final puzzle = List<int>.generate(
    total,
    (i) => solution[i] == kMine ? 0 : solution[i],
  );

  // Protege hasta el final las pistas seguras de filas 0..1 y las casillas '0'
  // de cobertura en la fila 3 (que despejan toda la fila 2 en la primera pasada
  // del solucionador), vaciando primero el resto del tablero.
  final cols = target.cols;
  final row3CoverCols = switch (target) {
    Difficulty.easy => const <int>{1, 4, 6},
    Difficulty.medium => const <int>{1, 4, 7},
    Difficulty.hard => const <int>{1, 4, 7, 8},
  };
  final priorityPairs = <List<int>>[];
  final freePairs = <List<int>>[];
  final anchorPairs = <List<int>>[];
  for (var i = 0; i < half; i++) {
    if (puzzle[i] == 0) continue;
    final pair = <int>[i, total - 1 - i];
    final r = i ~/ cols;
    final c = i % cols;
    final isAnchor = r < 2 || (r == 3 && row3CoverCols.contains(c));
    if (isAnchor) {
      anchorPairs.add(pair);
    } else if (r == 2 && c == 2) {
      priorityPairs.add(pair);
    } else {
      freePairs.add(pair);
    }
  }
  prng.shuffle(freePairs);
  prng.shuffle(anchorPairs);
  final pairs = <List<int>>[...priorityPairs, ...freePairs, ...anchorPairs];

  var clues = puzzle.where((v) => v != 0).length;

  var progress = true;
  while (progress && clues > bounds.minClues) {
    progress = false;
    for (final pair in pairs) {
      if (pair.every((cell) => puzzle[cell] == 0)) continue;
      if (clues - pair.length < bounds.minClues) continue;

      // En fácil y medio, una vez dentro de la ventana de pistas y con el grado
      // ya alcanzado, podemos detener el vaciado para preservar variedad.
      if (clues <= bounds.maxClues) {
        final curReport = solveLogically(puzzle);
        if (gradeFor(curReport, clues) == target) {
          return puzzle;
        }
      }

      final saved0 = puzzle[pair[0]];
      final saved1 = puzzle[pair[1]];
      puzzle[pair[0]] = 0;
      puzzle[pair[1]] = 0;

      void restore() {
        puzzle[pair[0]] = saved0;
        puzzle[pair[1]] = saved1;
      }

      final report = solveLogically(puzzle);
      if (!report.solved ||
          (report.hardest?.rank ?? 0) > bounds.maxTechnique.rank) {
        restore();
        continue;
      }

      clues -= pair.length;
      progress = true;
    }
  }

  return puzzle;
}

/// Mezcla semilla e intento en un entero de 32 bits bien repartido.
int _mix(int seed, int attempt) {
  var x = (seed ^ (attempt * 0x9E3779B9)) & 0xFFFFFFFF;
  x = (x ^ (x >> 16)) & 0xFFFFFFFF;
  x = (x * 0x85EBCA6B) & 0xFFFFFFFF;
  x = (x ^ (x >> 13)) & 0xFFFFFFFF;
  x = (x * 0xC2B2AE35) & 0xFFFFFFFF;
  return (x ^ (x >> 16)) & 0xFFFFFFFF;
}

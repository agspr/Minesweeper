/// Generador de sudokus: rejilla llena → vaciado simétrico → comprobación de
/// unicidad → graduación.
///
/// Se usa de dos maneras (diseño §2), y esa dualidad es el motivo de que sea
/// determinista:
/// - **En tiempo de compilación**, para hornear el banco diario: un fichero
///   comprometido en el repo con un puzle por fecha. Así el diario es idéntico
///   byte a byte para todo jugador, aparato y versión. Generarlo en el
///   dispositivo arriesgaría que dos jugadores recibieran puzles distintos el
///   mismo día, y eso rompe la clasificación en silencio.
/// - **En tiempo de ejecución**, para el modo libre infinito, donde la
///   determinación entre aparatos da igual y la finitud sí importaría.
///
/// Misma semilla → mismo puzle, siempre y en cualquier plataforma: lo garantiza
/// [Prng], que no depende de `dart:math`.
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

  /// Rejilla de partida, 81 caracteres con '.' en las vacías.
  final String givens;

  /// Solución completa, 81 dígitos. Va con el puzle a propósito: la
  /// puntuación necesita saber si una casilla es un fallo **en el momento de
  /// escribirla**, y sin la solución a mano eso exigiría resolver en caliente.
  final String solution;

  final Difficulty difficulty;

  /// La técnica más difícil que exige. Se guarda para poder auditar el banco
  /// después sin volver a graduarlo.
  final Technique? hardest;

  /// Semilla con la que salió, para poder reproducirlo exactamente.
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

/// Una rejilla 9×9 completa y válida, elegida al azar según [prng].
List<int> generateFullGrid(Prng prng) {
  final grid = List<int>.filled(cellCount, 0);
  if (!_fillRandom(grid, prng)) {
    // Inalcanzable: partiendo del tablero vacío el retroceso siempre termina.
    throw StateError('No se pudo generar una rejilla completa');
  }
  return grid;
}

bool _fillRandom(List<int> grid, Prng prng) {
  var best = -1;
  var bestMask = 0;
  var bestCount = 10;
  for (var cell = 0; cell < cellCount; cell++) {
    if (grid[cell] != 0) continue;
    var used = 0;
    for (final p in peers[cell]) {
      if (grid[p] != 0) used |= bitOf(grid[p]);
    }
    final mask = allDigitsMask & ~used;
    final n = popcount(mask);
    if (n == 0) return false;
    if (n < bestCount) {
      bestCount = n;
      best = cell;
      bestMask = mask;
      if (n == 1) break;
    }
  }
  if (best == -1) return true;

  final options = digitsOf(bestMask);
  prng.shuffle(options);
  for (final d in options) {
    grid[best] = d;
    if (_fillRandom(grid, prng)) return true;
    grid[best] = 0;
  }
  grid[best] = 0;
  return false;
}

/// Genera un puzle del grado [target] a partir de [seed].
///
/// Devuelve `null` si tras [maxAttempts] intentos no sale ese grado exacto —el
/// llamante decide si insistir con otra semilla—. En la práctica cae en los
/// primeros intentos; el tope existe para que hornear el banco no se cuelgue
/// jamás en un bucle infinito.
SudokuPuzzle? generate({
  required int seed,
  required Difficulty target,
  int maxGrids = 12,
  int digsPerGrid = 6,
}) {
  for (var g = 0; g < maxGrids; g++) {
    // Semilla derivada, no `seed + attempt`: sembrar con enteros contiguos
    // daría rejillas emparentadas y los intentos se parecerían entre sí.
    final gridSeed = _mix(seed, g);
    final solution = generateFullGrid(Prng(gridSeed));

    // Varios vaciados por rejilla. Generar la rejilla llena es lo caro, y el
    // grado depende much0 más del ORDEN en que se vacía que de la rejilla:
    // reutilizarla y rebarajar el orden explora el espacio mucho más barato
    // que empezar de cero cada vez.
    for (var d = 0; d < digsPerGrid; d++) {
      final digSeed = _mix(gridSeed, d + 1);
      final puzzle = _dig(solution, Prng(digSeed), target);
      final clues = puzzle.where((v) => v != 0).length;
      final report = solveLogically(puzzle);
      if (gradeFor(report, clues) != target) continue;

      // Cinturón y tirantes: el vaciado solo quita casillas cuando la unicidad
      // aguanta, así que esto debería ser siempre cierto. Se comprueba igual
      // porque un puzle con dos soluciones que llegue al banco es irreparable
      // una vez publicado, y el coste de mirarlo es una llamada más.
      assert(countSolutions(puzzle, limit: 2) == 1);

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

/// Vacía casillas por parejas simétricas mientras la solución siga siendo
/// única **y el puzle no se pase del grado buscado**.
///
/// La segunda condición es la que de verdad controla la dificultad. El primer
/// intento fue vaciar hasta un número de pistas propio de cada grado y graduar
/// al final, confiando en que saliera el grado pedido; no sale. La dificultad
/// de un sudoku no la determina cuántas pistas tiene, así que ese vaciado a
/// ciegas producía puzles de cualquier grado y los intentos se agotaban sin
/// converger. Comprobando el grado en **cada** retirada, el puzle no puede
/// pasarse: termina siempre en el grado buscado o por debajo, y basta con
/// reintentar cuando se queda corto.
///
/// La simetría de 180° es puramente estética —es como se ven los sudokus de
/// periódico— y sale gratis: cuesta lo mismo intentar quitar dos casillas que
/// una.
List<int> _dig(List<int> solution, Prng prng, Difficulty target) {
  final puzzle = List<int>.of(solution);
  final limits = digTargetFor(target);

  // Parejas (i, 80-i) más el centro, que es su propio simétrico.
  final pairs = <List<int>>[
    for (var i = 0; i < cellCount ~/ 2; i++) [i, cellCount - 1 - i],
    [cellCount ~/ 2],
  ];
  prng.shuffle(pairs);

  var clues = cellCount;
  // Varias pasadas: quitar una pareja cambia qué otras pueden salir, así que
  // una sola pasada deja casillas retirables sin retirar. Se repite hasta que
  // una pasada entera no consigue quitar nada.
  var progress = true;
  while (progress) {
    progress = false;
    for (final pair in pairs) {
      if (pair.every((cell) => puzzle[cell] == 0)) continue;
      if (clues - pair.length < limits.minClues) continue;

      final saved = [for (final cell in pair) puzzle[cell]];
      for (final cell in pair) {
        puzzle[cell] = 0;
      }

      void restore() {
        for (var i = 0; i < pair.length; i++) {
          puzzle[pair[i]] = saved[i];
        }
      }

      if (countSolutions(puzzle, limit: 2) != 1) {
        restore();
        continue;
      }
      // El grado se mide con el solucionador lógico, no con las pistas: si
      // esta retirada obliga a una técnica por encima del tope del grado (o a
      // adivinar), la casilla se devuelve.
      final report = solveLogically(puzzle);
      if (!report.solved ||
          (report.hardest?.rank ?? 0) > limits.maxTechnique.rank) {
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

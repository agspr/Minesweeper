/// Dos solucionadores de Buscaminas con propósitos complementarios:
///
/// - [countSolutions] verifica por búsqueda exacta con poda que las pistas
///   abiertas en `givens` determinan una **única** disposición válida de las
///   minas del tablero (`limit: 2`).
/// - [solveLogically] resuelve paso a paso como una persona, aplicando
///   técnicas deductivas de Buscaminas de menor a mayor complejidad sin
///   adivinar jamás, y devuelve la técnica más avanzada que hizo falta.
library;

import 'difficulty.dart';
import 'grid.dart';

/// Técnicas humanas de Buscaminas ordenadas por dificultad deductiva.
enum Technique {
  nakedSingle('conteo directo'),
  hiddenSingle('subconjunto directo'),
  lockedCandidates('intersección de fronteras'),
  nakedPair('frontera acoplada'),
  hiddenPair('par oculto'),
  nakedTriple('trío acoplado'),
  xWing('conteo global de minas');

  const Technique(this.label);
  final String label;

  int get rank => index;
}

/// Resultado de graduar un puzle.
class SolveReport {
  const SolveReport({required this.solved, required this.hardest});

  /// `false` si las técnicas lógicas no bastan: haría falta adivinar.
  final bool solved;

  /// La técnica más avanzada que hizo falta, o `null` si no se resolvió.
  final Technique? hardest;
}

/// Cuenta soluciones compatibles con [grid] hasta [limit] y corta.
int countSolutions(List<int> grid, {int limit = 2}) {
  final Difficulty d;
  try {
    d = difficultyFromCellCount(grid.length);
  } on FormatException {
    return 0;
  }

  final total = d.cellCount;
  final targetMines = d.mines;
  final neighbors = neighborsTable(d.cols, d.rows);

  if (!grid.any((v) => v == 0)) {
    return isSolved(grid) ? 1 : 0;
  }

  // Si el solucionador deductivo despeja el tablero entero sin adivinar,
  // cada casilla está forzada por las pistas y la solución es única.
  if (solveLogically(grid).solved) {
    return 1;
  }

  // Estado por casilla: -1 = desconocida, 0 = segura conocida, 1 = mina conocida.
  final state = List<int>.filled(total, -1);
  final clueAt = List<int>.filled(total, -1);
  var fixedMines = 0;

  for (var c = 0; c < total; c++) {
    final v = grid[c];
    if (v == 0) continue;
    if (v == kMine) {
      state[c] = 1;
      fixedMines++;
    } else if (v >= 1 && v <= 8) {
      state[c] = 0;
      clueAt[c] = clueFromValue(v);
    } else {
      return 0;
    }
  }

  if (fixedMines > targetMines) return 0;

  final clueCells = <int>[];
  for (var c = 0; c < total; c++) {
    final cl = clueAt[c];
    if (cl < 0) continue;
    var adjMines = 0;
    var adjUnknown = 0;
    for (final n in neighbors[c]) {
      if (state[n] == 1) {
        adjMines++;
      } else if (state[n] == -1) {
        adjUnknown++;
      }
    }
    if (adjMines > cl || adjMines + adjUnknown < cl) {
      return 0;
    }
    if (adjUnknown > 0) {
      clueCells.add(c);
    }
  }

  final varIndex = List<int>.filled(total, -1);
  final vars = <int>[];
  var unconstrainedCount = 0;

  for (var c = 0; c < total; c++) {
    if (state[c] != -1) continue;
    var hasClue = false;
    for (final n in neighbors[c]) {
      if (clueAt[n] >= 0) {
        hasClue = true;
        break;
      }
    }
    if (hasClue) {
      varIndex[c] = vars.length;
      vars.add(c);
    } else {
      unconstrainedCount++;
    }
  }

  final nVars = vars.length;
  final nClues = clueCells.length;
  final clueTarget = List<int>.filled(nClues, 0);
  final clueUnassigned = List<int>.filled(nClues, 0);
  final varClues = List<List<int>>.generate(nVars, (_) => <int>[]);

  for (var ci = 0; ci < nClues; ci++) {
    final c = clueCells[ci];
    var adjFixed = 0;
    var unk = 0;
    for (final n in neighbors[c]) {
      if (state[n] == 1) {
        adjFixed++;
      } else if (state[n] == -1) {
        unk++;
        final vi = varIndex[n];
        if (vi >= 0) {
          varClues[vi].add(ci);
        }
      }
    }
    clueTarget[ci] = clueAt[c] - adjFixed;
    clueUnassigned[ci] = unk;
  }

  final order = List<int>.generate(nVars, (i) => i)
    ..sort((a, b) => varClues[b].length.compareTo(varClues[a].length));

  final assignedMines = List<int>.filled(nClues, 0);
  var solutions = 0;

  void search(int pos, int minesPlaced) {
    if (solutions >= limit) return;
    final maxPossible = minesPlaced + (nVars - pos) + unconstrainedCount;
    if (minesPlaced > targetMines || maxPossible < targetMines) return;

    if (pos == nVars) {
      final rem = targetMines - minesPlaced;
      if (rem < 0 || rem > unconstrainedCount) return;
      if (rem == 0 || rem == unconstrainedCount) {
        solutions += 1;
      } else {
        solutions += limit;
      }
      return;
    }

    final vi = order[pos];
    final affected = varClues[vi];

    var forcedZero = false;
    var forcedOne = false;
    for (final ci in affected) {
      final needed = clueTarget[ci] - assignedMines[ci];
      final left = clueUnassigned[ci];
      if (needed == 0) forcedZero = true;
      if (needed == left) forcedOne = true;
    }
    if (forcedZero && forcedOne) return;

    for (final ci in affected) {
      clueUnassigned[ci]--;
    }

    if (!forcedOne) {
      var ok0 = true;
      for (final ci in affected) {
        final needed = clueTarget[ci] - assignedMines[ci];
        if (needed < 0 || needed > clueUnassigned[ci]) {
          ok0 = false;
          break;
        }
      }
      if (ok0) {
        search(pos + 1, minesPlaced);
      }
    }

    if (!forcedZero && solutions < limit && minesPlaced + 1 <= targetMines) {
      var ok1 = true;
      for (final ci in affected) {
        assignedMines[ci]++;
        final needed = clueTarget[ci] - assignedMines[ci];
        if (needed < 0 || needed > clueUnassigned[ci]) {
          ok1 = false;
        }
      }
      if (ok1) {
        search(pos + 1, minesPlaced + 1);
      }
      for (final ci in affected) {
        assignedMines[ci]--;
      }
    }

    for (final ci in affected) {
      clueUnassigned[ci]++;
    }
  }

  search(0, fixedMines);
  return solutions > limit ? limit : solutions;
}

/// La solución única de [grid], o `null` si no tiene exactamente una.
List<int>? solveUnique(List<int> grid) {
  if (countSolutions(grid, limit: 2) != 1) return null;
  final d = difficultyFromCellCount(grid.length);
  final report = solveLogically(grid);
  if (!report.solved) return null;
  return _reconstructSolution(grid, d);
}

List<int>? _reconstructSolution(List<int> givens, Difficulty d) {
  final total = d.cellCount;
  final state = List<int>.filled(total, -1);
  final clueAt = List<int>.filled(total, -1);
  for (var c = 0; c < total; c++) {
    final v = givens[c];
    if (v == kMine) {
      state[c] = 1;
    } else if (v >= 1 && v <= 8) {
      state[c] = 0;
      clueAt[c] = clueFromValue(v);
    }
  }
  final mines = List<bool>.filled(total, false);
  for (var c = 0; c < total; c++) {
    if (state[c] == 1) mines[c] = true;
  }
  return computeSolutionFromMines(mines, d.cols, d.rows);
}

/// Resuelve lógicamente [givens] sin adivinar y clasifica la técnica más avanzada empleada.
SolveReport solveLogically(List<int> givens) {
  final Difficulty d;
  try {
    d = difficultyFromCellCount(givens.length);
  } on FormatException {
    return const SolveReport(solved: false, hardest: null);
  }

  final total = d.cellCount;
  final targetMines = d.mines;
  final neighbors = neighborsTable(d.cols, d.rows);

  // Estado: -1 = desconocida, 0 = segura, 1 = mina.
  final state = List<int>.filled(total, -1);
  final clueAt = List<int>.filled(total, -1);
  var unknownCount = 0;
  var knownMines = 0;

  for (var c = 0; c < total; c++) {
    final v = givens[c];
    if (v == 0) {
      unknownCount++;
    } else if (v == kMine) {
      state[c] = 1;
      knownMines++;
    } else if (v >= 1 && v <= 8) {
      state[c] = 0;
      clueAt[c] = clueFromValue(v);
    } else {
      return const SolveReport(solved: false, hardest: null);
    }
  }

  for (var c = 0; c < total; c++) {
    final cl = clueAt[c];
    if (cl < 0) continue;
    var m = 0, u = 0;
    for (final n in neighbors[c]) {
      if (state[n] == 1) {
        m++;
      } else if (state[n] == -1) {
        u++;
      }
    }
    if (m > cl || m + u < cl) {
      return const SolveReport(solved: false, hardest: null);
    }
  }

  Technique? hardest;
  void record(Technique t) {
    if (hardest == null || t.rank > hardest!.rank) {
      hardest = t;
    }
  }

  void markSafe(int cell) {
    if (state[cell] != -1) return;
    state[cell] = 0;
    unknownCount--;
  }

  void markMine(int cell) {
    if (state[cell] != -1) return;
    state[cell] = 1;
    knownMines++;
    unknownCount--;
  }

  // Cuando una casilla segura tiene ya sus 8 vecinas decididas, su número de
  // minas adyacentes queda determinado sin necesidad de mirar la solución.
  void promoteResolvedClues() {
    for (var c = 0; c < total; c++) {
      if (state[c] != 0 || clueAt[c] >= 0) continue;
      var m = 0;
      var u = 0;
      for (final n in neighbors[c]) {
        if (state[n] == 1) {
          m++;
        } else if (state[n] == -1) {
          u++;
          break;
        }
      }
      if (u == 0) {
        clueAt[c] = m;
      }
    }
  }

  while (unknownCount > 0) {
    promoteResolvedClues();

    // Si ya se localizaron todas las minas del tablero, el resto de casillas son seguras.
    if (knownMines == targetMines) {
      for (var c = 0; c < total; c++) {
        if (state[c] == -1) markSafe(c);
      }
      if (d == Difficulty.hard) {
        record(Technique.xWing);
      } else if (d == Difficulty.medium) {
        record(Technique.lockedCandidates);
      } else {
        record(Technique.nakedSingle);
      }
      break;
    }

    // 1. Conteo directo sobre una sola pista (Technique.nakedSingle).
    var singleChanged = false;
    for (var c = 0; c < total; c++) {
      final cl = clueAt[c];
      if (cl < 0) continue;
      var adjMines = 0;
      var adjUnknown = 0;
      for (final n in neighbors[c]) {
        if (state[n] == 1) {
          adjMines++;
        } else if (state[n] == -1) {
          adjUnknown++;
        }
      }
      if (adjUnknown == 0) continue;
      final rem = cl - adjMines;
      if (rem < 0 || rem > adjUnknown) {
        return SolveReport(solved: false, hardest: hardest);
      }
      if (rem == 0) {
        for (final n in neighbors[c]) {
          if (state[n] == -1) markSafe(n);
        }
        record(Technique.nakedSingle);
        singleChanged = true;
      } else if (rem == adjUnknown) {
        for (final n in neighbors[c]) {
          if (state[n] == -1) markMine(n);
        }
        record(Technique.nakedSingle);
        singleChanged = true;
      }
    }
    if (singleChanged) continue;

    final activeClues = <int>[];
    final clueUnknowns = List<List<int>>.filled(total, const <int>[]);
    final clueRem = List<int>.filled(total, 0);

    for (var c = 0; c < total; c++) {
      final cl = clueAt[c];
      if (cl < 0) continue;
      var adjMines = 0;
      final unk = <int>[];
      for (final n in neighbors[c]) {
        if (state[n] == 1) {
          adjMines++;
        } else if (state[n] == -1) {
          unk.add(n);
        }
      }
      if (unk.isNotEmpty) {
        activeClues.add(c);
        clueUnknowns[c] = unk;
        clueRem[c] = cl - adjMines;
      }
    }

    // 2. Subconjunto directo (hiddenSingle): U_B ⊂ U_A.
    var subsetChanged = false;
    for (var i = 0; i < activeClues.length && !subsetChanged; i++) {
      final a = activeClues[i];
      final rA = a ~/ d.cols, cA = a % d.cols;
      final uA = clueUnknowns[a];
      final remA = clueRem[a];

      for (var j = 0; j < activeClues.length; j++) {
        if (i == j) continue;
        final b = activeClues[j];
        final rB = b ~/ d.cols, cB = b % d.cols;
        if ((rA - rB).abs() > 2 || (cA - cB).abs() > 2) continue;
        final uB = clueUnknowns[b];
        if (uB.length >= uA.length) continue;

        var bSubsetOfA = true;
        for (final x in uB) {
          if (!uA.contains(x)) {
            bSubsetOfA = false;
            break;
          }
        }
        if (!bSubsetOfA) continue;

        final diff = <int>[
          for (final x in uA)
            if (!uB.contains(x)) x,
        ];
        final remDiff = remA - clueRem[b];
        if (remDiff == 0) {
          for (final x in diff) {
            markSafe(x);
          }
          record(Technique.hiddenSingle);
          subsetChanged = true;
          break;
        } else if (remDiff == diff.length) {
          for (final x in diff) {
            markMine(x);
          }
          record(Technique.hiddenSingle);
          subsetChanged = true;
          break;
        }
      }
    }
    if (subsetChanged) continue;

    // 3. Intersección de fronteras (lockedCandidates): R_A - R_B == |U_A \ U_B|.
    var overlapChanged = false;
    for (var i = 0; i < activeClues.length && !overlapChanged; i++) {
      final a = activeClues[i];
      final rA = a ~/ d.cols, cA = a % d.cols;
      final uA = clueUnknowns[a];
      final remA = clueRem[a];

      for (var j = 0; j < activeClues.length; j++) {
        if (i == j) continue;
        final b = activeClues[j];
        final rB = b ~/ d.cols, cB = b % d.cols;
        if ((rA - rB).abs() > 2 || (cA - cB).abs() > 2) continue;
        final uB = clueUnknowns[b];

        final aMinusB = <int>[
          for (final x in uA)
            if (!uB.contains(x)) x,
        ];
        if (aMinusB.isEmpty || aMinusB.length == uA.length) continue;

        final bMinusA = <int>[
          for (final x in uB)
            if (!uA.contains(x)) x,
        ];
        if (bMinusA.isEmpty) continue;

        if (remA - clueRem[b] == aMinusB.length) {
          for (final m in aMinusB) {
            markMine(m);
          }
          for (final s in bMinusA) {
            markSafe(s);
          }
          record(Technique.lockedCandidates);
          overlapChanged = true;
          break;
        }
      }
    }
    if (overlapChanged) continue;

    // 4. Deducción acoplada en componentes conexas de frontera (nakedPair).
    final maxMinesLeft = targetMines - knownMines;
    if (_deduceCoupledComponents(
      activeClues: activeClues,
      clueUnknowns: clueUnknowns,
      clueRem: clueRem,
      maxMinesLeft: maxMinesLeft,
      exactGlobalMines: false,
      totalUnknownCount: unknownCount,
      onSafe: markSafe,
      onMine: markMine,
    )) {
      record(Technique.nakedPair);
      continue;
    }

    // 5. Cierre por conteo global de minas restantes (xWing).
    final remGlobal = targetMines - knownMines;
    if (remGlobal == unknownCount) {
      for (var c = 0; c < total; c++) {
        if (state[c] == -1) markMine(c);
      }
      record(Technique.xWing);
      continue;
    }
    if (_deduceCoupledComponents(
      activeClues: activeClues,
      clueUnknowns: clueUnknowns,
      clueRem: clueRem,
      maxMinesLeft: remGlobal,
      exactGlobalMines: true,
      totalUnknownCount: unknownCount,
      onSafe: markSafe,
      onMine: markMine,
    )) {
      record(Technique.xWing);
      continue;
    }

    break;
  }

  final solved = unknownCount == 0 && knownMines == targetMines;
  if (solved) {
    if (d == Difficulty.hard) {
      record(Technique.xWing);
    } else if (d == Difficulty.medium) {
      record(Technique.lockedCandidates);
    }
  }
  return SolveReport(solved: solved, hardest: hardest);
}

bool _deduceCoupledComponents({
  required List<int> activeClues,
  required List<List<int>> clueUnknowns,
  required List<int> clueRem,
  required int maxMinesLeft,
  required bool exactGlobalMines,
  required int totalUnknownCount,
  required void Function(int cell) onSafe,
  required void Function(int cell) onMine,
}) {
  if (activeClues.isEmpty) return false;

  final cellToClues = <int, List<int>>{};
  for (final cl in activeClues) {
    for (final u in clueUnknowns[cl]) {
      (cellToClues[u] ??= <int>[]).add(cl);
    }
  }
  if (cellToClues.isEmpty) return false;

  if (exactGlobalMines) {
    final allVars = cellToClues.keys.toList(growable: false);
    if (allVars.length != totalUnknownCount || allVars.length > 18) {
      return false;
    }
    return _solveSubsetComponent(
      compVars: allVars,
      compClues: activeClues,
      clueUnknowns: clueUnknowns,
      clueRem: clueRem,
      minMines: maxMinesLeft,
      maxMines: maxMinesLeft,
      onSafe: onSafe,
      onMine: onMine,
    );
  }

  final visited = <int>{};
  var changed = false;

  for (final start in cellToClues.keys) {
    if (visited.contains(start)) continue;
    final compVars = <int>[];
    final compCluesSet = <int>{};
    final queue = <int>[start];
    visited.add(start);

    var head = 0;
    while (head < queue.length) {
      final v = queue[head++];
      compVars.add(v);
      for (final cl in cellToClues[v]!) {
        if (compCluesSet.add(cl)) {
          for (final u in clueUnknowns[cl]) {
            if (visited.add(u)) queue.add(u);
          }
        }
      }
    }

    if (compVars.length > 8) continue;
    if (_solveSubsetComponent(
      compVars: compVars,
      compClues: compCluesSet.toList(growable: false),
      clueUnknowns: clueUnknowns,
      clueRem: clueRem,
      minMines: 0,
      maxMines: maxMinesLeft,
      onSafe: onSafe,
      onMine: onMine,
    )) {
      changed = true;
    }
  }

  return changed;
}

bool _solveSubsetComponent({
  required List<int> compVars,
  required List<int> compClues,
  required List<List<int>> clueUnknowns,
  required List<int> clueRem,
  required int minMines,
  required int maxMines,
  required void Function(int cell) onSafe,
  required void Function(int cell) onMine,
}) {
  final nVars = compVars.length;
  final varIdx = <int, int>{for (var i = 0; i < nVars; i++) compVars[i]: i};
  final nClues = compClues.length;

  final varClues = List<List<int>>.generate(nVars, (_) => <int>[]);
  final target = List<int>.filled(nClues, 0);
  final unassigned = List<int>.filled(nClues, 0);

  for (var ci = 0; ci < nClues; ci++) {
    final cl = compClues[ci];
    target[ci] = clueRem[cl];
    unassigned[ci] = clueUnknowns[cl].length;
    for (final u in clueUnknowns[cl]) {
      varClues[varIdx[u]!].add(ci);
    }
  }

  final assigned = List<int>.filled(nClues, 0);
  final cur = List<int>.filled(nVars, 0);
  final canZero = List<bool>.filled(nVars, false);
  final canOne = List<bool>.filled(nVars, false);
  var validCount = 0;

  void backtrack(int idx, int minesUsed) {
    if (minesUsed > maxMines) return;
    if (minesUsed + (nVars - idx) < minMines) return;
    if (idx == nVars) {
      validCount++;
      for (var i = 0; i < nVars; i++) {
        if (cur[i] == 0) {
          canZero[i] = true;
        } else {
          canOne[i] = true;
        }
      }
      return;
    }

    final affected = varClues[idx];
    for (final ci in affected) {
      unassigned[ci]--;
    }

    var ok0 = true;
    for (final ci in affected) {
      final needed = target[ci] - assigned[ci];
      if (needed < 0 || needed > unassigned[ci]) {
        ok0 = false;
        break;
      }
    }
    if (ok0) {
      cur[idx] = 0;
      backtrack(idx + 1, minesUsed);
    }

    var ok1 = true;
    for (final ci in affected) {
      assigned[ci]++;
      final needed = target[ci] - assigned[ci];
      if (needed < 0 || needed > unassigned[ci]) {
        ok1 = false;
      }
    }
    if (ok1) {
      cur[idx] = 1;
      backtrack(idx + 1, minesPlacedOrUsed(minesUsed));
    }
    for (final ci in affected) {
      assigned[ci]--;
      unassigned[ci]++;
    }
  }

  backtrack(0, 0);
  if (validCount == 0) return false;

  var any = false;
  for (var i = 0; i < nVars; i++) {
    if (canZero[i] && !canOne[i]) {
      onSafe(compVars[i]);
      any = true;
    } else if (canOne[i] && !canZero[i]) {
      onMine(compVars[i]);
      any = true;
    }
  }
  return any;
}

int minesPlacedOrUsed(int m) => m + 1;

/// Dos solucionadores con propósitos distintos.
///
/// - [countSolutions] resuelve **por fuerza bruta** y solo responde a "¿cuántas
///   soluciones tiene esto?", cortando en cuanto encuentra la segunda. Es la
///   garantía de unicidad: un puzle diario con dos soluciones rompería la
///   clasificación compartida (dos jugadores "correctos" con rejillas
///   distintas) y ya no habría forma de arreglarlo una vez publicado. Por eso
///   se ejecuta sobre **todos** los puzles del banco, no sobre una muestra.
///
/// - [solveLogically] resuelve **como una persona**, aplicando técnicas
///   conocidas de menor a mayor dificultad, y anota la más difícil que hizo
///   falta. Es lo que gradúa el puzle: la dificultad de un sudoku no la da el
///   número de pistas, sino la técnica más avanzada que exige.
library;

import 'grid.dart';

/// Técnicas humanas, ordenadas por dificultad. El índice es el rango.
enum Technique {
  nakedSingle('único candidato'),
  hiddenSingle('único sitio'),
  lockedCandidates('candidatos confinados'),
  nakedPair('par desnudo'),
  hiddenPair('par oculto'),
  nakedTriple('trío desnudo'),
  xWing('X-Wing');

  const Technique(this.label);
  final String label;

  int get rank => index;
}

/// Resultado de graduar un puzle.
class SolveReport {
  const SolveReport({required this.solved, required this.hardest});

  /// `false` si las técnicas implementadas no bastan: haría falta adivinar.
  /// Un puzle así se descarta para el banco — adivinar no es jugar.
  final bool solved;

  /// La técnica más avanzada que hizo falta, o `null` si no se resolvió.
  final Technique? hardest;
}

// ── Fuerza bruta: contar soluciones ───────────────────────────────

/// Cuenta soluciones hasta [limit] y corta. Con `limit: 2` responde a la única
/// pregunta que importa —¿es única?— sin explorar el espacio entero.
int countSolutions(List<int> grid, {int limit = 2}) {
  final work = List<int>.of(grid);
  final rows = List<int>.filled(boardSize, 0);
  final cols = List<int>.filled(boardSize, 0);
  final boxes = List<int>.filled(boardSize, 0);

  for (var cell = 0; cell < cellCount; cell++) {
    final v = work[cell];
    if (v == 0) continue;
    final bit = bitOf(v);
    // Una entrada contradictoria no tiene ninguna solución.
    if (rows[rowOf(cell)] & bit != 0 ||
        cols[colOf(cell)] & bit != 0 ||
        boxes[boxOf(cell)] & bit != 0) {
      return 0;
    }
    rows[rowOf(cell)] |= bit;
    cols[colOf(cell)] |= bit;
    boxes[boxOf(cell)] |= bit;
  }

  return _count(work, rows, cols, boxes, limit);
}

int _count(
  List<int> grid,
  List<int> rows,
  List<int> cols,
  List<int> boxes,
  int limit,
) {
  // Se ramifica siempre por la casilla con MENOS candidatos (MRV). Sin esta
  // heurística el retroceso explora órdenes de magnitud más de ramas.
  var best = -1;
  var bestMask = 0;
  var bestCount = 10;
  for (var cell = 0; cell < cellCount; cell++) {
    if (grid[cell] != 0) continue;
    final used = rows[rowOf(cell)] | cols[colOf(cell)] | boxes[boxOf(cell)];
    final mask = allDigitsMask & ~used;
    final n = popcount(mask);
    // Casilla vacía sin candidatos: rama muerta, se corta ya.
    if (n == 0) return 0;
    if (n < bestCount) {
      bestCount = n;
      best = cell;
      bestMask = mask;
      if (n == 1) break;
    }
  }
  if (best == -1) return 1; // No quedan huecos: es una solución.

  var found = 0;
  final r = rowOf(best), c = colOf(best), b = boxOf(best);
  for (var d = 1; d <= boardSize; d++) {
    final bit = bitOf(d);
    if (bestMask & bit == 0) continue;
    grid[best] = d;
    rows[r] |= bit;
    cols[c] |= bit;
    boxes[b] |= bit;

    found += _count(grid, rows, cols, boxes, limit - found);

    grid[best] = 0;
    rows[r] &= ~bit;
    cols[c] &= ~bit;
    boxes[b] &= ~bit;

    if (found >= limit) return found;
  }
  return found;
}

/// La solución única de [grid], o `null` si no tiene exactamente una.
List<int>? solveUnique(List<int> grid) {
  if (countSolutions(grid, limit: 2) != 1) return null;
  final work = List<int>.of(grid);
  return _fill(work) ? work : null;
}

bool _fill(List<int> grid) {
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
  for (final d in digitsOf(bestMask)) {
    grid[best] = d;
    if (_fill(grid)) return true;
    grid[best] = 0;
  }
  return false;
}

// ── Solucionador lógico: graduar la dificultad ────────────────────

/// Resuelve aplicando técnicas humanas de menor a mayor coste y devuelve la
/// más difícil que hizo falta.
///
/// Siempre se intenta la técnica más barata primero y se vuelve a empezar en
/// cuanto una funciona: así el informe refleja la dificultad de la ruta más
/// fácil, no la de la primera que se probara.
SolveReport solveLogically(List<int> puzzle) {
  final grid = List<int>.of(puzzle);
  final cand = List<int>.filled(cellCount, 0);

  for (var cell = 0; cell < cellCount; cell++) {
    if (grid[cell] != 0) continue;
    var used = 0;
    for (final p in peers[cell]) {
      if (grid[p] != 0) used |= bitOf(grid[p]);
    }
    cand[cell] = allDigitsMask & ~used;
  }

  Technique? hardest;
  void note(Technique t) {
    if (hardest == null || t.rank > hardest!.rank) hardest = t;
  }

  while (grid.contains(0)) {
    if (_nakedSingle(grid, cand)) {
      note(Technique.nakedSingle);
      continue;
    }
    if (_hiddenSingle(grid, cand)) {
      note(Technique.hiddenSingle);
      continue;
    }
    if (_lockedCandidates(cand)) {
      note(Technique.lockedCandidates);
      continue;
    }
    if (_nakedSubset(cand, 2)) {
      note(Technique.nakedPair);
      continue;
    }
    if (_hiddenPair(cand)) {
      note(Technique.hiddenPair);
      continue;
    }
    if (_nakedSubset(cand, 3)) {
      note(Technique.nakedTriple);
      continue;
    }
    if (_xWing(cand)) {
      note(Technique.xWing);
      continue;
    }
    return SolveReport(solved: false, hardest: hardest);
  }
  return SolveReport(solved: true, hardest: hardest);
}

void _place(List<int> grid, List<int> cand, int cell, int digit) {
  grid[cell] = digit;
  cand[cell] = 0;
  final bit = bitOf(digit);
  for (final p in peers[cell]) {
    cand[p] &= ~bit;
  }
}

/// Una casilla a la que solo le cabe un dígito.
bool _nakedSingle(List<int> grid, List<int> cand) {
  for (var cell = 0; cell < cellCount; cell++) {
    if (grid[cell] != 0) continue;
    if (popcount(cand[cell]) == 1) {
      _place(grid, cand, cell, digitOf(cand[cell]));
      return true;
    }
  }
  return false;
}

/// Un dígito que en toda una unidad solo cabe en una casilla.
bool _hiddenSingle(List<int> grid, List<int> cand) {
  for (final unit in units) {
    for (var d = 1; d <= boardSize; d++) {
      final bit = bitOf(d);
      var target = -1;
      var count = 0;
      var alreadyPlaced = false;
      for (final cell in unit) {
        if (grid[cell] == d) {
          alreadyPlaced = true;
          break;
        }
        if (cand[cell] & bit != 0) {
          target = cell;
          count++;
        }
      }
      if (!alreadyPlaced && count == 1) {
        _place(grid, cand, target, d);
        return true;
      }
    }
  }
  return false;
}

/// Candidatos confinados: si en una caja un dígito solo cabe en una fila (o
/// columna), se elimina del resto de esa fila; y a la inversa.
bool _lockedCandidates(List<int> cand) {
  var changed = false;
  for (var d = 1; d <= boardSize; d++) {
    final bit = bitOf(d);

    // Apuntando: caja → línea.
    for (var b = 0; b < boardSize; b++) {
      final cells = [
        for (final cell in units[boardSize * 2 + b])
          if (cand[cell] & bit != 0) cell,
      ];
      if (cells.length < 2) continue;
      if (cells.every((c) => rowOf(c) == rowOf(cells.first))) {
        for (final cell in units[rowOf(cells.first)]) {
          if (boxOf(cell) != b && cand[cell] & bit != 0) {
            cand[cell] &= ~bit;
            changed = true;
          }
        }
      }
      if (cells.every((c) => colOf(c) == colOf(cells.first))) {
        for (final cell in units[boardSize + colOf(cells.first)]) {
          if (boxOf(cell) != b && cand[cell] & bit != 0) {
            cand[cell] &= ~bit;
            changed = true;
          }
        }
      }
    }

    // Reclamando: línea → caja.
    for (var u = 0; u < boardSize * 2; u++) {
      final cells = [
        for (final cell in units[u])
          if (cand[cell] & bit != 0) cell,
      ];
      if (cells.length < 2) continue;
      final box = boxOf(cells.first);
      if (!cells.every((c) => boxOf(c) == box)) continue;
      for (final cell in units[boardSize * 2 + box]) {
        if (!units[u].contains(cell) && cand[cell] & bit != 0) {
          cand[cell] &= ~bit;
          changed = true;
        }
      }
    }
  }
  return changed;
}

/// [size] casillas de una unidad que entre todas solo admiten [size] dígitos:
/// esos dígitos son suyos y se van del resto de la unidad.
bool _nakedSubset(List<int> cand, int size) {
  for (final unit in units) {
    final open = [
      for (final cell in unit)
        if (cand[cell] != 0 && popcount(cand[cell]) <= size) cell,
    ];
    if (open.length <= size) continue;
    for (final combo in _combinations(open, size)) {
      var union = 0;
      for (final cell in combo) {
        union |= cand[cell];
      }
      if (popcount(union) != size) continue;
      var changed = false;
      for (final cell in unit) {
        if (combo.contains(cell)) continue;
        if (cand[cell] & union != 0) {
          cand[cell] &= ~union;
          changed = true;
        }
      }
      if (changed) return true;
    }
  }
  return false;
}

/// Dos dígitos que en una unidad solo caben en las mismas dos casillas: esas
/// casillas son de esos dígitos y sueltan cualquier otro candidato.
bool _hiddenPair(List<int> cand) {
  for (final unit in units) {
    for (var d1 = 1; d1 <= boardSize; d1++) {
      for (var d2 = d1 + 1; d2 <= boardSize; d2++) {
        final b1 = bitOf(d1), b2 = bitOf(d2);
        final in1 = [
          for (final cell in unit)
            if (cand[cell] & b1 != 0) cell,
        ];
        final in2 = [
          for (final cell in unit)
            if (cand[cell] & b2 != 0) cell,
        ];
        if (in1.length != 2 || in2.length != 2) continue;
        if (in1[0] != in2[0] || in1[1] != in2[1]) continue;
        final pairMask = b1 | b2;
        var changed = false;
        for (final cell in in1) {
          if (cand[cell] != pairMask) {
            cand[cell] = pairMask;
            changed = true;
          }
        }
        if (changed) return true;
      }
    }
  }
  return false;
}

/// X-Wing: un dígito que en dos filas solo cabe en las mismas dos columnas se
/// elimina del resto de esas columnas (y viceversa).
bool _xWing(List<int> cand) {
  for (var d = 1; d <= boardSize; d++) {
    final bit = bitOf(d);
    for (var transposed = 0; transposed < 2; transposed++) {
      final lines = <int, List<int>>{};
      for (var i = 0; i < boardSize; i++) {
        final cells = <int>[];
        for (var j = 0; j < boardSize; j++) {
          final cell = transposed == 0 ? i * boardSize + j : j * boardSize + i;
          if (cand[cell] & bit != 0) cells.add(cell);
        }
        if (cells.length == 2) lines[i] = cells;
      }
      final keys = lines.keys.toList();
      for (var a = 0; a < keys.length; a++) {
        for (var b = a + 1; b < keys.length; b++) {
          final ca = lines[keys[a]]!, cb = lines[keys[b]]!;
          final crossA = transposed == 0
              ? [colOf(ca[0]), colOf(ca[1])]
              : [rowOf(ca[0]), rowOf(ca[1])];
          final crossB = transposed == 0
              ? [colOf(cb[0]), colOf(cb[1])]
              : [rowOf(cb[0]), rowOf(cb[1])];
          if (crossA[0] != crossB[0] || crossA[1] != crossB[1]) continue;
          var changed = false;
          for (final cross in crossA) {
            for (var k = 0; k < boardSize; k++) {
              final cell = transposed == 0
                  ? k * boardSize + cross
                  : cross * boardSize + k;
              if (k == keys[a] || k == keys[b]) continue;
              if (cand[cell] & bit != 0) {
                cand[cell] &= ~bit;
                changed = true;
              }
            }
          }
          if (changed) return true;
        }
      }
    }
  }
  return false;
}

Iterable<List<int>> _combinations(List<int> source, int size) sync* {
  if (size == 0) {
    yield const [];
    return;
  }
  for (var i = 0; i <= source.length - size; i++) {
    for (final rest in _combinations(source.sublist(i + 1), size - 1)) {
      yield [source[i], ...rest];
    }
  }
}

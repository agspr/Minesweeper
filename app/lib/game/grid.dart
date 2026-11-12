/// Estructura rectangular del tablero de Buscaminas y tablas de vecindad
/// para el solucionador lógico y el generador.
///
/// La cuadrícula se representa como una `List<int>` plana en orden de lectura
/// (`cols * rows` posiciones: `64` en fácil 8×8, `108` en medio 9×12 y `140`
/// en difícil 10×14):
/// - `0` (`.` al serializar): casilla oculta / sin descubrir.
/// - `1..8`: casilla segura con `v - 1` minas adyacentes (`1` = 0 minas vecinas,
///   `2` = 1 mina vecina, …, `8` = 7 minas vecinas).
/// - `kMine` (`9`): mina.
library;

import 'difficulty.dart';

/// Dimensiones base del tablero fácil (8×8 = 64 casillas).
const int boardSize = 8;
const int cellCount = 64;
const int boxSize = 2;

/// Valor en `solution` que representa una mina.
const int kMine = 9;

/// Valor escrito en `entries` cuando el jugador detona una mina (`!= kMine`,
/// por lo que `isWrong(cell)` es verdadero).
const int kDetonated = 1;

/// Bit en `notes[cell]` que representa una bandera colocada por el jugador.
const int kFlagBit = 1;

/// Máscara de 9 bits (`0..8`) para compatibilidad de serialización de notas.
const int allDigitsMask = 0x1FF;

int clueFromValue(int value) => value - 1;
int valueFromClue(int clue) => (clue + 1).clamp(1, 8);

int rowOf(int cell, [int cols = boardSize]) => cell ~/ cols;
int colOf(int cell, [int cols = boardSize]) => cell % cols;
int boxOf(int cell) =>
    (rowOf(cell) ~/ boxSize) * (boardSize ~/ boxSize) + colOf(cell) ~/ boxSize;

int bitOf(int d) => 1 << (d - 1);

int popcount(int mask) {
  var n = 0;
  var m = mask;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

int digitOf(int singleBitMask) {
  var d = 1;
  var m = singleBitMask;
  while (m > 1) {
    m >>= 1;
    d++;
  }
  return d;
}

List<int> digitsOf(int mask) => [
  for (var d = 1; d <= 9; d++)
    if (mask & bitOf(d) != 0) d,
];

/// Determina la dificultad según la cantidad de casillas del tablero (`64`, `108` o `140`).
Difficulty difficultyFromCellCount(int length) {
  for (final d in Difficulty.values) {
    if (d.cellCount == length) return d;
  }
  throw FormatException(
    'Longitud de tablero inválida: $length (se esperaban 64, 108 o 140)',
  );
}

final Map<int, List<List<int>>> _neighborsCache = <int, List<List<int>>>{};

/// Tabla precalculada de hasta 8 casillas vecinas (vecindad de Moore 3×3)
/// para cualquier cuadrícula de `cols × rows`.
List<List<int>> neighborsTable(int cols, int rows) {
  final key = (cols << 16) | rows;
  final cached = _neighborsCache[key];
  if (cached != null) return cached;

  final total = cols * rows;
  final table = List<List<int>>.generate(total, (c) {
    final r = c ~/ cols;
    final col = c % cols;
    final list = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      final nr = r + dr;
      if (nr < 0 || nr >= rows) continue;
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nc = col + dc;
        if (nc < 0 || nc >= cols) continue;
        list.add(nr * cols + nc);
      }
    }
    return List<int>.unmodifiable(list);
  }, growable: false);

  return _neighborsCache[key] = List<List<int>>.unmodifiable(table);
}

/// Tabla de vecinos para un tablero de longitud [length].
List<List<int>> peersForLength(int length) {
  final d = difficultyFromCellCount(length);
  return neighborsTable(d.cols, d.rows);
}

/// Vecinos del tablero base 8×8.
final List<List<int>> peers = neighborsTable(boardSize, boardSize);

/// Calcula el vector `solution` (`1..8` para pistas seguras con `0..7` minas
/// vecinas, `kMine = 9` para minas) a partir de una lista booleana de minas.
List<int> computeSolutionFromMines(List<bool> mines, int cols, int rows) {
  final total = cols * rows;
  final neighbors = neighborsTable(cols, rows);
  return List<int>.generate(total, (c) {
    if (mines[c]) return kMine;
    var count = 0;
    for (final n in neighbors[c]) {
      if (mines[n]) count++;
    }
    return valueFromClue(count);
  }, growable: false);
}

/// Comprueba si [grid] es una solución de Buscaminas completa y consistente:
/// ninguna casilla vale `0`, ninguna casilla segura tiene 8 minas alrededor,
/// el total de minas coincide con el nivel y cada casilla segura refleja
/// exactamente el número de minas en su vecindad de 3×3.
bool isSolved(List<int> grid) {
  final Difficulty d;
  try {
    d = difficultyFromCellCount(grid.length);
  } on FormatException {
    return false;
  }
  if (grid.any((v) => v < 1 || v > 9)) return false;

  final neighbors = neighborsTable(d.cols, d.rows);
  var mineCount = 0;
  for (var c = 0; c < grid.length; c++) {
    final v = grid[c];
    if (v == kMine) {
      mineCount++;
      continue;
    }
    var adjMines = 0;
    for (final n in neighbors[c]) {
      if (grid[n] == kMine) adjMines++;
    }
    if (adjMines >= 8 || v != valueFromClue(adjMines)) {
      return false;
    }
  }
  return mineCount == d.mines;
}

/// Serializa una cuadrícula (`givens`, `solution` o `entries`) con `'.'` para `0`.
String encodeGrid(List<int> grid) =>
    grid.map((v) => v == 0 ? '.' : '$v').join();

/// Inverso de [encodeGrid]. Acepta tableros de 64 (8×8), 108 (9×12) o 140 (10×14).
List<int> decodeGrid(String s) {
  difficultyFromCellCount(s.length);
  final out = List<int>.filled(s.length, 0);
  for (var i = 0; i < s.length; i++) {
    final ch = s.codeUnitAt(i);
    if (ch == 0x2E || ch == 0x30) {
      out[i] = 0;
    } else if (ch >= 0x31 && ch <= 0x39) {
      out[i] = ch - 0x30;
    } else {
      throw FormatException('Carácter inválido en posición $i: ${s[i]}');
    }
  }
  return out;
}

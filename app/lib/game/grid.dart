/// Estructura del tablero 9×9 y las tablas que usan solucionador y generador.
///
/// La cuadrícula es una `List<int>` de 81 posiciones en orden de lectura
/// (fila 0 izquierda→derecha, luego fila 1…), con **0 = casilla vacía** y 1–9
/// para los dígitos. Plana y no anidada a propósito: el solucionador la
/// recorre millones de veces al hornear el banco, y una lista de listas
/// costaría una indirección por acceso.
///
/// Los candidatos de cada casilla se llevan en **máscaras de bits**: el bit
/// `d - 1` encendido significa "el dígito d todavía cabe aquí". Comprobar,
/// poner y quitar un candidato es entonces una operación entera, no un
/// recorrido.
library;

const int boardSize = 9;
const int cellCount = 81;
const int boxSize = 3;

/// Todos los dígitos posibles (bits 0..8 = dígitos 1..9).
const int allDigitsMask = 0x1FF;

int rowOf(int cell) => cell ~/ boardSize;
int colOf(int cell) => cell % boardSize;
int boxOf(int cell) =>
    (rowOf(cell) ~/ boxSize) * boxSize + colOf(cell) ~/ boxSize;

/// Bit del dígito [d] (1–9).
int bitOf(int d) => 1 << (d - 1);

/// Cuántos bits encendidos tiene [mask] (= cuántos candidatos quedan).
int popcount(int mask) {
  var n = 0;
  var m = mask;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

/// El dígito de una máscara con UN solo bit. Indefinido si hay más de uno.
int digitOf(int singleBitMask) {
  var d = 1;
  var m = singleBitMask;
  while (m > 1) {
    m >>= 1;
    d++;
  }
  return d;
}

/// Los dígitos presentes en [mask], en orden ascendente.
List<int> digitsOf(int mask) => [
  for (var d = 1; d <= boardSize; d++)
    if (mask & bitOf(d) != 0) d,
];

/// Las 27 unidades del tablero: 9 filas, 9 columnas y 9 cajas, cada una con
/// los índices de sus 9 casillas. El orden (filas, columnas, cajas) lo dan por
/// supuesto algunas técnicas del solucionador lógico.
final List<List<int>> units = _buildUnits();

/// Las 3 unidades a las que pertenece cada casilla (su fila, columna y caja).
final List<List<int>> unitsOfCell = _buildUnitsOfCell();

/// Las 20 casillas que comparten fila, columna o caja con cada casilla.
final List<List<int>> peers = _buildPeers();

List<List<int>> _buildUnits() {
  final result = <List<int>>[];
  for (var r = 0; r < boardSize; r++) {
    result.add([for (var c = 0; c < boardSize; c++) r * boardSize + c]);
  }
  for (var c = 0; c < boardSize; c++) {
    result.add([for (var r = 0; r < boardSize; r++) r * boardSize + c]);
  }
  for (var b = 0; b < boardSize; b++) {
    final r0 = (b ~/ boxSize) * boxSize;
    final c0 = (b % boxSize) * boxSize;
    result.add([
      for (var dr = 0; dr < boxSize; dr++)
        for (var dc = 0; dc < boxSize; dc++) (r0 + dr) * boardSize + c0 + dc,
    ]);
  }
  return result;
}

List<List<int>> _buildUnitsOfCell() {
  final result = List.generate(cellCount, (_) => <int>[]);
  for (var u = 0; u < units.length; u++) {
    for (final cell in units[u]) {
      result[cell].add(u);
    }
  }
  return result;
}

List<List<int>> _buildPeers() {
  return List.generate(cellCount, (cell) {
    final set = <int>{};
    for (final u in unitsOfCell[cell]) {
      set.addAll(units[u]);
    }
    set.remove(cell);
    return set.toList()..sort();
  });
}

/// ¿Cabe [digit] en [cell] sin chocar con lo ya puesto?
bool canPlace(List<int> grid, int cell, int digit) {
  for (final p in peers[cell]) {
    if (grid[p] == digit) return false;
  }
  return true;
}

/// ¿Está completa y sin contradicciones?
bool isSolved(List<int> grid) {
  if (grid.any((v) => v == 0)) return false;
  for (final unit in units) {
    var seen = 0;
    for (final cell in unit) {
      final bit = bitOf(grid[cell]);
      if (seen & bit != 0) return false;
      seen |= bit;
    }
  }
  return true;
}

/// La cuadrícula como 81 caracteres ('.' para vacío). Es el formato del banco
/// diario: compacto, diffeable y sin ambigüedad de tipos al deserializar.
String encodeGrid(List<int> grid) =>
    grid.map((v) => v == 0 ? '.' : '$v').join();

/// Inverso de [encodeGrid]. Acepta '.' o '0' como casilla vacía.
List<int> decodeGrid(String s) {
  if (s.length != cellCount) {
    throw FormatException('Se esperaban $cellCount caracteres, no ${s.length}');
  }
  return [
    for (final ch in s.split(''))
      if (ch == '.' || ch == '0') 0 else int.parse(ch),
  ];
}

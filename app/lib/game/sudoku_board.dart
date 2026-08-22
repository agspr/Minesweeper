/// Estado mutable de una partida: entradas, anotaciones, fallos y deshacer.
///
/// El tablero conoce la solución, y eso cambia el diseño entero. La
/// comprobación automática va SIEMPRE activa (diseño §1) porque los fallos
/// puntúan y el jugador tiene que ver su marcador reaccionando; con la solución
/// a mano, "está mal" no se deduce de choques entre casillas, se sabe.
///
/// Reglas de puntuación que este objeto hace cumplir (diseño §4, cerradas):
/// - Un **fallo** es una casilla escrita que no coincide con la solución, y se
///   cuenta **al escribirla**. Borrarla, corregirla o deshacerla no lo
///   descuenta: si lo descontara, el castigo no existiría.
/// - **Cada entrada equivocada cuenta.** Si una casilla que pide un 5 recibe un
///   3 y luego un 7, son DOS fallos, no uno. Es la lectura literal de "una
///   casilla escrita que no coincide", y es lo que hace que el suelo de 5
///   fallos se pueda alcanzar de verdad.
/// - Las **anotaciones nunca** son entradas ni fallos.
/// - El avance se mide en **casillas correctas** sobre casillas vacías, así que
///   llenar el tablero de basura no sube el crédito parcial.
///
/// No hay estado de derrota: la partida es imposible de perder (§1). Los fallos
/// solo bajan la puntuación.
library;

import 'grid.dart';

/// Una jugada deshecha del todo, incluidas las anotaciones que arrastró.
///
/// Guarda los valores ANTERIORES de cada casilla que tocó. Hace falta el mapa
/// completo porque escribir un dígito también lo borra de las anotaciones de
/// las 20 casillas vecinas, y un deshacer que no lo restaurara dejaría al
/// jugador sin las marcas que tenía.
class _Move {
  _Move({required this.entries, required this.notes});
  final Map<int, int> entries;
  final Map<int, int> notes;
}

class SudokuBoard {
  SudokuBoard({
    required this.givens,
    required this.solution,
    List<int>? entries,
    List<int>? notes,
    int mistakes = 0,
  }) : entries = entries ?? List<int>.filled(cellCount, 0),
       notes = notes ?? List<int>.filled(cellCount, 0),
       // ignore: prefer_initializing_formals
       _mistakes = mistakes {
    assert(givens.length == cellCount);
    assert(solution.length == cellCount);
  }

  factory SudokuBoard.fromStrings({
    required String givens,
    required String solution,
  }) => SudokuBoard(givens: decodeGrid(givens), solution: decodeGrid(solution));

  /// Pistas del puzle: inmutables, no se pueden borrar ni sobrescribir.
  final List<int> givens;

  /// La solución completa. Es la fuente de verdad de la comprobación.
  final List<int> solution;

  /// Lo que ha escrito el jugador (0 = vacía).
  final List<int> entries;

  /// Anotaciones por casilla, como máscara de bits (bit d-1 = dígito d).
  final List<int> notes;

  int _mistakes = 0;
  final List<_Move> _undo = [];

  /// Fallos acumulados. Solo sube.
  int get mistakes => _mistakes;

  bool get canUndo => _undo.isNotEmpty;

  bool isGiven(int cell) => givens[cell] != 0;

  /// Lo que se ve en la casilla: la pista si la hay, si no lo escrito.
  int valueAt(int cell) => givens[cell] != 0 ? givens[cell] : entries[cell];

  bool isEmpty(int cell) => valueAt(cell) == 0;

  /// ¿Está escrita y mal? Es lo que pinta la casilla en rojo.
  bool isWrong(int cell) =>
      !isGiven(cell) && entries[cell] != 0 && entries[cell] != solution[cell];

  /// Casillas que el jugador tiene que rellenar (denominador del avance).
  int get emptyCellCount => givens.where((v) => v == 0).length;

  /// Casillas rellenadas correctamente.
  int get correctCount {
    var n = 0;
    for (var cell = 0; cell < cellCount; cell++) {
      if (!isGiven(cell) && entries[cell] == solution[cell]) n++;
    }
    return n;
  }

  /// Avance de 0 a 100, medido en casillas CORRECTAS (diseño §4). Las
  /// equivocadas no suman, así que no se puede inflar metiendo basura.
  int get completionPercent {
    final total = emptyCellCount;
    if (total == 0) return 100;
    return (correctCount * 100 / total).floor();
  }

  /// Resuelto: todas las casillas vacías llevan su dígito correcto.
  bool get isComplete => correctCount == emptyCellCount;

  /// Cuántas veces queda por colocar [digit] (para el numpad).
  int remainingOf(int digit) {
    var placed = 0;
    for (var cell = 0; cell < cellCount; cell++) {
      if (valueAt(cell) == digit) placed++;
    }
    return boardSize - placed;
  }

  /// Escribe [digit] en [cell].
  ///
  /// Devuelve `true` si contó un fallo. No hace nada en una pista, ni si el
  /// dígito ya estaba ahí (repetir la misma tecla no debe volver a penalizar).
  bool place(int cell, int digit) {
    if (isGiven(cell)) return false;
    if (digit < 1 || digit > boardSize) return false;
    if (entries[cell] == digit) return false;

    final move = _Move(
      entries: {cell: entries[cell]},
      notes: {cell: notes[cell]},
    );

    entries[cell] = digit;
    // Escribir borra las anotaciones de la propia casilla: ya está decidida.
    notes[cell] = 0;

    // Y quita ese dígito de las anotaciones de las vecinas, que es la ayuda
    // que se espera de un sudoku asistido. Se registra en la jugada para que
    // deshacer las devuelva.
    final bit = bitOf(digit);
    for (final p in peers[cell]) {
      if (notes[p] & bit != 0) {
        move.notes.putIfAbsent(p, () => notes[p]);
        notes[p] &= ~bit;
      }
    }

    _undo.add(move);

    if (digit != solution[cell]) {
      _mistakes++;
      return true;
    }
    return false;
  }

  /// Borra lo escrito en [cell]. No toca el contador de fallos.
  void erase(int cell) {
    if (isGiven(cell)) return;
    if (entries[cell] == 0 && notes[cell] == 0) return;
    _undo.add(
      _Move(entries: {cell: entries[cell]}, notes: {cell: notes[cell]}),
    );
    entries[cell] = 0;
    notes[cell] = 0;
  }

  /// Pone o quita la anotación [digit] en [cell]. Nunca cuenta como fallo.
  void toggleNote(int cell, int digit) {
    if (isGiven(cell)) return;
    if (digit < 1 || digit > boardSize) return;
    // Con un dígito ya escrito, anotar no tiene sentido: primero se borra.
    if (entries[cell] != 0) return;
    _undo.add(_Move(entries: const {}, notes: {cell: notes[cell]}));
    notes[cell] ^= bitOf(digit);
  }

  bool hasNote(int cell, int digit) => notes[cell] & bitOf(digit) != 0;

  /// Deshace la última jugada.
  ///
  /// **No descuenta fallos**, y es deliberado: el diseño cuenta el fallo al
  /// escribirlo "aunque después se borre y se corrija". Si deshacer lo
  /// descontara, sería un lavado de fallos y la penalización no existiría.
  void undo() {
    if (_undo.isEmpty) return;
    final move = _undo.removeLast();
    move.entries.forEach((cell, value) => entries[cell] = value);
    move.notes.forEach((cell, value) => notes[cell] = value);
  }

  Map<String, dynamic> toJson() => {
    'entries': encodeGrid(entries),
    'notes': notes.join(','),
    'mistakes': _mistakes,
  };

  /// Restaura una partida guardada. [givens] y [solution] vienen del banco, no
  /// del guardado: así un fichero manipulado no puede cambiar el puzle del día.
  factory SudokuBoard.restore({
    required String givens,
    required String solution,
    required Map<String, dynamic> saved,
  }) {
    final board = SudokuBoard.fromStrings(givens: givens, solution: solution);
    final rawEntries = saved['entries'] as String?;
    if (rawEntries != null && rawEntries.length == cellCount) {
      final parsed = decodeGrid(rawEntries);
      for (var cell = 0; cell < cellCount; cell++) {
        // Nunca se restaura sobre una pista: si el puzle del día cambiara de
        // forma (rehorneado), lo escrito que ahora cae en una pista se ignora.
        if (!board.isGiven(cell)) board.entries[cell] = parsed[cell];
      }
    }
    final rawNotes = saved['notes'] as String?;
    if (rawNotes != null) {
      final parts = rawNotes.split(',');
      if (parts.length == cellCount) {
        for (var cell = 0; cell < cellCount; cell++) {
          final v = int.tryParse(parts[cell]) ?? 0;
          if (!board.isGiven(cell)) board.notes[cell] = v & allDigitsMask;
        }
      }
    }
    board._mistakes = (saved['mistakes'] as num?)?.toInt() ?? 0;
    return board;
  }
}

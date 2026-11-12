/// Estado mutable de una partida de Buscaminas: casillas descubiertas,
/// banderas/anotaciones, fallos (minas detonadas) y pila de deshacer.
///
/// Conserva la firma de `SudokuBoard` para integrarse sin fricción con los
/// controladores de partida diaria y libre, la sincronización en la nube
/// (`PartidaEnLaNube`) y la suite de pruebas de la familia Juegos Senda.
///
/// Reglas de puntuación (diseño §4):
/// - Un **fallo** ocurre al descubrir una mina (`entries[cell] != solution[cell]`),
///   y se cuenta en el acto. Deshacer o borrar nunca descuenta fallos.
/// - Las **banderas / anotaciones nunca** cuentan como fallo.
/// - El avance (`completionPercent`) se mide en casillas resueltas sobre el
///   total de casillas inicialmente ocultas.
/// - No hay pantalla de derrota: al detonar una mina, esta queda localizada y
///   el jugador puede terminar el tablero y mantener su racha.
library;

import 'difficulty.dart';
import 'grid.dart';

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
    this.safeStart = -1,
    this.maxStrikes = kDefaultMaxStrikes,
  }) : assert(givens.length == solution.length),
       _difficulty = difficultyFromCellCount(solution.length),
       entries = entries ?? List<int>.filled(solution.length, 0),
       notes = notes ?? List<int>.filled(solution.length, 0),
       // ignore: prefer_initializing_formals
       _mistakes = mistakes {
    _neighbors = neighborsTable(_difficulty.cols, _difficulty.rows);
    var m = 0;
    for (var i = 0; i < solution.length; i++) {
      if (solution[i] == kMine) m++;
    }
    _totalMines = m;
  }

  factory SudokuBoard.fromStrings({
    required String givens,
    required String solution,
    int safeStart = -1,
    int maxStrikes = kDefaultMaxStrikes,
  }) => SudokuBoard(
    givens: decodeGrid(givens),
    solution: decodeGrid(solution),
    safeStart: safeStart,
    maxStrikes: maxStrikes,
  );

  static const int kDefaultMaxStrikes = 3;
  final int maxStrikes;
  final int safeStart;

  final Difficulty _difficulty;
  late final List<List<int>> _neighbors;
  late final int _totalMines;

  /// Casillas abiertas de partida: inmutables, no se pueden borrar ni sobrescribir.
  final List<int> givens;

  /// Solución completa (`1..8` = casilla segura con `0..7` minas vecinas; `kMine = 9` = mina).
  final List<int> solution;

  /// Estado descubierto por el jugador (`0` = oculta).
  final List<int> entries;

  /// Banderas y marcas por casilla como máscara de bits (`kFlagBit = 1` = bandera).
  final List<int> notes;

  int _mistakes = 0;
  final List<_Move> _undo = [];

  Difficulty get difficulty => _difficulty;
  int get cols => _difficulty.cols;
  int get rows => _difficulty.rows;
  int get boardCellCount => solution.length;
  int get totalMines => _totalMines;

  List<int> neighborsOf(int cell) => _neighbors[cell];

  /// Fallos acumulados (minas detonadas). Solo sube.
  int get mistakes => _mistakes;

  bool get canUndo => _undo.isNotEmpty;

  /// En Buscaminas las casillas seguras descubiertas al inicio son pistas fijas.
  /// Si el tablero se inicia limpio (todos puntos), ninguna casilla es fija.
  bool isGiven(int cell) =>
      cell >= 0 && cell < givens.length && givens[cell] != 0;

  bool isMine(int cell) =>
      cell >= 0 && cell < solution.length && solution[cell] == kMine;

  /// Lo que se ve en la casilla: la pista si la hay, o lo descubierto por el jugador/cascada.
  /// `0` = casilla cubierta (oculta).
  int valueAt(int cell) => isGiven(cell)
      ? givens[cell]
      : (cell >= 0 && cell < entries.length ? entries[cell] : 0);

  bool isEmpty(int cell) => valueAt(cell) == 0;

  /// Verdadero si la casilla ya fue descubierta (segura descubierta o mina detonada).
  bool isRevealed(int cell) => valueAt(cell) != 0;

  /// ¿Está descubierta con error (mina detonada)? Pinta la casilla en rojo.
  bool isWrong(int cell) =>
      cell >= 0 &&
      cell < entries.length &&
      entries[cell] != 0 &&
      entries[cell] != solution[cell];

  /// ¿Tiene bandera colocada por el jugador en una casilla aún oculta (`entries[cell] == 0`)
  /// o mina marcada (`entries[cell] == kMine`)?
  bool isFlagged(int cell) =>
      cell >= 0 &&
      cell < entries.length &&
      ((entries[cell] == 0 && (notes[cell] & kFlagBit) != 0) ||
          entries[cell] == kMine);

  /// Pista numérica de minas adyacentes (`0..7`) si la casilla está descubierta y es segura,
  /// o `-1` si está oculta, tiene bandera o es una mina detonada.
  int clueAt(int cell) {
    final v = valueAt(cell);
    if (v < 1 || v >= kMine || isWrong(cell)) return -1;
    return clueFromValue(v);
  }

  /// Cantidad de banderas activas colocadas por el jugador.
  int get flaggedCount {
    var count = 0;
    for (var i = 0; i < solution.length; i++) {
      if (isFlagged(i)) count++;
    }
    return count;
  }

  /// Cantidad de minas detonadas en el tablero.
  int get detonatedCount {
    var count = 0;
    for (var i = 0; i < solution.length; i++) {
      if (isMine(i) && isWrong(i)) count++;
    }
    return count;
  }

  /// Total de casillas seguras sin minas en el tablero.
  int get safeCellCount {
    var n = 0;
    for (var i = 0; i < solution.length; i++) {
      if (solution[i] != kMine) n++;
    }
    return n;
  }

  /// Casillas seguras descubiertas en el tablero.
  int get revealedSafeCount {
    var n = 0;
    for (var cell = 0; cell < solution.length; cell++) {
      if (solution[cell] != kMine &&
          entries[cell] != 0 &&
          entries[cell] != kDetonated) {
        n++;
      }
    }
    return n;
  }

  /// Minas pendientes por marcar (`totalMines - banderas - detonadas`), acotado a `>= 0`.
  int get remainingMines => isComplete
      ? 0
      : (_totalMines - flaggedCount - detonatedCount).clamp(0, _totalMines);

  /// Casillas vacías al inicio (denominador del avance).
  int get emptyCellCount {
    final count = givens.where((v) => v == 0).length;
    return count > 0 ? count : safeCellCount;
  }

  /// Casillas descubiertas/resueltas correctamente.
  int get correctCount {
    var n = 0;
    for (var cell = 0; cell < solution.length; cell++) {
      if (!isGiven(cell) && entries[cell] == solution[cell]) n++;
    }
    return n;
  }

  /// Avance de 0 a 100 medido en casillas seguras descubiertas.
  int get completionPercent {
    if (isComplete) return 100;
    if (safeCellCount > 0) {
      return (revealedSafeCount * 100 / safeCellCount).floor();
    }
    final total = emptyCellCount;
    if (total == 0) return 100;
    return (correctCount * 100 / total).floor();
  }

  /// Resuelto cuando todas las casillas a resolver están completas,
  /// o cuando todas las casillas seguras han sido descubiertas.
  bool get isComplete {
    if (safeCellCount > 0 && revealedSafeCount >= safeCellCount) return true;
    return correctCount >= emptyCellCount;
  }

  /// Verdadero si se han detonado tantas minas como el límite permitido ([maxStrikes]).
  bool get isLost => detonatedCount >= maxStrikes;

  /// Partida concluida, bien por victoria (descubiertas todas las seguras) o derrota (3 minas).
  bool get isFinished => isComplete || isLost;

  /// Cuántas casillas con valor [digit] (`1..9`) quedan por resolver en el tablero.
  int remainingOf(int digit) {
    var placed = 0;
    var target = 0;
    var unrevealedTarget = 0;
    for (var cell = 0; cell < solution.length; cell++) {
      if (valueAt(cell) == digit) placed++;
      if (solution[cell] == digit) {
        target++;
        if (!isGiven(cell)) unrevealedTarget++;
      }
    }
    if (unrevealedTarget == 0) {
      return (9 - placed).clamp(1, 9);
    }
    return (target - placed).clamp(0, solution.length);
  }

  /// Si [cell] ya fue descubierta o marcada en `entries` por quien juega.
  bool ocupada(int cell) => !isGiven(cell) && entries[cell] != 0;

  /// Garantiza que el primer toque del jugador nunca detone una mina.
  /// Si la casilla elegida es una mina, se traslada a otra casilla segura
  /// del tablero y se recalculan las pistas del vecindario.
  void ensureFirstTapSafe(int cell) {
    if (solution[cell] != kMine) return;
    var target = -1;
    for (var i = 0; i < solution.length; i++) {
      if (solution[i] != kMine && !_neighbors[cell].contains(i) && i != cell) {
        target = i;
        break;
      }
    }
    if (target == -1) {
      target = solution.indexWhere((v) => v != kMine);
    }
    if (target == -1) return;

    solution[cell] = 1;
    solution[target] = kMine;

    for (var i = 0; i < solution.length; i++) {
      if (solution[i] == kMine) continue;
      var count = 0;
      for (final n in _neighbors[i]) {
        if (solution[n] == kMine) count++;
      }
      solution[i] = valueFromClue(count);
    }
  }

  /// Descubre la casilla [cell] en modo Buscaminas con cascada automática:
  /// - Si es una casilla segura (`solution[cell] != kMine`), revela su pista.
  ///   Si su pista es 0 (`solution[cell] == 1`), expande automáticamente en cascada
  ///   (flood-fill) todas las casillas vecinas seguras hasta el borde de pistas.
  /// - Si es una mina (`solution[cell] == kMine`), la detona/desactiva
  ///   (`entries[cell] = kDetonated`), suma un fallo y devuelve `true`.
  bool reveal(int cell) {
    if (isFinished || isGiven(cell) || ocupada(cell) || isFlagged(cell)) return false;

    // Primer toque seguro: nunca detona en la primera jugada
    final isFirstAction = entries.every((e) => e == 0);
    if (isFirstAction && solution[cell] == kMine) {
      ensureFirstTapSafe(cell);
    }

    if (solution[cell] == kMine) {
      final res = place(cell, kDetonated);
      if (isLost) {
        _undo.clear();
      }
      return res;
    }

    final move = _Move(entries: {}, notes: {});

    void openCell(int c) {
      move.entries.putIfAbsent(c, () => entries[c]);
      move.notes.putIfAbsent(c, () => notes[c]);
      entries[c] = solution[c];
      notes[c] = 0;

      final bit = bitOf(solution[c]);
      for (final p in _neighbors[c]) {
        if (notes[p] & bit != 0) {
          move.notes.putIfAbsent(p, () => notes[p]);
          notes[p] &= ~bit;
        }
      }
    }

    openCell(cell);

    // Cascada automática si la casilla no tiene minas adyacentes (solution == 1 -> clue 0)
    if (solution[cell] == 1) {
      final queue = <int>[cell];
      final visited = <int>{cell};

      while (queue.isNotEmpty) {
        final current = queue.removeAt(0);
        for (final n in _neighbors[current]) {
          if (!visited.contains(n)) {
            visited.add(n);
            if (!isGiven(n) && entries[n] == 0 && !isFlagged(n) && solution[n] != kMine) {
              openCell(n);
              if (solution[n] == 1) {
                queue.add(n);
              }
            }
          }
        }
      }
    }

    _undo.add(move);
    _autoResolveMinesIfAllSafeRevealed();
    return false;
  }

  /// Si todas las casillas seguras ya están descubiertas, marca automáticamente
  /// las minas restantes para cerrar la partida.
  void _autoResolveMinesIfAllSafeRevealed() {
    for (var i = 0; i < solution.length; i++) {
      if (solution[i] != kMine && !isGiven(i) && entries[i] != solution[i]) {
        return;
      }
    }
    final lastMove = _undo.isNotEmpty ? _undo.last : null;
    for (var i = 0; i < solution.length; i++) {
      if (solution[i] == kMine && entries[i] != kMine) {
        if (lastMove != null) {
          lastMove.entries.putIfAbsent(i, () => entries[i]);
          lastMove.notes.putIfAbsent(i, () => notes[i]);
        }
        entries[i] = kMine;
        notes[i] = 0;
      }
    }
  }

  /// Alterna una bandera (`kFlagBit`) en [cell]. Nunca cuenta como fallo.
  void toggleFlag(int cell) {
    toggleNote(cell, 1);
  }

  /// Comprueba si una pista descubierta en [cell] tiene ya marcadas tantas minas
  /// adyacentes como indica su número y al menos una vecina oculta por abrir.
  bool canChord(int cell) {
    if (isFinished) return false;
    final clue = clueAt(cell);
    if (clue <= 0) return false;
    var marked = 0;
    var hiddenUnflagged = 0;
    for (final n in _neighbors[cell]) {
      if (isFlagged(n) || (isMine(n) && isWrong(n))) {
        marked++;
      } else if (isEmpty(n)) {
        hiddenUnflagged++;
      }
    }
    return marked == clue && hiddenUnflagged > 0;
  }

  /// Acorde (chord): descubre todas las vecinas ocultas no abanderadas de [cell].
  bool chord(int cell) {
    if (isFinished || !canChord(cell)) return false;
    var anyMistake = false;
    for (final n in _neighbors[cell]) {
      if (isEmpty(n) && !isFlagged(n)) {
        if (reveal(n)) {
          anyMistake = true;
        }
        if (isFinished) break;
      }
    }
    return anyMistake;
  }

  /// Escribe [digit] en [cell].
  ///
  /// Devuelve `true` si contó un fallo (`digit != solution[cell]`).
  /// No pisa una casilla ya descubierta a menos que [sobrescribir] sea `true`
  /// (usado por la pista del modo práctica).
  bool place(int cell, int digit, {bool sobrescribir = false}) {
    if (isGiven(cell)) return false;
    if (isFinished && !sobrescribir) return false;
    if (digit < 1 || digit > 9) return false;
    if (entries[cell] == digit) return false;
    if (entries[cell] != 0 && !sobrescribir) return false;

    final move = _Move(
      entries: {cell: entries[cell]},
      notes: {cell: notes[cell]},
    );

    entries[cell] = digit;
    notes[cell] = 0;

    final bit = bitOf(digit);
    for (final p in _neighbors[cell]) {
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

  /// Borra lo escrito o la bandera en [cell]. No descuenta fallos.
  void erase(int cell) {
    if (isFinished || isGiven(cell)) return;
    if (entries[cell] == 0 && notes[cell] == 0) return;
    _undo.add(
      _Move(entries: {cell: entries[cell]}, notes: {cell: notes[cell]}),
    );
    entries[cell] = 0;
    notes[cell] = 0;
  }

  /// Pone o quita la marca/bandera [digit] en [cell]. Nunca cuenta como fallo.
  void toggleNote(int cell, int digit) {
    if (isFinished || isGiven(cell)) return;
    if (digit < 1 || digit > 9) return;
    if (entries[cell] != 0) return;
    _undo.add(_Move(entries: const {}, notes: {cell: notes[cell]}));
    notes[cell] ^= bitOf(digit);
  }

  bool hasNote(int cell, int digit) => notes[cell] & bitOf(digit) != 0;

  /// Deshace la última jugada sin descontar fallos.
  void undo() {
    if (isFinished || _undo.isEmpty) return;
    final move = _undo.removeLast();
    move.entries.forEach((cell, value) => entries[cell] = value);
    move.notes.forEach((cell, value) => notes[cell] = value);
  }

  Map<String, dynamic> toJson() => {
    'entries': encodeGrid(entries),
    'notes': notes.join(','),
    'mistakes': _mistakes,
  };

  /// Restaura una partida guardada.
  factory SudokuBoard.restore({
    required String givens,
    required String solution,
    required Map<String, dynamic> saved,
    int safeStart = -1,
    int maxStrikes = kDefaultMaxStrikes,
  }) {
    final board = SudokuBoard.fromStrings(
      givens: givens,
      solution: solution,
      safeStart: safeStart,
      maxStrikes: maxStrikes,
    );
    final total = board.boardCellCount;
    final rawEntries = saved['entries'] as String?;
    if (rawEntries != null && rawEntries.length == total) {
      final parsed = decodeGrid(rawEntries);
      for (var cell = 0; cell < total; cell++) {
        if (!board.isGiven(cell)) board.entries[cell] = parsed[cell];
      }
    }
    final rawNotes = saved['notes'] as String?;
    if (rawNotes != null) {
      final parts = rawNotes.split(',');
      if (parts.length == total) {
        for (var cell = 0; cell < total; cell++) {
          final v = int.tryParse(parts[cell]) ?? 0;
          if (!board.isGiven(cell)) board.notes[cell] = v & allDigitsMask;
        }
      }
    }
    board._mistakes = (saved['mistakes'] as num?)?.toInt() ?? 0;
    return board;
  }
}

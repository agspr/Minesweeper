/// Modo libre: puzles infinitos, dificultad a elección y **sin puntuar**.
///
/// Por qué aquí sí se genera en caliente y en la diaria no (diseño §2): en el
/// modo libre no hay nada que tenga que coincidir con nadie, así que la
/// determinación entre aparatos da igual y lo que sí importaría es quedarse sin
/// puzles. En la diaria es al revés, y por eso sale de un banco horneado.
///
/// Nada de esto puntúa (§1): ni puntos, ni racha, ni clasificación. Es
/// exactamente lo que permite que aquí haya **pistas** y en la diaria no —una
/// pista en un día puntuado obligaría a inventar una regla de puntuación que el
/// modelo cerrado no tiene.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:juegos_senda/juegos_senda.dart' show Analytics;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptics.dart';

import 'difficulty.dart';
import 'grid.dart';
import 'mine_generator.dart';
import 'sudoku_board.dart';

enum PracticeGameMode {
  senda,
  classic,
}

/// Genera en un isolate un tablero de Buscaminas resoluble sin adivinar.
Map<String, dynamic>? _generateInIsolate((int, int) args) {
  final (seed, difficultyIndex) = args;
  final puzzle = generateMinePuzzle(
    seed: seed,
    target: Difficulty.values[difficultyIndex],
  );
  if (puzzle == null) return null;
  return {
    'givens': puzzle.givens,
    'solution': puzzle.solution,
    'start': puzzle.start,
    'difficulty': puzzle.difficulty.name,
    'seed': puzzle.seed,
  };
}

class PracticeController extends ChangeNotifier {
  PracticeController(
    this._prefs, {
    int Function()? seedSource,
    DateTime Function()? clock,
  }) : _seedSource =
           seedSource ??
           (() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF),
       _clock = clock ?? DateTime.now;

  static const _kState = 'game.nona.practice';
  static const _kDifficulty = 'game.nona.practice.difficulty';
  static const _kStats = 'game.nona.practice.stats';
  static const _kMode = 'game.nona.practice.mode';

  final SharedPreferences _prefs;
  final int Function() _seedSource;
  final DateTime Function() _clock;

  /// Cronómetro del puzle en curso, con la misma mecánica que la diaria:
  /// segundos acumulados + desde cuándo corre. Se persiste en el estado del
  /// tablero para que cerrar la app a medias no regale un "mejor tiempo".
  int _accumulatedSeconds = 0;
  DateTime? _runningSince;

  /// ¿Este tablero ya contó como "jugada"? Cuenta al PRIMER toque, no al
  /// generarse: entrar en la pestaña genera tablero, y contar eso inflaría
  /// las jugadas con puzles que nadie llegó a mirar.
  bool _countedThisBoard = false;

  SudokuBoard? _board;
  Difficulty _difficulty = Difficulty.easy;
  PracticeGameMode _gameMode = PracticeGameMode.senda;
  bool _generating = false;
  int _selected = -1;
  bool _notesMode = false;

  /// Cuántas veces se tocó una cifra sobre un número ya puesto (ver
  /// `SudokuBoard.place`). Solo sube: la pantalla lo escucha para avisar de
  /// que hay que borrarlo primero.
  final ValueNotifier<int> intentosDeSobrescribir = ValueNotifier(0);

  /// Cuántas veces se tocó otra casilla antes de abrir la salida marcada (ver
  /// `SudokuBoard.faltaLaSalida`; solo en Senda, que es el modo que la marca).
  final ValueNotifier<int> avisosDeSalida = ValueNotifier(0);
  int _hintsUsed = 0;

  SudokuBoard? get board => _board;
  Difficulty get difficulty => _difficulty;
  PracticeGameMode get gameMode => _gameMode;
  bool get generating => _generating;
  int get selected => _selected;
  bool get notesMode => _notesMode;
  int get hintsUsed => _hintsUsed;
  bool get isComplete => _board?.isComplete ?? false;
  bool get isLost => _board?.isLost ?? false;
  bool get isFinished => _board?.isFinished ?? false;
  bool get isRunning => _runningSince != null && !isFinished;

  Duration get elapsed => Duration(
    seconds:
        _accumulatedSeconds +
        (_runningSince == null
            ? 0
            : _clock().difference(_runningSince!).inSeconds),
  );

  /// Las cifras de práctica de [d]: jugadas, completadas y mejor tiempo.
  ///
  /// Solo cuentan desde que existen (26-8-2026): los puzles anteriores no
  /// dejaron rastro y no se inventan — la regla de siempre, sin datos crudos
  /// no se escribe nada.
  PracticeLevelStats statsFor(Difficulty d) {
    final all = _readStats();
    final m = all[d.name];
    if (m is! Map) return const PracticeLevelStats();
    final best = (m['b'] as num?)?.toInt();
    return PracticeLevelStats(
      played: (m['j'] as num?)?.toInt() ?? 0,
      completed: (m['c'] as num?)?.toInt() ?? 0,
      bestSeconds: best,
    );
  }

  Map<String, dynamic> _readStats() {
    final raw = _prefs.getString(_kStats);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return {};
    }
  }

  void _bumpStats(void Function(Map<String, dynamic> nivel) update) {
    final all = _readStats();
    final nivel = ((all[_difficulty.name] as Map?) ?? <String, dynamic>{})
        .cast<String, dynamic>();
    update(nivel);
    all[_difficulty.name] = nivel;
    _prefs.setString(_kStats, jsonEncode(all));
  }

  /// El primer toque de un tablero: arranca el cronómetro y cuenta la jugada.
  void _touch() {
    _runningSince ??= _clock();
    if (_countedThisBoard) return;
    _countedThisBoard = true;
    _bumpStats((n) => n['j'] = ((n['j'] as num?)?.toInt() ?? 0) + 1);
  }

  /// El tablero acaba de completarse: cierra el cronómetro y apunta las
  /// cifras. Las pistas no lo invalidan — en práctica no penalizan nada, por
  /// decisión de André, y eso incluye estas cuentas.
  void _finished() {
    // Hermano del offline_terminada de CINCO. Mismo gate que diaria_terminada:
    // no sale en build hasta que §3.8 lo declare.
    Analytics.gameEvent('practica_terminada', {'dificultad': _difficulty.name});
    if (_runningSince != null) {
      _accumulatedSeconds += _clock().difference(_runningSince!).inSeconds;
      _runningSince = null;
    }
    final t = _accumulatedSeconds;
    _bumpStats((n) {
      n['c'] = ((n['c'] as num?)?.toInt() ?? 0) + 1;
      final best = (n['b'] as num?)?.toInt();
      // El mejor tiempo solo MEJORA. Con `t > 0` además: un tablero
      // restaurado de un guardado corrupto podría dar 0 segundos, y un
      // "mejor: 0:00" es mentira por construcción.
      if (t > 0 && (best == null || t < best)) n['b'] = t;
    });
  }

  /// Recupera el puzle a medias que hubiera, o genera uno nuevo.
  Future<void> load() async {
    final savedMode = _prefs.getString(_kMode);
    if (savedMode != null) {
      _gameMode = PracticeGameMode.values.firstWhere(
        (m) => m.name == savedMode,
        orElse: () => PracticeGameMode.senda,
      );
    }
    final savedDifficulty = _prefs.getString(_kDifficulty);
    if (savedDifficulty != null) {
      _difficulty = Difficulty.values.firstWhere(
        (d) => d.name == savedDifficulty,
        orElse: () => Difficulty.easy,
      );
    }
    final raw = _prefs.getString(_kState);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final strikes = _gameMode == PracticeGameMode.classic
            ? 1
            : SudokuBoard.kDefaultMaxStrikes;
        _board = SudokuBoard.restore(
          givens: data['givens'] as String,
          solution: data['solution'] as String,
          saved: data,
          safeStart: (data['start'] as num?)?.toInt() ?? -1,
          maxStrikes: strikes,
        );
        _hintsUsed = (data['hints'] as num?)?.toInt() ?? 0;
        _accumulatedSeconds = (data['seconds'] as num?)?.toInt() ?? 0;
        _runningSince = null;
        _countedThisBoard = data['counted'] == true;
        notifyListeners();
        return;
      } catch (_) {
        // Guardado corrupto: se genera uno limpio.
      }
    }
    await newPuzzle();
  }

  Future<void> setGameMode(PracticeGameMode mode) async {
    if (mode == _gameMode) return;
    _gameMode = mode;
    notifyListeners();
    await _prefs.setString(_kMode, mode.name);
    await newPuzzle();
  }

  Future<void> setDifficulty(Difficulty d) async {
    if (d == _difficulty) return;
    _difficulty = d;
    await _prefs.setString(_kDifficulty, d.name);
    await newPuzzle();
  }

  Future<void> newPuzzle() async {
    if (_generating) return;
    _generating = true;
    _selected = -1;
    _notesMode = false;
    _hintsUsed = 0;
    _accumulatedSeconds = 0;
    _runningSince = null;
    _countedThisBoard = false;
    notifyListeners();

    Map<String, dynamic>? json;
    for (var attempt = 0; attempt < 10 && json == null; attempt++) {
      json = await compute(_generateInIsolate, (
        _seedSource() + attempt * 7919,
        _difficulty.index,
      ));
    }

    if (json != null) {
      final sol = json['solution'] as String;
      final start = (json['start'] as num?)?.toInt() ?? -1;
      final emptyGivens = '.' * sol.length;
      final strikes = _gameMode == PracticeGameMode.classic
          ? 1
          : SudokuBoard.kDefaultMaxStrikes;
      _board = SudokuBoard.fromStrings(
        givens: emptyGivens,
        solution: sol,
        safeStart: _gameMode == PracticeGameMode.senda ? start : -1,
        maxStrikes: strikes,
      );
    }
    _generating = false;
    _save();
    notifyListeners();
  }

  void select(int cell) {
    final limit = _board?.boardCellCount ?? cellCount;
    if (cell < 0 || cell >= limit) return;
    if (cell == _selected) return;
    _selected = cell;
    NonaHaptics.select();
    notifyListeners();
  }

  /// Toque sobre una casilla del tablero en práctica:
  /// - Si la casilla ya está descubierta, comprueba si puede hacer acorde;
  ///   si no, la selecciona para visualizar sus vecinas.
  /// - Si la casilla está oculta:
  ///   - En modo Cavar: la descubre en el acto (1 toque).
  ///   - En modo Bandera: coloca o quita bandera en el acto (1 toque).
  void tapCellOnBoard(int cell) {
    final b = _board;
    if (b == null || isFinished) return;
    if (_soloLaSalida(b, cell)) return;

    if (b.isRevealed(cell)) {
      _selected = cell;
      if (b.canChord(cell)) {
        _touch();
        final fallo = b.chord(cell);
        if (fallo) {
          NonaHaptics.mistake();
        } else {
          NonaHaptics.tap();
        }
        if (b.isFinished) _finished();
        _save();
        notifyListeners();
      } else {
        NonaHaptics.select();
        notifyListeners();
      }
      return;
    }

    _selected = cell;
    if (_notesMode) {
      NonaHaptics.tap();
      flagSelected();
    } else {
      if (b.isFlagged(cell)) {
        NonaHaptics.select();
        notifyListeners();
        return;
      }
      NonaHaptics.tap();
      revealSelected();
    }
  }

  /// Pulsación larga sobre una casilla: alterna bandera directamente con respuesta háptica.
  void longPressCellOnBoard(int cell) {
    final b = _board;
    if (b == null || isFinished) return;
    if (_soloLaSalida(b, cell)) return;
    if (!b.isRevealed(cell)) {
      _selected = cell;
      NonaHaptics.select();
      flagSelected();
    }
  }

  /// Antes de abrir la salida marcada solo vale ella, como en la diaria
  /// (`DailyController._soloLaSalida`): tocarla la abre, tocar otra avisa.
  /// Devuelve `true` si el toque se quedó aquí.
  bool _soloLaSalida(SudokuBoard b, int cell) {
    if (!b.faltaLaSalida) return false;
    if (cell != b.safeStart) {
      NonaHaptics.select();
      avisosDeSalida.value++;
      return true;
    }
    _selected = cell;
    NonaHaptics.tap();
    revealSelected();
    return true;
  }

  /// Descubre la casilla seleccionada (o ejecuta acorde si procede).
  bool revealSelected() {
    final b = _board;
    if (b == null || _selected < 0 || isFinished) return false;
    if (b.faltaLaSalida && _selected != b.safeStart) return false;
    if (b.isRevealed(_selected)) {
      if (b.canChord(_selected)) {
        _touch();
        final fallo = b.chord(_selected);
        if (fallo) NonaHaptics.mistake();
        if (b.isFinished) _finished();
        _save();
        notifyListeners();
        return fallo;
      }
      return false;
    }
    if (b.isFlagged(_selected)) {
      return false;
    }
    if (b.isGiven(_selected)) return false;
    _touch();
    final fallo = b.reveal(_selected);
    if (fallo) NonaHaptics.mistake();
    if (b.isFinished) _finished();
    _save();
    notifyListeners();
    return fallo;
  }

  /// Alterna bandera sobre la casilla seleccionada.
  void flagSelected() {
    final b = _board;
    if (b == null || _selected < 0 || isFinished) return;
    if (b.isRevealed(_selected)) return;
    if (b.isGiven(_selected)) return;
    if (b.faltaLaSalida) return;
    _touch();
    b.toggleFlag(_selected);
    _save();
    notifyListeners();
  }

  bool get isFlagMode => _notesMode;
  bool get isDigMode => !_notesMode;

  void setFlagMode(bool flagMode) {
    if (_notesMode != flagMode) {
      toggleNotesMode();
    }
  }

  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  /// Devuelve si la cifra contó como FALLO.
  bool tapDigit(int digit) {
    final b = _board;
    if (b == null || _selected < 0 || isFinished) return false;
    if (b.ocupada(_selected) && (_notesMode || b.entries[_selected] != digit)) {
      intentosDeSobrescribir.value++;
      return false;
    }
    _touch();
    var fallo = false;
    if (_notesMode) {
      b.toggleNote(_selected, digit);
    } else {
      fallo = b.place(_selected, digit);
      if (fallo) NonaHaptics.mistake();
      if (b.isFinished) _finished();
    }
    _save();
    notifyListeners();
    return fallo;
  }

  void erase() {
    final b = _board;
    if (b == null || _selected < 0 || isFinished) return;
    _touch();
    b.erase(_selected);
    _save();
    notifyListeners();
  }

  void undo() {
    final b = _board;
    if (b == null || isFinished) return;
    _touch();
    b.undo();
    _save();
    notifyListeners();
  }

  /// Revela la primera casilla segura no resuelta.
  void hint() {
    final b = _board;
    if (b == null || isFinished) return;
    var cell = _selected;
    if (b.faltaLaSalida) {
      // La primera pista es la salida: abrir otra casilla primero (la primera
      // segura por orden de lectura) dejaría el tablero sin la garantía.
      cell = b.safeStart;
    } else if (cell < 0 || b.isRevealed(cell) || b.isMine(cell)) {
      cell = _firstUnsolvedSafe(b);
      if (cell < 0) return;
    }
    _touch();
    b.reveal(cell);
    if (b.isFinished) _finished();
    _selected = cell;
    _hintsUsed++;
    _save();
    notifyListeners();
  }

  @override
  void dispose() {
    intentosDeSobrescribir.dispose();
    avisosDeSalida.dispose();
    super.dispose();
  }

  int _firstUnsolvedSafe(SudokuBoard b) {
    for (var cell = 0; cell < b.boardCellCount; cell++) {
      if (!b.isMine(cell) && !b.isRevealed(cell)) return cell;
    }
    return -1;
  }

  void _save() {
    final b = _board;
    if (b == null) return;
    _prefs.setString(
      _kState,
      jsonEncode({
        'givens': encodeGrid(b.givens),
        'solution': encodeGrid(b.solution),
        ...b.toJson(),
        'hints': _hintsUsed,
        // El cronómetro se congela al guardar: los segundos con la app
        // cerrada no son juego, y contarlos regalaría un "mejor tiempo" malo
        // o robaría uno bueno.
        'seconds': elapsed.inSeconds,
        'counted': _countedThisBoard,
      }),
    );
    if (_runningSince != null) {
      _accumulatedSeconds += _clock().difference(_runningSince!).inSeconds;
      _runningSince = _clock();
    }
  }
}

/// Las cifras de práctica de un nivel. Ver [PracticeController.statsFor].
class PracticeLevelStats {
  const PracticeLevelStats({
    this.played = 0,
    this.completed = 0,
    this.bestSeconds,
  });

  final int played;
  final int completed;

  /// `null` mientras no se haya completado ninguno: no hay mejor tiempo que
  /// enseñar, y un cero sería mentira.
  final int? bestSeconds;
}

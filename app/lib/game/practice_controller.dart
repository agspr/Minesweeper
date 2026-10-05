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
import 'generator.dart';
import 'grid.dart';
import 'sudoku_board.dart';

/// Genera en un isolate. La generación es Dart puro, así que se puede sacar del
/// hilo de interfaz sin más: un difícil tarda unos milisegundos de media, pero
/// el peor caso puede irse a bastante más y ahí se notaría el tirón justo al
/// pulsar "otro puzle".
Map<String, dynamic>? _generateInIsolate((int, int) args) {
  final (seed, difficultyIndex) = args;
  final puzzle = generate(
    seed: seed,
    target: Difficulty.values[difficultyIndex],
  );
  return puzzle?.toJson();
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
  bool _generating = false;
  int _selected = -1;
  bool _notesMode = false;
  int _hintsUsed = 0;

  SudokuBoard? get board => _board;
  Difficulty get difficulty => _difficulty;
  bool get generating => _generating;
  int get selected => _selected;
  bool get notesMode => _notesMode;
  int get hintsUsed => _hintsUsed;
  bool get isComplete => _board?.isComplete ?? false;

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
        _board = SudokuBoard.restore(
          givens: data['givens'] as String,
          solution: data['solution'] as String,
          saved: data,
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
    // Se reintenta con semillas distintas: `generate` puede no converger al
    // grado pedido, y en ese caso devuelve null en vez de entregar otra cosa.
    for (var attempt = 0; attempt < 5 && json == null; attempt++) {
      json = await compute(_generateInIsolate, (
        _seedSource() + attempt,
        _difficulty.index,
      ));
    }

    if (json != null) {
      _board = SudokuBoard.fromStrings(
        givens: json['givens'] as String,
        solution: json['solution'] as String,
      );
    }
    _generating = false;
    _save();
    notifyListeners();
  }

  void select(int cell) {
    if (cell < 0 || cell >= cellCount) return;
    // Igual que en la diaria: re-tocar la seleccionada no mueve nada, así que
    // no repinta ni vibra. (El guardia de rango faltaba aquí.)
    if (cell == _selected) return;
    _selected = cell;
    NonaHaptics.select();
    notifyListeners();
  }

  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  /// Devuelve si la cifra contó como FALLO. El numpad lo necesita para no
  /// encabalgar su golpe con el patrón de error: la cifra entra al tocar la
  /// tecla, así que el veredicto ya no llega «después», al soltar.
  bool tapDigit(int digit) {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return false;
    _touch();
    var fallo = false;
    if (_notesMode) {
      b.toggleNote(_selected, digit);
    } else {
      // Un fallo se siente, no solo se ve: ver NonaHaptics.mistake.
      fallo = b.place(_selected, digit);
      if (fallo) NonaHaptics.mistake();
      if (b.isComplete) _finished();
    }
    _save();
    notifyListeners();
    return fallo;
  }

  void erase() {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return;
    _touch();
    b.erase(_selected);
    _save();
    notifyListeners();
  }

  void undo() {
    final b = _board;
    if (b == null || isComplete) return;
    _touch();
    b.undo();
    _save();
    notifyListeners();
  }

  /// Revela la casilla seleccionada (o la primera vacía si no hay ninguna).
  ///
  /// Solo existe en el modo libre, por decisión de André: aquí no hay puntos
  /// que falsear. Se cuenta el número de pistas para poder mostrarlo, no para
  /// penalizar nada.
  void hint() {
    final b = _board;
    if (b == null || isComplete) return;
    var cell = _selected;
    if (cell < 0 || b.isGiven(cell) || b.entries[cell] == b.solution[cell]) {
      cell = _firstUnsolved(b);
      if (cell < 0) return;
    }
    // Se coloca el dígito correcto, así que nunca cuenta como fallo.
    _touch();
    b.place(cell, b.solution[cell]);
    if (b.isComplete) _finished();
    _selected = cell;
    _hintsUsed++;
    _save();
    notifyListeners();
  }

  int _firstUnsolved(SudokuBoard b) {
    for (var cell = 0; cell < cellCount; cell++) {
      if (!b.isGiven(cell) && b.entries[cell] != b.solution[cell]) return cell;
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

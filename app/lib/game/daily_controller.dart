/// La partida diaria: carga el puzle del banco, guarda el estado y lleva el
/// reloj.
///
/// Es **imposible de perder** (diseño §1): no hay límite de fallos ni pantalla
/// de derrota, así que aquí no existe ningún estado "perdido". Los fallos solo
/// bajan la puntuación, y la racha solo pide terminar.
///
/// El reloj se muestra para quien quiera picarse consigo mismo y **no puntúa**
/// (§1). Por eso no lleva ninguna defensa contra trampas: adelantar el reloj no
/// da nada. Se para al irse la app al fondo, para que mida tiempo de juego real
/// y no tiempo de calendario.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/haptics.dart';

import 'daily_bank.dart';
import 'day_key.dart';
import 'difficulty.dart';
import 'sudoku_board.dart';

/// Lo que la partida entrega a la puntuación (N4) cuando el día se cierra.
///
/// Deliberadamente tonto: solo datos. La tabla de puntos vive en `scoring.dart`
/// y este objeto es la costura, para que cambiar la puntuación no obligue a
/// tocar la partida ni al contrario.
class DailyOutcome {
  const DailyOutcome({
    required this.dayKey,
    required this.difficulty,
    required this.completed,
    required this.mistakes,
    required this.completionPercent,
    required this.seconds,
  });

  final String dayKey;
  final Difficulty difficulty;

  /// Terminado del todo. Es lo ÚNICO que da racha (§1).
  final bool completed;

  final int mistakes;
  final int completionPercent;
  final int seconds;
}

class DailyController extends ChangeNotifier {
  DailyController(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  // Prefijo 'game.' a propósito: es lo que SessionSync borra al cambiar de
  // cuenta en el aparato, para que la partida de una persona no se le atribuya
  // a otra.
  static const _kState = 'game.nona.today';

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  SudokuBoard? _board;
  String? _dayKey;
  Difficulty? _difficulty;
  bool _ready = false;
  Object? _loadError;

  int _selected = -1;
  bool _notesMode = false;

  int _accumulatedSeconds = 0;
  DateTime? _runningSince;

  SudokuBoard? get board => _board;
  String? get dayKey => _dayKey;
  Difficulty? get difficulty => _difficulty;

  /// `true` cuando el puzle del día está cargado y se puede jugar.
  bool get ready => _ready;

  /// El día pedido no estaba en el banco (horizonte agotado, reloj en otra era).
  Object? get loadError => _loadError;

  int get selected => _selected;
  bool get notesMode => _notesMode;
  bool get isComplete => _board?.isComplete ?? false;

  Duration get elapsed => Duration(
    seconds:
        _accumulatedSeconds +
        (_runningSince == null
            ? 0
            : _clock().difference(_runningSince!).inSeconds),
  );

  /// Carga el puzle de hoy. Idempotente por día.
  Future<void> load() async {
    final today = dayKeyFor(_clock());
    if (_ready && _dayKey == today) return;
    _ready = false;
    _loadError = null;
    notifyListeners();
    try {
      final puzzle = await DailyBank.forDayKey(today, _clock().year);
      _dayKey = today;
      _difficulty = puzzle.difficulty;
      final saved = _readSaved(today);
      _board = saved == null
          ? SudokuBoard.fromStrings(
              givens: puzzle.givens,
              solution: puzzle.solution,
            )
          : SudokuBoard.restore(
              givens: puzzle.givens,
              solution: puzzle.solution,
              saved: saved,
            );
      _accumulatedSeconds = (saved?['seconds'] as num?)?.toInt() ?? 0;
      _runningSince = null;
      _selected = -1;
      _notesMode = false;
      _ready = true;
    } catch (e) {
      _loadError = e;
      _board = null;
    }
    notifyListeners();
  }

  /// Relee el día del reloj y recarga si ya cambió.
  ///
  /// Se llama al volver la app a primer plano. Un proceso móvil sobrevive a
  /// medianoche durante días sin problema, y sin esto seguiría mostrando el
  /// puzle de ayer y guardaría el resultado en la fecha equivocada. Mismo
  /// patrón que `refreshForToday` en CINCO, donde arregló justo ese fallo.
  Future<bool> refreshForToday() async {
    final today = dayKeyFor(_clock());
    if (today == _dayKey) return false;
    pauseTimer();
    await load();
    return true;
  }

  // ── Reloj ────────────────────────────────────────────────

  void startTimer() {
    if (_runningSince != null || isComplete) return;
    _runningSince = _clock();
  }

  void pauseTimer() {
    if (_runningSince == null) return;
    _accumulatedSeconds += _clock().difference(_runningSince!).inSeconds;
    _runningSince = null;
    _save();
  }

  // ── Entrada ──────────────────────────────────────────────

  void select(int cell) {
    if (cell < 0 || cell >= 81) return;
    _selected = cell;
    notifyListeners();
  }

  void toggleNotesMode() {
    _notesMode = !_notesMode;
    notifyListeners();
  }

  /// Pulsa un dígito del numpad sobre la casilla seleccionada.
  void tapDigit(int digit) {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return;
    if (_notesMode) {
      b.toggleNote(_selected, digit);
    } else {
      // Un fallo se siente, no solo se ve: ver NonaHaptics.mistake.
      if (b.place(_selected, digit)) NonaHaptics.mistake();
      // Terminar para el reloj: la partida ya está cerrada.
      if (b.isComplete) pauseTimer();
    }
    _save();
    notifyListeners();
  }

  void erase() {
    final b = _board;
    if (b == null || _selected < 0 || isComplete) return;
    b.erase(_selected);
    _save();
    notifyListeners();
  }

  void undo() {
    final b = _board;
    if (b == null || isComplete) return;
    b.undo();
    _save();
    notifyListeners();
  }

  /// El resultado de hoy tal y como está ahora mismo.
  ///
  /// Sirve tanto al terminar (crédito completo) como al abandonar a medias
  /// (crédito parcial): la puntuación decide, esto solo informa.
  DailyOutcome? get outcome {
    final b = _board;
    if (b == null || _dayKey == null || _difficulty == null) return null;
    return DailyOutcome(
      dayKey: _dayKey!,
      difficulty: _difficulty!,
      completed: b.isComplete,
      mistakes: b.mistakes,
      completionPercent: b.completionPercent,
      seconds: elapsed.inSeconds,
    );
  }

  // ── Persistencia ─────────────────────────────────────────

  Map<String, dynamic>? _readSaved(String today) {
    final raw = _prefs.getString(_kState);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // Guardado de otro día: no sirve, y devolverlo pondría las entradas de
      // ayer en el tablero de hoy.
      if (data['day'] != today) return null;
      return data;
    } catch (_) {
      return null; // Corrupto: se empieza limpio.
    }
  }

  void _save() {
    final b = _board;
    if (b == null || _dayKey == null) return;
    unawaited(
      _prefs.setString(
        _kState,
        jsonEncode({
          'day': _dayKey,
          ...b.toJson(),
          'seconds': elapsed.inSeconds,
        }),
      ),
    );
  }

  /// Vuelve a leer las prefs para el día actual. Se llama tras un cambio de
  /// cuenta, cuando SessionSync ya ha limpiado el estado del dueño anterior.
  Future<void> reloadFromPrefs() async {
    _ready = false;
    _dayKey = null;
    await load();
  }

  @override
  void dispose() {
    pauseTimer();
    super.dispose();
  }
}

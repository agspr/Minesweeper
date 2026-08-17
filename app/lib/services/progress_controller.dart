/// Racha, puntos y registro de los días jugados. Todo local, por ahora.
///
/// Cuando el paquete `juegos_senda` traiga la capa de identidad, esto se apoya
/// en su `ProgressStore` para replicar en la nube. Hasta entonces vive en el
/// dispositivo, y eso no es un apaño: la diaria tiene que poder jugarse sin red
/// y sin cuenta, así que lo local es la fuente de verdad y la nube será una
/// réplica, nunca al revés.
///
/// Dos propiedades que el diseño exige y que aquí se hacen cumplir:
/// - **Registrar un día es idempotente.** Volver a la pantalla, reiniciar la
///   app o recuperar la partida no puede sumar dos veces los mismos puntos.
/// - **La racha solo la extiende TERMINAR** (§1). El crédito parcial suma
///   puntos y no toca la racha: si la tocara, una casilla al día mantendría una
///   racha infinita.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/day_key.dart';
import '../game/difficulty.dart';
import '../game/scoring.dart';

/// Lo que quedó registrado de un día concreto.
class DayRecord {
  const DayRecord({
    required this.dayKey,
    required this.points,
    required this.completed,
    required this.mistakes,
    required this.completionPercent,
    required this.difficulty,
    required this.seconds,
  });

  final String dayKey;
  final int points;
  final bool completed;
  final int mistakes;
  final int completionPercent;
  final Difficulty difficulty;
  final int seconds;

  Map<String, dynamic> toJson() => {
    'points': points,
    'completed': completed,
    'mistakes': mistakes,
    'percent': completionPercent,
    'difficulty': difficulty.name,
    'seconds': seconds,
  };

  factory DayRecord.fromJson(String dayKey, Map<String, dynamic> j) => DayRecord(
    dayKey: dayKey,
    points: (j['points'] as num?)?.toInt() ?? 0,
    completed: j['completed'] as bool? ?? false,
    mistakes: (j['mistakes'] as num?)?.toInt() ?? 0,
    completionPercent: (j['percent'] as num?)?.toInt() ?? 0,
    difficulty: Difficulty.values.firstWhere(
      (d) => d.name == j['difficulty'],
      orElse: () => Difficulty.easy,
    ),
    seconds: (j['seconds'] as num?)?.toInt() ?? 0,
  );
}

class ProgressController extends ChangeNotifier {
  ProgressController(this._prefs);

  // Prefijo 'progress.' para que SessionSync lo limpie al cambiar de cuenta.
  static const _kStreak = 'progress.streak';
  static const _kBest = 'progress.bestStreak';
  static const _kPoints = 'progress.totalPoints';
  static const _kLastDay = 'progress.lastPlayedDay';
  static String _kRecord(String day) => 'progress.day.$day';

  final SharedPreferences _prefs;

  int get streak => _prefs.getInt(_kStreak) ?? 0;
  int get bestStreak => _prefs.getInt(_kBest) ?? 0;
  int get totalPoints => _prefs.getInt(_kPoints) ?? 0;
  String? get lastCompletedDay => _prefs.getString(_kLastDay);

  /// Racha vigente a día de hoy.
  ///
  /// Distinta de [streak] a propósito: el contador guardado no sabe que el
  /// tiempo pasa. Si el último día terminado no es ni hoy ni ayer, la racha ya
  /// está rota aunque nadie haya abierto la app para enterarse — y hay que
  /// enseñarla rota, no inflada.
  int streakAsOf(DateTime now) {
    final last = lastCompletedDay;
    if (last == null) return 0;
    final lastDate = DateTime.tryParse(last);
    if (lastDate == null) return 0;
    return calendarDaysBetween(lastDate, now) <= 1 ? streak : 0;
  }

  DayRecord? recordFor(String dayKey) {
    final raw = _prefs.getString(_kRecord(dayKey));
    if (raw == null) return null;
    try {
      return DayRecord.fromJson(
        dayKey,
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Todos los días registrados, del más reciente al más antiguo.
  List<DayRecord> get allRecords {
    final out = <DayRecord>[];
    for (final key in _prefs.getKeys()) {
      if (!key.startsWith('progress.day.')) continue;
      final day = key.substring('progress.day.'.length);
      final record = recordFor(day);
      if (record != null) out.add(record);
    }
    out.sort((a, b) => b.dayKey.compareTo(a.dayKey));
    return out;
  }

  /// Registra el resultado del día.
  ///
  /// **Idempotente por día**: si ese día ya estaba registrado, devuelve lo
  /// guardado sin volver a sumar. Sin esto, cerrar y abrir la app tras
  /// terminar duplicaría los puntos, que es justo lo que pasa en cuanto una
  /// pantalla se reconstruye sola.
  ///
  /// La excepción deliberada: un día que se registró SIN terminar puede
  /// mejorarse si luego se termina. Es lo que permite dejarlo a medias, volver
  /// más tarde y llevarse el crédito completo y la racha. En ese caso se
  /// ajusta la diferencia de puntos, nunca se suma otra vez el total.
  DayRecord record(DailyScore score, DateTime date, {int seconds = 0}) {
    final dayKey = dayKeyFor(date);
    final previous = recordFor(dayKey);

    if (previous != null && (previous.completed || !score.completed)) {
      // Ya registrado y sin mejora que aplicar.
      return previous;
    }

    final record = DayRecord(
      dayKey: dayKey,
      points: score.points,
      completed: score.completed,
      mistakes: score.countedMistakes,
      completionPercent: score.completionPercent,
      difficulty: switch (score.base) {
        50 => Difficulty.easy,
        100 => Difficulty.medium,
        _ => Difficulty.hard,
      },
      seconds: seconds,
    );

    // Solo la DIFERENCIA: si el día ya había dado 20 puntos de crédito parcial
    // y ahora termina con 100, se suman 80, no 100.
    final delta = score.points - (previous?.points ?? 0);
    _prefs.setInt(_kPoints, totalPoints + delta);
    _prefs.setString(_kRecord(dayKey), jsonEncode(record.toJson()));

    if (score.completed) _extendStreak(date);

    notifyListeners();
    return record;
  }

  /// Extiende la racha. Solo lo llama un día TERMINADO.
  void _extendStreak(DateTime date) {
    final last = DateTime.tryParse(lastCompletedDay ?? '');
    // Días de calendario, no horas: en el cambio de primavera un día dura 23 h
    // y restar `DateTime`s daría 0, rompiendo rachas sin motivo. Es el mismo
    // fallo que CINCO ya corrigió.
    final continues = last != null && calendarDaysBetween(last, date) == 1;
    final alreadyToday = last != null && calendarDaysBetween(last, date) == 0;
    if (alreadyToday) return;

    final next = continues ? streak + 1 : 1;
    _prefs.setInt(_kStreak, next);
    if (next > bestStreak) _prefs.setInt(_kBest, next);
    _prefs.setString(_kLastDay, dayKeyFor(date));
  }

  // ── Estadísticas ─────────────────────────────────────────

  int get daysPlayed => allRecords.length;
  int get daysCompleted => allRecords.where((r) => r.completed).length;

  /// Media de fallos de los días TERMINADOS. `null` sin ninguno.
  ///
  /// Solo los terminados: mezclar los abandonados a medias daría una media
  /// engañosamente buena, porque quien deja el puzle a los dos minutos apenas
  /// tuvo ocasión de fallar.
  double? get averageMistakes {
    final done = allRecords.where((r) => r.completed).toList();
    if (done.isEmpty) return null;
    return done.fold<int>(0, (a, r) => a + r.mistakes) / done.length;
  }

  /// Mejor tiempo de un día terminado, por dificultad.
  Duration? bestTimeFor(Difficulty d) {
    final times = allRecords
        .where((r) => r.completed && r.difficulty == d && r.seconds > 0)
        .map((r) => r.seconds)
        .toList();
    if (times.isEmpty) return null;
    return Duration(seconds: times.reduce((a, b) => a < b ? a : b));
  }

  int completedOf(Difficulty d) =>
      allRecords.where((r) => r.completed && r.difficulty == d).length;
}

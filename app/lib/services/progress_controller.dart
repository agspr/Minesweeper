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
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:juegos_senda/juegos_senda.dart';
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
    this.lost = false,
    required this.mistakes,
    required this.completionPercent,
    required this.difficulty,
    required this.seconds,
  });

  final String dayKey;
  final int points;
  final bool completed;
  final bool lost;
  final int mistakes;
  final int completionPercent;
  final Difficulty difficulty;
  final int seconds;

  /// ¿Se jugó hasta su conclusión (victoria o derrota)?
  bool get finished => completed || lost;

  Map<String, dynamic> toJson() => {
    'points': points,
    'completed': completed,
    if (lost) 'lost': true,
    'mistakes': mistakes,
    'percent': completionPercent,
    'difficulty': difficulty.name,
    'seconds': seconds,
  };

  factory DayRecord.fromJson(String dayKey, Map<String, dynamic> j) =>
      DayRecord(
        dayKey: dayKey,
        points: (j['points'] as num?)?.toInt() ?? 0,
        completed: j['completed'] as bool? ?? false,
        lost: j['lost'] as bool? ?? false,
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

  // El SUELO adoptado de la nube. No son puntos que se sumen a nada: son lo
  // que la nube decía de esta semana y de este mes cuando se adoptó, y sirven
  // para no publicar un cero después de reinstalar. Ver [adoptCloud].
  static const _kBaseWeekId = 'progress.base.weekId';
  static const _kBaseWeek = 'progress.base.weekPoints';
  static const _kBaseMonthId = 'progress.base.monthId';
  static const _kBaseMonth = 'progress.base.monthPoints';

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

  /// El progreso en la forma que entiende el paquete (clasificación y nube).
  ///
  /// Los puntos de semana y mes se SUMAN aquí a partir de los días guardados,
  /// no se llevan en un contador aparte: un contador habría que reiniciarlo al
  /// cambiar de semana, y quien no abriera la app ese día arrastraría los
  /// puntos de la anterior. Sumando, el periodo se define solo.
  ProgressSummary summaryAsOf(DateTime now) {
    final week = weekIdFor(now);
    final month = monthIdFor(now);
    var weekPoints = 0;
    var monthPoints = 0;
    for (final r in allRecords) {
      final day = DateTime.tryParse(r.dayKey);
      if (day == null) continue;
      if (weekIdFor(day) == week) weekPoints += r.points;
      if (monthIdFor(day) == month) monthPoints += r.points;
    }
    // El suelo adoptado manda mientras siga siendo de ESTE periodo, y se
    // combina con MÁXIMO, no sumando: sumar contaría dos veces un día que ya
    // estuviera en los dos lados, y en el marcador de amigos eso es mentir
    // hacia arriba. El máximo nunca baja y nunca infla.
    if (_prefs.getString(_kBaseWeekId) == week) {
      weekPoints = max(weekPoints, _prefs.getInt(_kBaseWeek) ?? 0);
    }
    if (_prefs.getString(_kBaseMonthId) == month) {
      monthPoints = max(monthPoints, _prefs.getInt(_kBaseMonth) ?? 0);
    }

    return ProgressSummary(
      streak: streakAsOf(now),
      bestStreak: bestStreak,
      totalPoints: totalPoints,
      weekPoints: weekPoints,
      weekId: week,
      monthPoints: monthPoints,
      monthId: month,
      lastPlayedDay: lastCompletedDay,
    );
  }

  /// Trae de la nube un progreso MAYOR que el de este teléfono.
  ///
  /// El caso real: alguien reinstala Nona, o entra en un teléfono nuevo. Sus
  /// preferencias están vacías, así que sin esto la app publicaría un resumen
  /// a cero encima del bueno y le borraría la racha y los puntos a quien
  /// llevaba meses jugando. El fallo no se ve nunca en desarrollo.
  ///
  /// **Solo adopta si la nube va por delante en puntos totales**, y devuelve
  /// si lo hizo. Al revés —local por delante— no se toca nada y el
  /// sincronizador sube lo de aquí: quien acaba de jugar sin cobertura tiene
  /// razón frente a un documento viejo.
  ///
  /// La mejor racha se queda con el máximo aunque el resto se adopte entero:
  /// es un récord histórico y no debería bajar por una reconciliación.
  ///
  /// Los DÍAS no viajan en este corte (solo el resumen, que es lo que lee el
  /// marcador), así que la semana y el mes adoptados se guardan como suelo y
  /// [summaryAsOf] los combina con lo que haya en los registros locales.
  bool adoptCloud(ProgressSummary cloud) {
    if (cloud.totalPoints <= totalPoints) return false;

    _prefs.setInt(_kStreak, cloud.streak);
    _prefs.setInt(_kBest, max(bestStreak, cloud.bestStreak));
    _prefs.setInt(_kPoints, cloud.totalPoints);
    final last = cloud.lastPlayedDay;
    if (last != null) _prefs.setString(_kLastDay, last);

    // El id del periodo viaja con sus puntos: sin él, los puntos de la semana
    // pasada se leerían como los de esta hasta que esa persona volviera a
    // jugar.
    if (cloud.weekId != null) {
      _prefs.setString(_kBaseWeekId, cloud.weekId!);
      _prefs.setInt(_kBaseWeek, cloud.weekPoints);
    }
    if (cloud.monthId != null) {
      _prefs.setString(_kBaseMonthId, cloud.monthId!);
      _prefs.setInt(_kBaseMonth, cloud.monthPoints);
    }

    notifyListeners();
    return true;
  }

  /// Qué días de ESTA semana se completaron, de lunes a domingo.
  ///
  /// Siete booleanos, uno por día. **No es la racha**: con una racha de 13 días
  /// y hoy miércoles, esto devuelve tres verdaderos y cuatro falsos, no siete
  /// verdaderos. La racha la dice el número; esto dice la semana.
  ///
  /// Solo cuenta lo TERMINADO, igual que la racha: un día a medias da puntos
  /// pero no llena su casilla, o la fila prometería una racha que no existe.
  List<bool> weekDoneAsOf(DateTime now) {
    final lunes = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    return [
      for (var i = 0; i < 7; i++)
        recordFor(dayKeyFor(lunes.add(Duration(days: i))))?.finished ?? false,
    ];
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

    if (previous != null && (previous.finished || !score.extendsStreak)) {
      // Ya registrado y sin mejora que aplicar.
      return previous;
    }

    final record = DayRecord(
      dayKey: dayKey,
      points: score.points,
      completed: score.completed,
      lost: score.lost,
      mistakes: score.countedMistakes,
      completionPercent: score.completionPercent,
      difficulty: switch (score.base) {
        50 => Difficulty.easy,
        100 => Difficulty.medium,
        _ => Difficulty.hard,
      },
      seconds: seconds,
    );

    // **La nube ya lo tiene TERMINADO, y este teléfono no lo sabía.** Pasa al
    // volver a tu cuenta el mismo día tras entrar con otra: el cambio de cuenta
    // borró los registros locales, `adoptCloud` trajo `lastPlayedDay` = hoy, y
    // la diaria sale sin tablero. Sin esta guardia, repetirla sumaba sus puntos
    // encima de los adoptados —contados dos veces— y la subida pisaba con
    // `set()` el día de la nube; si la repetición salía peor, el servidor
    // congelaba el resumen y la diferencia se perdía para siempre (lo midió la
    // revisión del 12-9-2026: 500 → 455).
    //
    // «Marca de hoy sin registro de hoy» solo puede venir de la nube: aquí la
    // marca se escribe siempre junto a su registro (`_extendStreak`, abajo).
    //
    // **Depende de algo que conviene saber.** En el servidor, `lastPlayedDay`
    // es el último día con CUALQUIER documento, también a medias
    // (backend/functions/recompute.js). Esta guardia es correcta porque Nona
    // solo sube días terminados: el único llamador de `record` es la pantalla
    // de juego, detrás de `isComplete`. Si algún día se suben partidas a
    // medias, esto impediría terminar una empezada en otra sesión de la misma
    // cuenta, y hay que revisarlo.
    if (previous == null && lastCompletedDay == dayKey) return record;

    // Solo la DIFERENCIA: si el día ya había dado 20 puntos de crédito parcial
    // y ahora termina con 100, se suman 80, no 100.
    final delta = score.points - (previous?.points ?? 0);
    _prefs.setInt(_kPoints, totalPoints + delta);
    _prefs.setString(_kRecord(dayKey), jsonEncode(record.toJson()));

    if (score.extendsStreak) _extendStreak(date);

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

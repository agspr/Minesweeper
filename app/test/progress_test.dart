import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  DailyScore finished(Difficulty d, {int mistakes = 0}) => scoreDaily(
    DailyOutcome(
      dayKey: 'x',
      difficulty: d,
      completed: true,
      mistakes: mistakes,
      completionPercent: 100,
      seconds: 0,
    ),
  );

  DailyScore partial(Difficulty d, int percent) => scoreDaily(
    DailyOutcome(
      dayKey: 'x',
      difficulty: d,
      completed: false,
      mistakes: 0,
      completionPercent: percent,
      seconds: 0,
    ),
  );

  group('registro idempotente', () {
    test('el mismo día no suma dos veces', () {
      // El caso real: se termina, la pantalla se reconstruye y se vuelve a
      // registrar. Sin idempotencia, los puntos se duplican solos.
      final p = ProgressController(prefs);
      final day = DateTime(2026, 8, 17);
      p.record(finished(Difficulty.medium), day);
      expect(p.totalPoints, 100);
      p.record(finished(Difficulty.medium), day);
      p.record(finished(Difficulty.medium), day);
      expect(p.totalPoints, 100);
      expect(p.streak, 1);
    });

    test('terminar un día que quedó a medias suma solo la diferencia', () {
      final p = ProgressController(prefs);
      final day = DateTime(2026, 8, 17);
      p.record(partial(Difficulty.medium, 60), day); // 30 puntos
      expect(p.totalPoints, 30);
      expect(p.streak, 0, reason: 'un parcial no da racha');

      p.record(finished(Difficulty.medium), day); // pasa a valer 100
      expect(p.totalPoints, 100, reason: 'debe sumar 70, no 100 otra vez');
      expect(p.streak, 1, reason: 'ahora sí, porque lo terminó');
    });

    test('un día terminado no empeora si luego se registra un parcial', () {
      final p = ProgressController(prefs);
      final day = DateTime(2026, 8, 17);
      p.record(finished(Difficulty.hard), day);
      p.record(partial(Difficulty.hard, 30), day);
      expect(p.totalPoints, 150);
      expect(p.recordFor('2026-08-17')!.completed, isTrue);
    });
  });

  group('racha', () {
    test('días seguidos la extienden', () {
      final p = ProgressController(prefs);
      for (var i = 0; i < 5; i++) {
        p.record(finished(Difficulty.easy), DateTime(2026, 8, 10 + i));
      }
      expect(p.streak, 5);
      expect(p.bestStreak, 5);
    });

    test('saltarse un día la reinicia, pero el récord se conserva', () {
      final p = ProgressController(prefs);
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 10));
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 11));
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 12));
      expect(p.streak, 3);
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 14)); // falta el 13
      expect(p.streak, 1);
      expect(p.bestStreak, 3);
    });

    test('SOLO la extiende terminar (§1)', () {
      // Es la regla que impide que una casilla al día sostenga una racha
      // infinita.
      final p = ProgressController(prefs);
      p.record(partial(Difficulty.hard, 99), DateTime(2026, 8, 10));
      expect(p.streak, 0);
      expect(p.totalPoints, 60, reason: 'puntúa igual, pero sin racha');
    });

    test('se muestra rota si el último día no es ni hoy ni ayer', () {
      // El contador guardado no sabe que el tiempo pasa; hay que enseñarla
      // rota, no inflada.
      final p = ProgressController(prefs);
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 10));
      expect(p.streakAsOf(DateTime(2026, 8, 10)), 1);
      expect(p.streakAsOf(DateTime(2026, 8, 11)), 1, reason: 'ayer aún cuenta');
      expect(p.streakAsOf(DateTime(2026, 8, 12)), 0, reason: 'ya está rota');
    });

    test('sobrevive al cambio de horario de verano', () {
      // El día del cambio dura 23 h: restar DateTime daría 0 días y la racha se
      // rompería sola. Es el fallo que CINCO ya corrigió y que aquí no puede
      // reaparecer.
      final p = ProgressController(prefs);
      p.record(finished(Difficulty.easy), DateTime(2026, 3, 28, 23));
      p.record(finished(Difficulty.easy), DateTime(2026, 3, 29, 23));
      expect(p.streak, 2);
    });
  });

  group('estadísticas', () {
    test('cuenta jugados y terminados por separado', () {
      final p = ProgressController(prefs);
      p.record(finished(Difficulty.easy), DateTime(2026, 8, 10));
      p.record(partial(Difficulty.medium, 40), DateTime(2026, 8, 11));
      p.record(finished(Difficulty.hard), DateTime(2026, 8, 12));
      expect(p.daysPlayed, 3);
      expect(p.daysCompleted, 2);
      expect(p.completedOf(Difficulty.hard), 1);
      expect(p.completedOf(Difficulty.medium), 0);
    });

    test('la media de fallos ignora los días sin terminar', () {
      // Mezclarlos daría una media engañosamente buena: quien abandona a los
      // dos minutos apenas tuvo ocasión de fallar.
      final p = ProgressController(prefs);
      p.record(finished(Difficulty.easy, mistakes: 4), DateTime(2026, 8, 10));
      p.record(finished(Difficulty.easy, mistakes: 2), DateTime(2026, 8, 11));
      p.record(partial(Difficulty.easy, 10), DateTime(2026, 8, 12));
      expect(p.averageMistakes, 3.0);
    });

    test('sin días terminados no hay media', () {
      expect(ProgressController(prefs).averageMistakes, isNull);
    });
  });

  test('el progreso sobrevive a cerrar la app', () {
    final p1 = ProgressController(prefs);
    p1.record(finished(Difficulty.medium), DateTime(2026, 8, 17));
    final p2 = ProgressController(prefs);
    expect(p2.totalPoints, 100);
    expect(p2.streak, 1);
    expect(p2.recordFor('2026-08-17'), isNotNull);
  });
}

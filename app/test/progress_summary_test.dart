import 'package:flutter_test/flutter_test.dart';
import 'package:juegos_senda/juegos_senda.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/day_key.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/services/progress_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El resumen que sube a la nube y que leen los amigos.
///
/// Es la ÚNICA cara pública del progreso: lo que aquí salga mal, otra persona
/// lo ve como una puntuación falsa en la clasificación. Y los dos errores
/// posibles son de signo contrario y los dos graves — inflar los puntos de la
/// semana con los de la semana pasada, o publicar un cero encima del progreso
/// bueno de quien acaba de reinstalar.
void main() {
  late SharedPreferences prefs;
  late ProgressController progress;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    progress = ProgressController(prefs);
  });

  /// Un día terminado con una puntuación cualquiera pero conocida.
  void jugar(DateTime day) {
    progress.record(
      scoreDaily(
        DailyOutcome(
          dayKey: dayKeyFor(day),
          difficulty: Difficulty.easy,
          completed: true,
          mistakes: 0,
          completionPercent: 100,
          seconds: 0,
        ),
      ),
      day,
    );
  }

  group('los puntos del periodo', () {
    test('la semana solo cuenta los días de ESTA semana', () {
      // Lunes 17 y martes 18 de agosto de 2026 son la misma semana; el 10 es
      // la anterior. Sin el corte, el marcador semanal arrastraría los puntos
      // viejos hasta que esa persona volviera a jugar.
      jugar(DateTime(2026, 8, 10));
      jugar(DateTime(2026, 8, 17));
      jugar(DateTime(2026, 8, 18));

      final s = progress.summaryAsOf(DateTime(2026, 8, 18, 10));
      final unDia = progress.recordFor('2026-08-17')!.points;

      expect(s.weekPoints, unDia * 2);
      expect(s.totalPoints, unDia * 3);
      expect(s.weekId, weekIdFor(DateTime(2026, 8, 18)));
    });

    test('el mes suma los días del mes, aunque sean de otra semana', () {
      jugar(DateTime(2026, 8, 3));
      jugar(DateTime(2026, 8, 18));
      jugar(DateTime(2026, 7, 30));

      final s = progress.summaryAsOf(DateTime(2026, 8, 18, 10));
      final unDia = progress.recordFor('2026-08-03')!.points;

      expect(s.monthPoints, unDia * 2);
      expect(s.monthId, monthIdFor(DateTime(2026, 8, 18)));
    });

    test('sin nada jugado, todo a cero pero con los ids del periodo', () {
      final s = progress.summaryAsOf(DateTime(2026, 8, 18, 10));
      expect(s.totalPoints, 0);
      expect(s.weekPoints, 0);
      // Los ids van igualmente: el cero tiene que ser "cero ESTA semana", no
      // un cero sin fecha que se leería como de cualquier semana.
      expect(s.weekId, isNotNull);
      expect(s.monthId, isNotNull);
    });
  });

  group('adoptar lo que hay en la nube', () {
    ProgressSummary nube({int total = 500, int streak = 7}) => ProgressSummary(
      streak: streak,
      bestStreak: 9,
      totalPoints: total,
      weekPoints: 120,
      weekId: weekIdFor(DateTime(2026, 8, 18)),
      monthPoints: 300,
      monthId: monthIdFor(DateTime(2026, 8, 18)),
      lastPlayedDay: '2026-08-18',
    );

    test('un teléfono recién instalado se trae el progreso de la cuenta', () {
      expect(progress.adoptCloud(nube()), isTrue);
      expect(progress.totalPoints, 500);
      expect(progress.streakAsOf(DateTime(2026, 8, 18, 10)), 7);
      expect(progress.lastCompletedDay, '2026-08-18');
    });

    test('la nube NO pisa un progreso local mayor', () {
      // Quien acaba de jugar sin cobertura tiene razón frente a un documento
      // viejo. Adoptar aquí le borraría la partida que acaba de terminar.
      jugar(DateTime(2026, 8, 18));
      final local = progress.totalPoints;

      expect(progress.adoptCloud(nube(total: 1)), isFalse);
      expect(progress.totalPoints, local);
    });

    test('la mejor racha nunca baja al adoptar', () {
      prefs.setInt('progress.bestStreak', 30);
      progress.adoptCloud(nube());
      expect(progress.bestStreak, 30);
    });

    test('lo adoptado se vuelve a publicar, no se pierde por el camino', () {
      // El fallo que esto vigila: adoptar 500 puntos y publicar acto seguido un
      // resumen con la semana a cero, porque los DÍAS no viajan y los puntos de
      // la semana se calculan de los días. Eso borraría en la nube justo lo que
      // se acaba de leer de ella.
      progress.adoptCloud(nube());
      final s = progress.summaryAsOf(DateTime(2026, 8, 18, 10));

      expect(s.totalPoints, 500);
      expect(s.weekPoints, 120);
      expect(s.monthPoints, 300);
    });

    test('el suelo adoptado caduca con su periodo', () {
      // Adoptado en agosto, leído en septiembre: los 120 puntos eran de otra
      // semana y de otro mes, y darlos por buenos sería inventarse actividad.
      progress.adoptCloud(nube());
      final s = progress.summaryAsOf(DateTime(2026, 9, 20, 10));

      expect(s.weekPoints, 0);
      expect(s.monthPoints, 0);
      expect(s.totalPoints, 500, reason: 'el total no caduca');
    });

    test('el suelo no se SUMA a lo jugado aquí: se toma el mayor', () {
      // Sumar contaría dos veces un día que estuviera en los dos lados, y en el
      // marcador de amigos eso es mentir hacia arriba.
      progress.adoptCloud(nube());
      jugar(DateTime(2026, 8, 18));
      final unDia = progress.recordFor('2026-08-18')!.points;

      final s = progress.summaryAsOf(DateTime(2026, 8, 18, 10));
      expect(s.weekPoints, 120);
      expect(s.weekPoints, isNot(120 + unDia));
    });
  });
}

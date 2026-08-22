import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';

/// La puntuación está CERRADA en el diseño §4, así que estas pruebas no
/// comprueban "algo razonable": transcriben la tabla del documento y fallan si
/// alguien la toca. Si un día se cambia el modelo, se cambia el documento
/// primero y estas pruebas después, nunca al revés.
void main() {
  DailyOutcome finished(Difficulty d, int mistakes) => DailyOutcome(
    dayKey: '2026-08-17',
    difficulty: d,
    completed: true,
    mistakes: mistakes,
    completionPercent: 100,
    seconds: 0,
  );

  DailyOutcome partial(Difficulty d, int percent, {int mistakes = 0}) =>
      DailyOutcome(
        dayKey: '2026-08-17',
        difficulty: d,
        completed: false,
        mistakes: mistakes,
        completionPercent: percent,
        seconds: 0,
      );

  group('base por dificultad (§3)', () {
    test('50 / 100 / 150', () {
      expect(baseFor(Difficulty.easy), 50);
      expect(baseFor(Difficulty.medium), 100);
      expect(baseFor(Difficulty.hard), 150);
    });

    test('una semana limpia son 650 puntos', () {
      // 3 fáciles + 2 medios + 2 difíciles.
      final week =
          3 * baseFor(Difficulty.easy) +
          2 * baseFor(Difficulty.medium) +
          2 * baseFor(Difficulty.hard);
      expect(week, 650);
    });
  });

  group('la escalera completa del documento §4', () {
    // Fila a fila, tal cual está impresa: fácil(50) · medio(100) · difícil(150).
    const ladder = <String, (int, int, int)>{
      'limpia (100%)': (50, 100, 150),
      '1 fallo (90%)': (45, 90, 135),
      '2 fallos (80%)': (40, 80, 120),
      '3 fallos (70%)': (35, 70, 105),
      '4 fallos (60%)': (30, 60, 90),
      '5+ fallos, suelo (50%)': (25, 50, 75),
    };

    test('terminando, por número de fallos', () {
      var mistakes = 0;
      for (final row in ladder.entries) {
        final (easy, medium, hard) = row.value;
        expect(
          scoreDaily(finished(Difficulty.easy, mistakes)).points,
          easy,
          reason: '${row.key} en fácil',
        );
        expect(
          scoreDaily(finished(Difficulty.medium, mistakes)).points,
          medium,
          reason: '${row.key} en medio',
        );
        expect(
          scoreDaily(finished(Difficulty.hard, mistakes)).points,
          hard,
          reason: '${row.key} en difícil',
        );
        mistakes++;
      }
    });

    test('los tramos parciales', () {
      const rows = <String, (int, (int, int, int))>{
        'parcial 75–99 (40%)': (80, (20, 40, 60)),
        'parcial 50–75 (30%)': (60, (15, 30, 45)),
        'parcial 25–50 (20%)': (30, (10, 20, 30)),
        'parcial 1–25 (10%)': (10, (5, 10, 15)),
      };
      for (final row in rows.entries) {
        final (pct, (easy, medium, hard)) = row.value;
        expect(
          scoreDaily(partial(Difficulty.easy, pct)).points,
          easy,
          reason: '${row.key} en fácil',
        );
        expect(
          scoreDaily(partial(Difficulty.medium, pct)).points,
          medium,
          reason: '${row.key} en medio',
        );
        expect(
          scoreDaily(partial(Difficulty.hard, pct)).points,
          hard,
          reason: '${row.key} en difícil',
        );
      }
    });

    test('sin empezar, 0 en las tres', () {
      for (final d in Difficulty.values) {
        expect(scoreDaily(partial(d, 0)).points, 0);
      }
    });
  });

  group('fallos', () {
    test('a partir de 5 ya no restan más', () {
      for (final d in Difficulty.values) {
        final floor = scoreDaily(finished(d, 5)).points;
        for (final n in [6, 7, 12, 81, 999]) {
          expect(
            scoreDaily(finished(d, n)).points,
            floor,
            reason: '$n fallos en $d deberían quedarse en el suelo',
          );
        }
      }
    });

    test('el suelo es exactamente la mitad de la base', () {
      for (final d in Difficulty.values) {
        expect(scoreDaily(finished(d, 5)).points, baseFor(d) ~/ 2);
      }
    });

    test('nunca da puntos negativos', () {
      for (final d in Difficulty.values) {
        expect(scoreDaily(finished(d, 500)).points, greaterThanOrEqualTo(0));
      }
    });

    test('los parciales NO descuentan por fallos', () {
      // Regla del §4: el parcial va por avance y nada más. Se sostiene porque el
      // avance solo cuenta casillas correctas.
      for (final d in Difficulty.values) {
        final limpio = scoreDaily(partial(d, 80)).points;
        final sucio = scoreDaily(partial(d, 80, mistakes: 40)).points;
        expect(sucio, limpio, reason: 'en $d el parcial no debe penalizar');
      }
    });
  });

  group('fronteras de los tramos parciales', () {
    test('el límite paga el tramo de ARRIBA', () {
      // Los cortes del documento se solapan; la decisión es redondear a favor
      // del jugador. Estas cifras fijan esa elección.
      expect(scoreDaily(partial(Difficulty.hard, 75)).points, 60);
      expect(scoreDaily(partial(Difficulty.hard, 74)).points, 45);
      expect(scoreDaily(partial(Difficulty.hard, 50)).points, 45);
      expect(scoreDaily(partial(Difficulty.hard, 49)).points, 30);
      expect(scoreDaily(partial(Difficulty.hard, 25)).points, 30);
      expect(scoreDaily(partial(Difficulty.hard, 24)).points, 15);
      expect(scoreDaily(partial(Difficulty.hard, 1)).points, 15);
      expect(scoreDaily(partial(Difficulty.hard, 0)).points, 0);
    });

    test('el avance nunca decide a la baja al subir', () {
      // Monotonía: más casillas correctas jamás pueden dar menos puntos.
      for (final d in Difficulty.values) {
        var previous = 0;
        for (var pct = 0; pct <= 99; pct++) {
          final points = scoreDaily(partial(d, pct)).points;
          expect(
            points,
            greaterThanOrEqualTo(previous),
            reason: 'en $d, $pct% dio menos que ${pct - 1}%',
          );
          previous = points;
        }
      }
    });
  });

  group('las dos propiedades que sostienen el modelo', () {
    test('TERMINAR GANA SIEMPRE: el peor final supera al mejor parcial', () {
      for (final d in Difficulty.values) {
        final peorFinal = scoreDaily(finished(d, 99)).points;
        final mejorParcial = scoreDaily(partial(d, 99)).points;
        expect(
          peorFinal,
          greaterThan(mejorParcial),
          reason: 'en $d terminar con 99 fallos debe superar un 99% a medias',
        );
      }
    });

    test('un difícil a medias renta más que un fácil entero', () {
      // Es el empujón a probar los días duros que describe el §4.
      expect(
        scoreDaily(partial(Difficulty.hard, 99)).points,
        greaterThan(scoreDaily(finished(Difficulty.easy, 0)).points),
      );
    });
  });

  group('racha', () {
    test('solo la da terminar (§1)', () {
      expect(scoreDaily(finished(Difficulty.easy, 0)).extendsStreak, isTrue);
      expect(scoreDaily(finished(Difficulty.easy, 99)).extendsStreak, isTrue);
      // Un parcial altísimo puntúa pero NO da racha: si la diera, una casilla al
      // día mantendría una racha infinita.
      expect(scoreDaily(partial(Difficulty.hard, 99)).extendsStreak, isFalse);
      expect(scoreDaily(partial(Difficulty.hard, 0)).extendsStreak, isFalse);
    });
  });

  group('desglose para la pantalla de resultado (§4)', () {
    test('terminando trae base, fallos contados y lo restado', () {
      final s = scoreDaily(finished(Difficulty.medium, 3));
      expect(s.base, 100);
      expect(s.countedMistakes, 3);
      expect(s.mistakePenalty, 30);
      expect(s.points, 70);
      expect(
        s.base - s.mistakePenalty,
        s.points,
        reason: 'el desglose debe cuadrar',
      );
      expect(s.partialFraction, isNull);
    });

    test('el desglose topa los fallos igual que los puntos', () {
      final s = scoreDaily(finished(Difficulty.easy, 9));
      expect(s.countedMistakes, 5);
      expect(s.mistakePenalty, 25);
      expect(s.points, 25);
    });

    test('a medias trae el tramo aplicado y no penaliza', () {
      final s = scoreDaily(partial(Difficulty.hard, 60, mistakes: 4));
      expect(s.completed, isFalse);
      expect(s.partialFraction, 0.30);
      expect(s.mistakePenalty, 0);
      expect(s.countedMistakes, 0);
      expect(s.points, 45);
    });
  });

  group('el reloj no puntúa (§1)', () {
    test('el mismo resultado en 30 s o en 3 horas da lo mismo', () {
      for (final d in Difficulty.values) {
        final rapido = scoreDaily(
          DailyOutcome(
            dayKey: '2026-08-17',
            difficulty: d,
            completed: true,
            mistakes: 1,
            completionPercent: 100,
            seconds: 30,
          ),
        ).points;
        final lento = scoreDaily(
          DailyOutcome(
            dayKey: '2026-08-17',
            difficulty: d,
            completed: true,
            mistakes: 1,
            completionPercent: 100,
            seconds: 10800,
          ),
        ).points;
        expect(rapido, lento);
      }
    });
  });
}

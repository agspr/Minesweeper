import 'package:flutter_test/flutter_test.dart';
import 'package:nona/game/daily_controller.dart';
import 'package:nona/game/difficulty.dart';
import 'package:nona/game/scoring.dart';
import 'package:nona/l10n/app_localizations.dart';
import 'package:nona/services/share_service.dart';
import 'package:flutter/widgets.dart';

/// El mensaje compartido no puede destripar el puzle (diseño §7). Un sudoku no
/// admite la rejilla de emojis de CINCO: enseñar qué casillas llevaba cada uno
/// filtra información real del tablero a quien aún no ha jugado.
void main() {
  late L es;
  late L en;

  setUpAll(() async {
    es = await L.delegate.load(const Locale('es'));
    en = await L.delegate.load(const Locale('en'));
  });

  DailyScore finished(Difficulty d, {int mistakes = 0}) => scoreDaily(
    DailyOutcome(
      dayKey: '2026-08-17',
      difficulty: d,
      completed: true,
      mistakes: mistakes,
      completionPercent: 100,
      seconds: 754,
    ),
  );

  String build(L l, DailyScore s, {int streak = 1}) => buildShareText(
    l: l,
    score: s,
    difficulty: switch (s.base) {
      50 => Difficulty.easy,
      100 => Difficulty.medium,
      _ => Difficulty.hard,
    },
    dayLabel: '17/8/2026',
    streak: streak,
  );

  test('no filtra NADA del tablero', () {
    final text = build(es, finished(Difficulty.hard, mistakes: 2));
    // Ni dígitos sueltos del puzle ni rejilla: solo resultado.
    expect(text.contains('Buscaminas'), isTrue);
    expect(text.split('\n').length, lessThan(8), reason: 'debe ser corto');
    // El único cuadro que sale es la fila de fallos, que no dice nada del
    // tablero: son 3 huecos fijos (3 vidas/minas).
    expect('🟩'.allMatches(text).length + '⬛'.allMatches(text).length, 3);
  });

  test('la fila de fallos refleja lo conservado', () {
    expect(build(es, finished(Difficulty.easy)).contains('🟩🟩🟩'), isTrue);
    expect(
      build(es, finished(Difficulty.easy, mistakes: 2)).contains('🟩⬛⬛'),
      isTrue,
    );
    // A partir de 3 la penalización se acaba (derrota), y la fila también.
    expect(
      build(es, finished(Difficulty.easy, mistakes: 9)).contains('⬛⬛⬛'),
      isTrue,
    );
  });

  test('NO menciona el tiempo: el reloj no puntúa (§1)', () {
    // Presumir de tiempo convertiría la diaria en una carrera, que es justo lo
    // que el modelo evita.
    final text = build(es, finished(Difficulty.hard));
    expect(text.contains('12:34'), isFalse);
    expect(text.contains('754'), isFalse);
  });

  test('la racha solo sale si hay más de un día', () {
    expect(
      build(es, finished(Difficulty.easy), streak: 1).contains('🔥'),
      isFalse,
    );
    expect(
      build(es, finished(Difficulty.easy), streak: 4).contains('🔥'),
      isTrue,
    );
  });

  test('sin terminar dice el avance, sin disimular', () {
    final partial = scoreDaily(
      const DailyOutcome(
        dayKey: '2026-08-17',
        difficulty: Difficulty.medium,
        completed: false,
        mistakes: 3,
        completionPercent: 62,
        seconds: 300,
      ),
    );
    final text = build(es, partial);
    expect(text.contains('62'), isTrue);
    expect(
      text.contains('🟩'),
      isFalse,
      reason: 'la fila de fallos es de los terminados',
    );
  });

  test('sale traducido en los dos idiomas', () {
    expect(build(es, finished(Difficulty.hard)).contains('Difícil'), isTrue);
    expect(build(es, finished(Difficulty.hard)).contains('Buscaminas'), isTrue);
    expect(build(en, finished(Difficulty.hard)).contains('Hard'), isTrue);
    expect(build(en, finished(Difficulty.hard)).contains('Minesweeper'), isTrue);
  });
}

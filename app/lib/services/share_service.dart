/// Texto para compartir el resultado del día.
///
/// **Sin destripar el puzle** (diseño §7). Un sudoku no admite la rejilla de
/// emojis que usa CINCO: enseñar qué casillas llevaba puestas cada uno filtra
/// información real sobre el tablero a quien todavía no ha jugado. Así que se
/// comparte el RESULTADO, no el camino.
///
/// El reloj tampoco aparece. El diseño §1 dice que no puntúa, y presumir de
/// tiempo en un mensaje público convertiría de facto la diaria en una carrera,
/// que es exactamente lo que el modelo evita.
library;

import 'package:share_plus/share_plus.dart';

import '../game/difficulty.dart';
import '../game/scoring.dart';
import '../l10n/app_localizations.dart';

/// Cuadro visual del resultado, sin información del tablero.
///
/// Los cinco huecos son los cinco fallos que cuentan (a partir del quinto la
/// penalización se acaba), así que la fila se lee sola: cuadros llenos = lo que
/// conservaste. Comunica el resultado sin decir una palabra del puzle.
String _mistakeRow(int countedMistakes) {
  const kept = '🟩';
  const lost = '⬛';
  final n = countedMistakes.clamp(0, maxCountedMistakes);
  return kept * (maxCountedMistakes - n) + lost * n;
}

String _difficultyEmoji(Difficulty d) => switch (d) {
  Difficulty.easy => '🟢',
  Difficulty.medium => '🟡',
  Difficulty.hard => '🔴',
};

String buildShareText({
  required L l,
  required DailyScore score,
  required Difficulty difficulty,
  required String dayLabel,
  required int streak,
}) {
  final lines = <String>[
    '${l.appName} · $dayLabel',
    '${_difficultyEmoji(difficulty)} ${switch (difficulty) {
      Difficulty.easy => l.difficultyEasy,
      Difficulty.medium => l.difficultyMedium,
      Difficulty.hard => l.difficultyHard,
    }} · ${l.shareScore(score.points)}',
  ];

  if (score.completed || score.lost) {
    lines.add(_mistakeRow(score.countedMistakes));
  } else {
    // Sin terminar: se dice el avance, que es lo que se puntuó. Nada de
    // disimular — el crédito parcial es parte del juego.
    lines.add(l.breakdownCompleted(score.completionPercent));
  }

  if (streak > 1) lines.add(l.shareStreak(streak));
  lines.add('');
  lines.add(l.shareChallenge);
  return lines.join('\n');
}

Future<void> shareText(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

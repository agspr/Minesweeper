/// Puntuación de la diaria (diseño §4, **cerrada**).
///
/// Todo es un porcentaje de la base del día, y la base la fija el día de la
/// semana (§3). Así el sistema entero es una escala coherente y de números
/// enteros, sin casos especiales:
///
/// - **Terminada:** `base − min(fallos, 5) × 10% × base`. Limpia = 100% de la
///   base; a partir de 5 fallos se queda en el suelo del 50%.
/// - **Sin terminar:** un tramo fijo según el % de casillas correctas, sin
///   descuento por fallos, y **siempre por debajo del suelo de terminar**.
///
/// Dos propiedades que la escala garantiza a propósito, y que hay pruebas
/// vigilando:
/// 1. **Terminar gana siempre.** El peor final (25 en fácil) supera al mejor
///    parcial (20 en fácil) en las tres dificultades.
/// 2. **Intentar un difícil renta más que un fácil.** Un difícil a medias llega
///    a 60; un fácil entero da 50. Empuja a la gente a probar los días duros.
///
/// **El reloj no entra.** Ni bonus por velocidad ni nada: premiar la prisa
/// castiga a quien juega tranquilo y a quien vive en otra franja horaria.
///
/// **El modo libre no puntúa** (§1): no hay ninguna ruta que llame aquí desde
/// la práctica.
library;

import 'daily_controller.dart';
import 'difficulty.dart';

/// Base del día por dificultad (§3). Semana limpia = 650 puntos.
int baseFor(Difficulty d) => switch (d) {
  Difficulty.easy => 50,
  Difficulty.medium => 100,
  Difficulty.hard => 150,
};

/// A partir de aquí los fallos dejan de contar: a 3 minas se pierde la partida.
const int maxCountedMistakes = 3;

/// Lo que cuesta cada fallo (mina detonada en victoria), en porcentaje de la base.
const double mistakePenaltyFraction = 0.15;

/// Fracción de la base otorgada como suelo fijo de participación al perder por 3 minas.
const double defeatParticipationFraction = 0.15;

/// Tramos de crédito parcial: (mínimo de avance inclusive, % de la base).
///
/// Los cortes del documento se solapan ("75–99", "50–75"…), así que el límite
/// se resuelve **hacia arriba**: justo 75 paga como 75–99, justo 50 como 50–75.
/// Es la lectura natural y evita que un jugador en la frontera cobre el tramo
/// peor.
const List<(int minPercent, double fraction)> partialTiers = [
  (75, 0.40),
  (50, 0.30),
  (25, 0.20),
  (1, 0.10),
];

/// Puntos del día, con las piezas para poder explicarlos.
///
/// El desglose no es adorno: §4 pide que el resultado se muestre legible —base,
/// lo que salió y lo que restaron los fallos—, así que el cálculo entrega sus
/// partes en vez de un número suelto.
class DailyScore {
  const DailyScore({
    required this.points,
    required this.base,
    required this.completed,
    this.lost = false,
    required this.countedMistakes,
    required this.mistakePenalty,
    required this.completionPercent,
    required this.partialFraction,
  });

  /// Puntos que se suman al total. Nunca negativo.
  final int points;

  final int base;
  final bool completed;
  final bool lost;

  /// Fallos que de verdad han restado (topado en [maxCountedMistakes]).
  final int countedMistakes;

  /// Puntos restados por fallos. 0 si no terminó (los parciales no descuentan).
  final int mistakePenalty;

  final int completionPercent;

  /// Fracción del tramo parcial aplicada, o `null` si terminó limpiamente.
  final double? partialFraction;

  /// ¿Extiende la racha? Se conserva si la partida se jugó hasta su conclusión:
  /// victoria o derrota. Las partidas incompletas o abandonadas no alargan la racha.
  bool get extendsStreak => completed || lost;
}

/// Puntúa el resultado de una diaria.
DailyScore scoreDaily(DailyOutcome outcome) {
  final base = baseFor(outcome.difficulty);

  if (outcome.completed) {
    final counted = outcome.mistakes > maxCountedMistakes
        ? maxCountedMistakes
        : outcome.mistakes;
    // Se calcula sobre la base con `round`, no acumulando restas, para que la
    // escala caiga en enteros limpios en las tres dificultades.
    final penalty = (base * mistakePenaltyFraction * counted).round();
    return DailyScore(
      points: base - penalty,
      base: base,
      completed: true,
      lost: false,
      countedMistakes: counted,
      mistakePenalty: penalty,
      completionPercent: outcome.completionPercent,
      partialFraction: null,
    );
  }

  if (outcome.lost) {
    final points = (base * defeatParticipationFraction).round();
    return DailyScore(
      points: points,
      base: base,
      completed: false,
      lost: true,
      countedMistakes: outcome.mistakes,
      mistakePenalty: base - points,
      completionPercent: outcome.completionPercent,
      partialFraction: defeatParticipationFraction,
    );
  }

  // Sin terminar: manda el avance, y los fallos no descuentan.
  final pct = outcome.completionPercent;
  for (final (minPercent, fraction) in partialTiers) {
    if (pct >= minPercent) {
      return DailyScore(
        points: (base * fraction).round(),
        base: base,
        completed: false,
        lost: false,
        countedMistakes: 0,
        mistakePenalty: 0,
        completionPercent: pct,
        partialFraction: fraction,
      );
    }
  }

  // Ni una casilla correcta: no se jugó.
  return DailyScore(
    points: 0,
    base: base,
    completed: false,
    lost: false,
    countedMistakes: 0,
    mistakePenalty: 0,
    completionPercent: pct,
    partialFraction: null,
  );
}

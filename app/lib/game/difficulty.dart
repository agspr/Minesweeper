/// Dificultad del puzle de Buscaminas y cómo se decide.
///
/// La del diario **no la elige el jugador**: sale del día de la semana, igual
/// para todo el mundo, porque una clasificación solo es justa si todos jugaron
/// el mismo puzle. Elegir dificultad queda para el modo libre, que no puntúa.
library;

import 'solver.dart';

enum Difficulty {
  easy,
  medium,
  hard;

  String get wire => name;

  /// Columnas de la cuadrícula según el nivel.
  int get cols => switch (this) {
    Difficulty.easy => 8,
    Difficulty.medium => 9,
    Difficulty.hard => 10,
  };

  /// Filas de la cuadrícula según el nivel (formato vertical en móvil).
  int get rows => switch (this) {
    Difficulty.easy => 8,
    Difficulty.medium => 12,
    Difficulty.hard => 14,
  };

  /// Total de casillas del tablero (`cols * rows`).
  int get cellCount => cols * rows;

  /// Cantidad de minas ocultas en el tablero.
  int get mines => switch (this) {
    Difficulty.easy => 10,
    Difficulty.medium => 18,
    Difficulty.hard => 28,
  };

  /// Total de casillas seguras (`cellCount - mines`).
  int get safeCells => cellCount - mines;

  static Difficulty fromWire(String raw) => switch (raw) {
    'easy' => Difficulty.easy,
    'medium' => Difficulty.medium,
    'hard' => Difficulty.hard,
    _ => throw ArgumentError.value(raw, 'raw', 'Unknown difficulty'),
  };
}

/// Mapa semanal (diseño §3): 3 fáciles (L-X-V), 2 medios (M-J), 2 difíciles
/// (S-D). Los fines de semana pesan más —hay más tiempo y más jugadores
/// entregados— y entre semana se alternan para que no se haga monótono.
///
/// [weekday] usa el convenio de `DateTime`: lunes = 1 … domingo = 7.
Difficulty difficultyForWeekday(int weekday) => switch (weekday) {
  DateTime.monday || DateTime.wednesday || DateTime.friday => Difficulty.easy,
  DateTime.tuesday || DateTime.thursday => Difficulty.medium,
  DateTime.saturday || DateTime.sunday => Difficulty.hard,
  _ => throw ArgumentError.value(weekday, 'weekday', 'Debe ir de 1 a 7'),
};

Difficulty difficultyForDate(DateTime date) =>
    difficultyForWeekday(date.weekday);

/// Grado de un tablero de Buscaminas, a partir de la técnica deductiva más
/// difícil que exige **y** del número de casillas abiertas de partida (`clueCount`).
/// Devuelve `null` si no se resuelve con pura lógica sin adivinar.
Difficulty? gradeFor(SolveReport report, int clueCount) {
  if (!report.solved) return null;
  return switch (report.hardest) {
    null || Technique.nakedSingle || Technique.hiddenSingle =>
      clueCount >= 32 ? Difficulty.easy : Difficulty.medium,
    Technique.lockedCandidates =>
      clueCount >= 28 ? Difficulty.medium : Difficulty.hard,
    Technique.nakedPair ||
    Technique.hiddenPair ||
    Technique.nakedTriple ||
    Technique.xWing => Difficulty.hard,
  };
}

/// Límites de técnica y de casillas iniciales abiertas para cada nivel.
({Technique maxTechnique, int minClues}) digTargetFor(Difficulty d) =>
    switch (d) {
      Difficulty.easy => (maxTechnique: Technique.hiddenSingle, minClues: 32),
      Difficulty.medium => (
        maxTechnique: Technique.lockedCandidates,
        minClues: 28,
      ),
      Difficulty.hard => (maxTechnique: Technique.xWing, minClues: 17),
    };

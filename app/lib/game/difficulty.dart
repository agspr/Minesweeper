/// Dificultad del puzle y cómo se decide.
///
/// La del diario **no la elige el jugador**: sale del día de la semana, igual
/// para todo el mundo, porque una clasificación solo es justa si todos jugaron
/// el mismo puzle. Elegir dificultad queda para el modo libre, que no puntúa.
library;

import 'solver.dart';

enum Difficulty { easy, medium, hard }

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

/// Grado de un puzle, a partir de la técnica más difícil que exige **y** de
/// cuántas pistas tiene. Devuelve `null` si no se resuelve con lógica: eso
/// obligaría a adivinar y no entra en el banco.
///
/// Por qué las dos cosas y no solo la técnica. La primera versión graduaba
/// únicamente por técnica, y midiendo 60 vaciados maximales se vio que no
/// funciona: **47 de 60 se resuelven solo con "únicos"**, y apenas 4 llegan a
/// pedir un par desnudo o más. Con ese reparto, un grado "difícil" definido
/// por técnica sería un puzle entre quince, y el generador se pasaría la vida
/// descartando.
///
/// Y sobre todo sería *falso*: entre esos 47 los hay de 25 pistas y de 32, y
/// para una persona no se parecen en nada. Con 32 pistas siempre hay un
/// movimiento evidente a la vista; con 25, encontrar cada "único" exige
/// rastrear el tablero entero. Esa búsqueda es dificultad real aunque la
/// técnica sea la misma, así que cuenta.
///
/// Los cortes salen del reparto medido, no de la nada: la mediana de un
/// vaciado maximal ronda las 28 pistas, así que 32 marca "cómodo" y 28
/// "apretado".
Difficulty? gradeFor(SolveReport report, int clueCount) {
  if (!report.solved) return null;
  return switch (report.hardest) {
    // Solo "únicos": lo decide cuánto hay que buscarlos.
    null || Technique.nakedSingle || Technique.hiddenSingle =>
      clueCount >= 32 ? Difficulty.easy : Difficulty.medium,
    // Candidatos confinados: medio si va holgado, difícil si va justo.
    Technique.lockedCandidates =>
      clueCount >= 28 ? Difficulty.medium : Difficulty.hard,
    // Pares, tríos y X-Wing: difícil, tenga las pistas que tenga.
    Technique.nakedPair ||
    Technique.hiddenPair ||
    Technique.nakedTriple ||
    Technique.xWing => Difficulty.hard,
  };
}

/// Cómo hay que vaciar para acertar cada grado: hasta qué técnica se permite
/// que suba el puzle, y por debajo de cuántas pistas no se sigue cavando.
///
/// Es el reverso exacto de [gradeFor]: el tope de técnica impide pasarse de
/// grado por arriba y el suelo de pistas impide pasarse por abajo.
({Technique maxTechnique, int minClues}) digTargetFor(Difficulty d) =>
    switch (d) {
      Difficulty.easy => (
        maxTechnique: Technique.hiddenSingle,
        minClues: 32,
      ),
      Difficulty.medium => (
        maxTechnique: Technique.lockedCandidates,
        minClues: 28,
      ),
      // El difícil no lleva tope: se vacía cuanto la unicidad y la lógica
      // permitan. 17 es el mínimo demostrado de un sudoku con solución única.
      Difficulty.hard => (maxTechnique: Technique.xWing, minClues: 17),
    };

// Nota: aquí hubo un `minCluesFor(Difficulty)` que decía a qué número de
// pistas vaciar cada grado. Se quitó porque partía de una premisa falsa —que
// las pistas miden la dificultad—: el generador vaciaba a ciegas hasta esa
// cifra, graduaba al final y salía cualquier cosa. Ahora el vaciado consulta
// [gradeFor] en cada retirada, así que el número de pistas es una CONSECUENCIA
// del grado, no su causa. Ver `generator.dart`.

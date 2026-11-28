// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Buscaminas';

  @override
  String get appTagline => 'Reto diario';

  @override
  String get menuDaily => 'Reto diario';

  @override
  String menuDailyToday(String difficulty) {
    return '$difficulty · hoy';
  }

  @override
  String menuDailyDone(String difficulty) {
    return 'Hecha · $difficulty';
  }

  @override
  String get menuLoading => 'Cargando…';

  @override
  String get menuPractice => 'Modo práctica';

  @override
  String get menuPracticeSubtitle => 'Puzles infinitos · sin puntos ni racha';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Medio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String get noMistakes => 'sin errores';

  @override
  String mistakeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errores',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String get mistakeCapSuffix => ' (tope)';

  @override
  String hintCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Deshacer';

  @override
  String get erase => 'Borrar';

  @override
  String get notes => 'Notas';

  @override
  String get practiceDifficultyTitle => 'Selecciona el nivel\nde dificultad';

  @override
  String get practiceDifficultySubtitle =>
      'Cambia el tamaño del tablero y cuántas minas esconde. Todos se resuelven con lógica, sin adivinar.';

  @override
  String get difficultyEasyDesc => 'El tablero más pequeño y con menos minas';

  @override
  String get difficultyMediumDesc =>
      'Más grande y con más minas: hay que rastrear el tablero';

  @override
  String get difficultyHardDesc =>
      'El más grande, y siempre pide cruzar dos pistas';

  @override
  String get practiceModeSenda => 'Senda (3 vidas)';

  @override
  String get practiceModeClassic => 'Clásico (1 vida)';

  @override
  String get keepPlaying => 'Seguir jugando';

  @override
  String get closeGame => 'Menú principal';

  @override
  String get hint => 'Pista';

  @override
  String get newPuzzle => 'Otro puzle';

  @override
  String get solved => '¡Resuelto!';

  @override
  String get unfinished => 'Por hoy lo dejamos aquí';

  @override
  String get streakDays => 'días de racha';

  @override
  String get keepPlayingPractice => 'Seguir jugando (Práctica)';

  @override
  String get points => 'puntos';

  @override
  String get breakdownBase => 'Base del día';

  @override
  String get breakdownNoMistakes => 'Sin errores';

  @override
  String breakdownCompleted(int percent) {
    return '$percent% completado';
  }

  @override
  String get breakdownTotal => 'Total';

  @override
  String get streakKept => '🔥 Racha mantenida';

  @override
  String get streakNeedsFinish => 'La racha pide terminarlo';

  @override
  String get done => 'Listo';

  @override
  String get bankGap =>
      'No hay puzle para hoy.\nRevisa la fecha de tu dispositivo.';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Del sistema';

  @override
  String get share => 'Compartir';

  @override
  String shareScore(int points) {
    return '$points pts';
  }

  @override
  String shareStreak(int days) {
    return '🔥 $days días de racha';
  }

  @override
  String get shareChallenge => '¿Puedes con la de hoy?';

  @override
  String get statsPracticeByLevel => 'Práctica por nivel';

  @override
  String get statsPlayedShort => 'Jugadas';

  @override
  String get statsCompletedShort => 'Completadas';

  @override
  String get statsBestTime => 'Mejor tiempo';

  @override
  String get statsBestShort => 'Mejor';

  @override
  String get statsDaysPlayed => 'Días jugados';

  @override
  String get statsDaysCompleted => 'Terminados';

  @override
  String get statsStreak => 'Racha';

  @override
  String get statsBestStreak => 'Mejor racha';

  @override
  String get statsTotalPoints => 'Puntos';

  @override
  String get statsAvgMistakes => 'Errores por día';

  @override
  String get more => 'Más';

  @override
  String get aboutNona => 'Acerca de Buscaminas';

  @override
  String get aboutSubtitle => 'Quiénes somos, términos, privacidad y contacto';

  @override
  String get aboutBody =>
      'Buscaminas es un juego diario desarrollado por SENDA LLC en Puerto Rico. Cada día hay un puzle nuevo, el mismo para todo el mundo, con la dificultad marcada por el día de la semana. Hay también un modo práctica con puzles ilimitados que no da puntos ni racha, y una clasificación para competir con tus amigos.';

  @override
  String get boardColourOn => 'Tablero en color';

  @override
  String get boardColourOff => 'Tablero en gris';

  @override
  String menuStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count días de racha',
      one: '🔥 1 día de racha',
    );
    return '$_temp0';
  }

  @override
  String get sceneTodaysSudoku => 'El buscaminas de hoy';

  @override
  String get sceneMistakes => 'Errores';

  @override
  String get scenePoints => 'Puntos';

  @override
  String sceneStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'días de racha',
      one: 'día de racha',
    );
    return '$_temp0';
  }

  @override
  String sceneStreakTomorrow(int next) {
    return 'Juega mañana y serán $next.';
  }

  @override
  String sceneMilestoneTitle(int count) {
    return '¡$count días seguidos!';
  }

  @override
  String get sceneMilestoneLabel => 'Un hito de racha';

  @override
  String get sceneFriendsTitle => 'Rachas de amigos';

  @override
  String get sceneFriendsAllPlayed => 'Hoy jugaron todos.';

  @override
  String sceneFriendsOneMissing(String name) {
    return '$name aún no ha jugado hoy.';
  }

  @override
  String sceneFriendsManyMissing(int count) {
    return '$count amigos aún no han jugado hoy.';
  }

  @override
  String get sceneContinue => 'Continuar';

  @override
  String get noAdsTitle => 'Jugar sin anuncios';

  @override
  String noAdsLink(String price) {
    return 'Jugar sin anuncios · $price';
  }

  @override
  String get noAdsDone => 'Listo: ya no verás anuncios';

  @override
  String get noAdsNothingToRestore =>
      'No encontramos ninguna compra que restaurar.';

  @override
  String get sceneRemind => 'Recordar';

  @override
  String get sceneReminded => 'Recordado';

  @override
  String get eraseFirst => 'Usa el botón de borrar para quitarlo primero.';

  @override
  String get startOnMarkedCell =>
      'Empieza por la casilla marcada: es segura, y desde ahí no hace falta adivinar.';
}

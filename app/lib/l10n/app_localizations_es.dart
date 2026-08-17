// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class LEs extends L {
  LEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Nona';

  @override
  String get appTagline => 'Sudoku del día';

  @override
  String get menuDaily => 'La diaria';

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
  String get menuPractice => 'Modo libre';

  @override
  String get menuPracticeSubtitle => 'Puzles infinitos · no puntúa';

  @override
  String get difficultyEasy => 'Fácil';

  @override
  String get difficultyMedium => 'Medio';

  @override
  String get difficultyHard => 'Difícil';

  @override
  String get noMistakes => 'sin fallos';

  @override
  String mistakeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fallos',
      one: '1 fallo',
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
  String get hint => 'Pista';

  @override
  String get newPuzzle => 'Otro puzle';

  @override
  String get solved => '¡Resuelto!';

  @override
  String get unfinished => 'Por hoy lo dejamos aquí';

  @override
  String get points => 'puntos';

  @override
  String get breakdownBase => 'Base del día';

  @override
  String get breakdownNoMistakes => 'Sin fallos';

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
  String get statsTitle => 'Tus números';

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
  String get statsAvgMistakes => 'Fallos por día';

  @override
  String get statsNone => 'Todavía no hay nada que contar. Juega la de hoy.';
}

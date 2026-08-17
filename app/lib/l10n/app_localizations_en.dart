// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nona';

  @override
  String get appTagline => 'Daily Sudoku';

  @override
  String get menuDaily => 'Today\'s puzzle';

  @override
  String menuDailyToday(String difficulty) {
    return '$difficulty · today';
  }

  @override
  String menuDailyDone(String difficulty) {
    return 'Done · $difficulty';
  }

  @override
  String get menuLoading => 'Loading…';

  @override
  String get menuPractice => 'Free play';

  @override
  String get menuPracticeSubtitle => 'Endless puzzles · unscored';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get noMistakes => 'no mistakes';

  @override
  String mistakeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mistakes',
      one: '1 mistake',
    );
    return '$_temp0';
  }

  @override
  String get mistakeCapSuffix => ' (max)';

  @override
  String hintCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hints',
      one: '1 hint',
    );
    return '$_temp0';
  }

  @override
  String get undo => 'Undo';

  @override
  String get erase => 'Erase';

  @override
  String get notes => 'Notes';

  @override
  String get hint => 'Hint';

  @override
  String get newPuzzle => 'New puzzle';

  @override
  String get solved => 'Solved!';

  @override
  String get unfinished => 'Let\'s leave it here for today';

  @override
  String get points => 'points';

  @override
  String get breakdownBase => 'Today\'s base';

  @override
  String get breakdownNoMistakes => 'No mistakes';

  @override
  String breakdownCompleted(int percent) {
    return '$percent% complete';
  }

  @override
  String get breakdownTotal => 'Total';

  @override
  String get streakKept => '🔥 Streak kept';

  @override
  String get streakNeedsFinish => 'The streak needs a finish';

  @override
  String get done => 'Done';

  @override
  String get bankGap =>
      'There\'s no puzzle for today.\nCheck your device\'s date.';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get share => 'Share';

  @override
  String shareScore(int points) {
    return '$points pts';
  }

  @override
  String shareStreak(int days) {
    return '🔥 $days-day streak';
  }

  @override
  String get shareChallenge => 'Can you beat today’s?';

  @override
  String get statsTitle => 'Your numbers';

  @override
  String get statsDaysPlayed => 'Days played';

  @override
  String get statsDaysCompleted => 'Finished';

  @override
  String get statsStreak => 'Streak';

  @override
  String get statsBestStreak => 'Best streak';

  @override
  String get statsTotalPoints => 'Points';

  @override
  String get statsAvgMistakes => 'Mistakes per day';

  @override
  String get statsNone => 'Nothing to show yet. Play today’s puzzle.';
}

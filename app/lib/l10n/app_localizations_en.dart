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
  String get menuDaily => 'Daily sudoku';

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
  String get menuPractice => 'Practice mode';

  @override
  String get menuPracticeSubtitle => 'Endless puzzles · no points or streak';

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
  String get practiceDifficultyTitle => 'Choose a\ndifficulty level';

  @override
  String get practiceDifficultySubtitle =>
      'Changes how many givens you get and which techniques you need. Every puzzle has one solution.';

  @override
  String get difficultyEasyDesc =>
      'Plenty of givens, and always a move in plain sight';

  @override
  String get difficultyMediumDesc =>
      'Fewer givens — you have to sweep the board';

  @override
  String get difficultyHardDesc => 'Needs techniques like pairs and triples';

  @override
  String get keepPlaying => 'Keep playing';

  @override
  String get closeGame => 'Main menu';

  @override
  String get hint => 'Hint';

  @override
  String get newPuzzle => 'New puzzle';

  @override
  String get solved => 'Solved!';

  @override
  String get unfinished => 'Let\'s leave it here for today';

  @override
  String get streakDays => 'day streak';

  @override
  String get keepPlayingPractice => 'Keep playing (Practice)';

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
  String get more => 'More';

  @override
  String get aboutNona => 'About Nona';

  @override
  String get aboutSubtitle => 'Who we are, terms, privacy and contact';

  @override
  String get aboutBody =>
      'Nona is a daily sudoku built by SENDA LLC in Puerto Rico. Every day brings a new puzzle, the same one for everyone, with difficulty set by the day of the week. There’s also a practice mode with unlimited puzzles that gives no points or streak, and a leaderboard to play alongside your friends.';

  @override
  String get boardColourOn => 'Board in colour';

  @override
  String get boardColourOff => 'Board in grey';

  @override
  String menuStreak(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count day streak',
      one: '🔥 1 day streak',
    );
    return '$_temp0';
  }
}

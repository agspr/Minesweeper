// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class LEn extends L {
  LEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Minesweeper';

  @override
  String get appTagline => 'Daily Challenge';

  @override
  String get menuDaily => 'Daily challenge';

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
      'Changes the board size and how many mines it hides. Every board can be solved with logic — no guessing.';

  @override
  String get difficultyEasyDesc => 'The smallest board, with the fewest mines';

  @override
  String get difficultyMediumDesc =>
      'Bigger, with more mines — you have to sweep the board';

  @override
  String get difficultyHardDesc =>
      'The biggest board, and it always takes combining two clues';

  @override
  String get practiceModeSenda => 'Senda (3 lives)';

  @override
  String get practiceModeClassic => 'Classic (1 life)';

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
  String get statsPracticeByLevel => 'Practice by level';

  @override
  String get statsPlayedShort => 'Played';

  @override
  String get statsCompletedShort => 'Completed';

  @override
  String get statsBestTime => 'Best time';

  @override
  String get statsBestShort => 'Best';

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
  String get aboutNona => 'About Minesweeper';

  @override
  String get aboutSubtitle => 'Who we are, terms, privacy and contact';

  @override
  String get aboutBody =>
      'Minesweeper is a daily minesweeper built by SENDA LLC in Puerto Rico. Every day brings a new puzzle, the same one for everyone, with difficulty set by the day of the week. There’s also a practice mode with unlimited puzzles that gives no points or streak, and a leaderboard to play alongside your friends.';

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

  @override
  String get sceneTodaysSudoku => 'Today\'s minesweeper';

  @override
  String get sceneMistakes => 'Mistakes';

  @override
  String get scenePoints => 'Points';

  @override
  String sceneStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'day streak',
      one: 'day streak',
    );
    return '$_temp0';
  }

  @override
  String sceneStreakTomorrow(int next) {
    return 'Play tomorrow to make it $next.';
  }

  @override
  String sceneMilestoneTitle(int count) {
    return '$count days in a row!';
  }

  @override
  String get sceneMilestoneLabel => 'A streak milestone';

  @override
  String get sceneFriendsTitle => 'Friend streaks';

  @override
  String get sceneFriendsAllPlayed => 'Everyone played today.';

  @override
  String sceneFriendsOneMissing(String name) {
    return '$name hasn\'t played today yet.';
  }

  @override
  String sceneFriendsManyMissing(int count) {
    return '$count friends haven\'t played today yet.';
  }

  @override
  String get sceneContinue => 'Continue';

  @override
  String get noAdsTitle => 'Play without ads';

  @override
  String noAdsLink(String price) {
    return 'Play without ads · $price';
  }

  @override
  String get noAdsDone => 'Done: no more ads';

  @override
  String get noAdsNothingToRestore =>
      'We couldn\'t find a purchase to restore.';

  @override
  String get sceneRemind => 'Remind';

  @override
  String get sceneReminded => 'Reminded';

  @override
  String get eraseFirst => 'Use the backspace button to erase it first.';
}

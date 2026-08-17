/// Achievement catalog + evaluation rules.
///
/// Achievements are data + pure extractor functions over a
/// [GameplaySnapshot], so adding one is a list entry — no engine code
/// changes. Progress persists locally (SQLite) and can sync to Google Play
/// Games when the player signs in.
library;

import '../../catalog/domain/game_definition.dart';

/// Everything the achievement rules may look at. Built by
/// `AchievementsService.buildSnapshot` after each session.
class GameplaySnapshot {
  const GameplaySnapshot({
    required this.category,
    required this.template,
    required this.won,
    required this.score,
    required this.stars,
    this.stats = const {},
    required this.totalPlays,
    required this.totalWins,
    required this.coinsEarnedTotal,
    required this.streakDays,
    required this.distinctGamesPlayed,
    this.categoryWins = const {},
    this.templateWins = const {},
    this.brainTrainingDays = 0,
  });

  final GameCategory category;
  final String template;
  final bool won;
  final int score;
  final int stars;

  /// Engine-reported stats, e.g. `{'cascades': 3}`.
  final Map<String, int> stats;

  final int totalPlays;
  final int totalWins;
  final int coinsEarnedTotal;
  final int streakDays;
  final int distinctGamesPlayed;

  /// Wins (stars >= 2) per category name, e.g. `{'puzzle': 12}`.
  final Map<String, int> categoryWins;

  /// Wins per engine template, e.g. `{'sudoku': 7}`.
  final Map<String, int> templateWins;

  /// Completed Daily Brain Training days.
  final int brainTrainingDays;
}

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.iconId,
    required this.target,
    required this.extract,
  });

  final String id;
  final String title;
  final String description;

  /// Icon key mapped to an IconData in the UI.
  final String iconId;
  final int target;

  /// Current progress value for this achievement given a snapshot.
  final int Function(GameplaySnapshot s) extract;
}

int _winIn(GameplaySnapshot s, GameCategory c) => s.categoryWins[c.name] ?? 0;

const List<AchievementDef> kAchievements = [
  AchievementDef(
    id: 'first_game', title: 'First Steps', iconId: 'play',
    description: 'Play your first game', target: 1,
    extract: (s) => s.totalPlays >= 1 ? 1 : 0,
  ),
  AchievementDef(
    id: 'plays_25', title: 'Getting Warm', iconId: 'play',
    description: 'Play 25 games', target: 25,
    extract: (s) => s.totalPlays,
  ),
  AchievementDef(
    id: 'plays_100', title: 'Century Club', iconId: 'play',
    description: 'Play 100 games', target: 100,
    extract: (s) => s.totalPlays,
  ),
  AchievementDef(
    id: 'plays_500', title: 'Game Marathoner', iconId: 'play',
    description: 'Play 500 games', target: 500,
    extract: (s) => s.totalPlays,
  ),
  AchievementDef(
    id: 'first_win', title: 'Trophy Debut', iconId: 'trophy',
    description: 'Win your first game', target: 1,
    extract: (s) => s.totalWins >= 1 ? 1 : 0,
  ),
  AchievementDef(
    id: 'wins_25', title: 'Serial Winner', iconId: 'trophy',
    description: 'Win 25 games', target: 25,
    extract: (s) => s.totalWins,
  ),
  AchievementDef(
    id: 'wins_100', title: 'Champion of Champions', iconId: 'trophy',
    description: 'Win 100 games', target: 100,
    extract: (s) => s.totalWins,
  ),
  AchievementDef(
    id: 'arcade_ace', title: 'Arcade Ace', iconId: 'bolt',
    description: 'Win 10 arcade games', target: 10,
    extract: (s) => _winIn(s, GameCategory.arcade),
  ),
  AchievementDef(
    id: 'puzzle_pro', title: 'Puzzle Pro', iconId: 'extension',
    description: 'Win 10 puzzle games', target: 10,
    extract: (s) => _winIn(s, GameCategory.puzzle),
  ),
  AchievementDef(
    id: 'card_shark', title: 'Card Shark', iconId: 'style',
    description: 'Win 10 card games', target: 10,
    extract: (s) => _winIn(s, GameCategory.cards),
  ),
  AchievementDef(
    id: 'board_master', title: 'Board Master', iconId: 'grid',
    description: 'Win 10 board games', target: 10,
    extract: (s) => _winIn(s, GameCategory.board),
  ),
  AchievementDef(
    id: 'quiz_whiz', title: 'Quiz Whiz', iconId: 'quiz',
    description: 'Win 10 trivia games', target: 10,
    extract: (s) => _winIn(s, GameCategory.trivia),
  ),
  AchievementDef(
    id: 'streak_3', title: 'Warming Up', iconId: 'flame',
    description: 'Play 3 days in a row', target: 3,
    extract: (s) => s.streakDays,
  ),
  AchievementDef(
    id: 'streak_7', title: 'A Week of Play', iconId: 'flame',
    description: 'Play 7 days in a row', target: 7,
    extract: (s) => s.streakDays,
  ),
  AchievementDef(
    id: 'streak_30', title: 'Unstoppable', iconId: 'flame',
    description: 'Play 30 days in a row', target: 30,
    extract: (s) => s.streakDays,
  ),
  AchievementDef(
    id: 'arcade_1000', title: 'Arcade Legend', iconId: 'bolt',
    description: 'Score 1000+ in one arcade game', target: 1,
    extract: (s) => s.category == GameCategory.arcade && s.score >= 1000 ? 1 : 0,
  ),
  AchievementDef(
    id: 'combo_master', title: 'Combo Master', iconId: 'extension',
    description: 'Trigger a 3-cascade in a match game', target: 1,
    extract: (s) => s.template == 'match3' && (s.stats['cascades'] ?? 0) >= 3 ? 1 : 0,
  ),
  AchievementDef(
    id: 'perfect_quiz', title: 'Flawless', iconId: 'quiz',
    description: 'Answer every question right in one quiz', target: 1,
    extract: (s) => s.template == 'trivia' && (s.stats['perfect'] ?? 0) == 1 ? 1 : 0,
  ),
  AchievementDef(
    id: 'snake_charmer', title: 'Snake Charmer', iconId: 'bolt',
    description: 'Reach length 30 in Snake', target: 1,
    extract: (s) => s.template == 'snake' && (s.stats['length'] ?? 0) >= 30 ? 1 : 0,
  ),
  AchievementDef(
    id: 'coin_collector', title: 'Coin Collector', iconId: 'coin',
    description: 'Earn 1,000 coins in total', target: 1000,
    extract: (s) => s.coinsEarnedTotal,
  ),
  AchievementDef(
    id: 'explorer', title: 'Explorer', iconId: 'compass',
    description: 'Play 15 different games', target: 15,
    extract: (s) => s.distinctGamesPlayed,
  ),
  // ---- Puzzle & Mind Games add-on ---------------------------------------
  AchievementDef(
    id: 'mind_master', title: 'Mind Master', iconId: 'psychology',
    description: 'Win 10 Puzzle & Mind games', target: 10,
    extract: (s) => _winIn(s, GameCategory.mind),
  ),
  AchievementDef(
    id: 'sudoku_solver', title: 'Sudoku Solver', iconId: 'psychology',
    description: 'Solve 10 Sudoku puzzles', target: 10,
    extract: (s) => s.templateWins['sudoku'] ?? 0,
  ),
  AchievementDef(
    id: 'wordle_ace', title: 'Wordle Ace', iconId: 'psychology',
    description: 'Win 5 daily word puzzles', target: 5,
    extract: (s) => s.templateWins['wordle_daily'] ?? 0,
  ),
  AchievementDef(
    id: 'brain_streak_3', title: 'Brain Warm-Up', iconId: 'psychology',
    description: 'Complete Daily Brain Training 3 days', target: 3,
    extract: (s) => s.brainTrainingDays,
  ),
  AchievementDef(
    id: 'brain_streak_7', title: 'Big Brain Week', iconId: 'psychology',
    description: 'Complete Daily Brain Training 7 days', target: 7,
    extract: (s) => s.brainTrainingDays,
  ),
];

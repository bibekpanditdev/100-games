/// Leaderboard repository + achievements engine tests (in-memory SQLite).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/catalog/domain/game_definition.dart';
import 'package:thousand_games/features/gamification/achievements/achievement_definitions.dart';
import 'package:thousand_games/features/gamification/achievements/achievements_repository.dart';
import 'package:thousand_games/features/gamification/progress_controller.dart';
import 'package:thousand_games/features/leaderboards/scores_repository.dart';

import '../helpers/test_env.dart';

GameDefinition _game(String id, GameCategory category) => GameDefinition(
      id: id,
      title: 'Game $id',
      category: category,
      template: 'snake',
      difficulty: Difficulty.medium,
      themeId: 'ocean',
      config: const {},
    );

void main() {
  late AppDatabase db;
  late ScoresRepository scores;
  late AchievementsRepository achievements;
  late ProgressController progress;

  setUp(() async {
    db = await openTestDb();
    scores = ScoresRepository(db.db);
    achievements = AchievementsRepository(db.db);
    progress = ProgressController(await openTestBox('ach'));
  });

  test('best score per game wins', () async {
    final game = _game('g1', GameCategory.arcade);
    await scores.record(game: game, score: 100, stars: 1);
    await scores.record(game: game, score: 500, stars: 2);
    await scores.record(game: game, score: 300, stars: 2);

    final best = await scores.bestForGame('g1');
    expect(best!.score, 500);

    final top = await scores.topForCategory(GameCategory.arcade);
    expect(top.first.gameId, 'g1');
    expect(top.first.score, 500);
  });

  test('wins counted as stars >= 2', () async {
    final game = _game('g2', GameCategory.puzzle);
    await scores.record(game: game, score: 100, stars: 1);
    await scores.record(game: game, score: 500, stars: 2);
    await scores.record(game: game, score: 900, stars: 3);

    expect(await scores.totalWins(), 2);
    expect((await scores.winsPerCategoryRaw())['puzzle'], 2);
  });

  test('achievements unlock once and persist progress', () async {
    final svc = AchievementsService(
      repository: achievements,
      scores: scores,
      progress: progress,
      db: db.db,
    );

    final game = _game('g3', GameCategory.arcade);
    await scores.record(game: game, score: 1500, stars: 3);

    final firstRun = await svc.applyAndCollectUnlocked(GameResultInput(
      category: GameCategory.arcade,
      template: 'snake',
      won: true,
      score: 1500,
      stars: 3,
      stats: const {'length': 31},
    ));

    final ids = firstRun.map((a) => a.id).toSet();
    expect(ids, containsAll(['first_game', 'first_win', 'arcade_1000', 'snake_charmer']));

    // Same result again unlocks nothing new.
    final secondRun = await svc.applyAndCollectUnlocked(GameResultInput(
      category: GameCategory.arcade,
      template: 'snake',
      won: true,
      score: 1500,
      stars: 3,
      stats: const {'length': 31},
    ));
    expect(secondRun, isEmpty);

    final states = await achievements.loadAll();
    expect(states['arcade_1000']!.unlocked, isTrue);
    expect(states['plays_25']!.progress, 1); // progress tracks plays so far
  });
}

/// Daily Brain Training service tests (in-memory SQLite).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/catalog/data/catalog_repository.dart';
import 'package:thousand_games/features/catalog/domain/game_definition.dart';
import 'package:thousand_games/features/leaderboards/scores_repository.dart';
import 'package:thousand_games/features/mind/brain_training/brain_training_service.dart';

import '../helpers/test_env.dart';

void main() {
  late CatalogRepository catalog;
  late ScoresRepository scores;
  late BrainTrainingService brain;

  setUp(() async {
    final db = await openTestDb();
    catalog = CatalogRepository(db.db);
    scores = ScoresRepository(db.db);
    brain = BrainTrainingService(db: db.db, catalog: catalog);
  });

  GameDefinition _mindGame(String id, String group) => GameDefinition(
        id: id,
        title: 'Mind $id',
        category: GameCategory.mind,
        template: 'sudoku',
        difficulty: Difficulty.medium,
        themeId: 'ocean',
        config: {'group': group},
      );

  test('routine picks one game per subcategory, deterministically', () async {
    final day = DateTime(2026, 8, 17);
    final r1 = await brain.routineFor(day);
    final r2 = await brain.routineFor(day);

    expect(r1.games.length, 5);
    final groups = r1.games.map((g) => g.group).toSet();
    expect(groups, containsAll(['logic', 'word', 'memory', 'math', 'spatial']));
    // Same day -> same picks.
    for (var i = 0; i < r1.games.length; i++) {
      expect(r2.games[i].definition.id, r1.games[i].definition.id);
    }
    // Different day -> (almost certainly) different picks somewhere.
    final other = await brain.routineFor(DateTime(2026, 8, 20));
    final a = r1.games.map((g) => g.definition.id).toSet();
    final b = other.games.map((g) => g.definition.id).toSet();
    expect(a.union(b).length, greaterThan(5));
  });

  test('progress empty on a fresh day; results fill it; score recorded', () async {
    final day = DateTime(2026, 8, 17);
    final routine = await brain.routineFor(day);

    var progress = await brain.progressFor(day);
    expect(progress.completedCount, 0);
    expect(progress.complete, isFalse);
    expect(progress.brainScore, 0);

    // Play two routine games.
    await scores.record(game: routine.games.first.definition, score: 500, stars: 2);
    await scores.record(
      game: routine.games[1].definition,
      score: 1000,
      stars: 3,
    );
    progress = await brain.progressFor(day);
    expect(progress.completedCount, 2);
    expect(progress.brainScore, (500 ~/ 10 + 2 * 150) + (100 ~/ 10 + 3 * 150));

    await brain.refreshDay(day);
    final history = await brain.history();
    expect(history, hasLength(1));
    expect(history.first.day, '2026-08-17');
    expect(history.first.completed, 2);

    // Finish the rest.
    for (final g in routine.games.skip(2)) {
      await scores.record(game: g.definition, score: 300, stars: 1);
    }
    progress = await brain.progressFor(day);
    expect(progress.complete, isTrue);
    await brain.refreshDay(day);
    expect((await brain.history()).first.completed, 5);
  });

  test('only routine games count (other mind games ignored)', () async {
    final day = DateTime(2026, 8, 17);
    await scores.record(game: _mindGame('other_mind_game', 'logic'), score: 999, stars: 3);
    final progress = await brain.progressFor(day);
    expect(progress.completedCount, 0);
  });

  test('history streak counts consecutive recorded days', () {
    final days = [
      BrainScoreDay(day: '2026-08-19', score: 100, completed: 5),
      BrainScoreDay(day: '2026-08-18', score: 200, completed: 5),
      BrainScoreDay(day: '2026-08-17', score: 300, completed: 4),
      BrainScoreDay(day: '2026-08-14', score: 400, completed: 5),
    ];
    expect(brain.historyStreak(days, now: DateTime(2026, 8, 19)), 3);
    expect(brain.historyStreak(days, now: DateTime(2026, 8, 20)), 3);
    expect(brain.historyStreak(days, now: DateTime(2026, 8, 21)), 0);
  });

  test('empty history renders zero streak (dashboard empty state)', () {
    expect(brain.historyStreak(const []), 0);
    expect(await brain.history(), isEmpty);
  });
}

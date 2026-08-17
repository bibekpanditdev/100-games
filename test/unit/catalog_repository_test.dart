/// Catalog repository tests against in-memory SQLite (sqflite ffi).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/catalog/data/catalog_repository.dart';
import 'package:thousand_games/features/catalog/domain/game_definition.dart';

import '../helpers/test_env.dart';

void main() {
  late CatalogRepository repo;

  setUp(() async {
    final db = await openTestDb();
    repo = CatalogRepository(db.db);
  });

  test('seeds 1000+ games on first access', () async {
    final count = await repo.count();
    expect(count, greaterThanOrEqualTo(1000));
  });

  test('all() returns definitions with resolvable palettes and configs', () async {
    final games = await repo.all();
    expect(games, isNotEmpty);
    for (final g in games.take(50)) {
      expect(g.template, isNotEmpty);
      expect(g.config, isNotNull);
    }
  });

  test('byId round-trips a definition', () async {
    final games = await repo.all();
    final target = games.first;
    final loaded = await repo.byId(target.id);
    expect(loaded, isNotNull);
    expect(loaded!.id, target.id);
    expect(loaded.title, target.title);
    expect(loaded.template, target.template);
    expect(loaded.config, target.config);
    expect(loaded.difficulty, target.difficulty);
  });

  test('byId returns null for unknown ids', () async {
    expect(await repo.byId('does_not_exist'), isNull);
  });

  test('GameDefinition json round-trip', () {
    final def = GameDefinition(
      id: 'x',
      title: 'Test Game',
      category: GameCategory.puzzle,
      template: 'match3',
      difficulty: Difficulty.hard,
      themeId: 'neon',
      config: const {'cols': 9},
    );
    final restored = GameDefinition.fromJson(def.toJson());
    expect(restored.id, def.id);
    expect(restored.category, GameCategory.puzzle);
    expect(restored.difficulty, Difficulty.hard);
    expect(restored.config['cols'], 9);
  });
}

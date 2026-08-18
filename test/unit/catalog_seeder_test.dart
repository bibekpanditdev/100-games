/// Catalog generator tests — the "1000+" guarantee.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:game/core/theme/palettes.dart';
import 'package:game/features/catalog/data/catalog_seeder.dart';
import 'package:game/features/catalog/domain/game_definition.dart';

void main() {
  final games = CatalogSeeder.generate();

  test('generates more than 1000 games', () {
    expect(games.length, greaterThanOrEqualTo(1000));
  });

  test('ids are unique', () {
    expect(games.map((g) => g.id).toSet().length, games.length);
  });

  test('titles are non-empty and unique-ish (per id)', () {
    for (final g in games) {
      expect(g.title, isNotEmpty);
      expect(g.title.length, lessThan(40));
    }
  });

  test('deterministic across runs', () {
    final again = CatalogSeeder.generate();
    expect(again.length, games.length);
    for (var i = 0; i < games.length; i++) {
      expect(again[i].id, games[i].id);
      expect(again[i].title, games[i].title);
      expect(again[i].config, games[i].config);
    }
  });

  test('covers every category with 100+ games each', () {
    for (final c in GameCategory.values) {
      final count = games.where((g) => g.category == c).length;
      expect(count, greaterThan(100), reason: '${c.name} has only $count games');
    }
  });

  test('every game uses a known palette and template', () {
    final paletteIds = kPalettes.map((p) => p.id).toSet();
    final templates = games.map((g) => g.template).toSet();
    expect(templates, containsAll([
      'snake', 'breakout', 'whack_a_mole', 'tap_reflex', 'dodge_runner',
      'match3', 'sliding_puzzle', 'block_fall', 'word_search',
      'memory_match', 'higher_lower', 'blackjack',
      'tic_tac_toe', 'connect_four', 'dots_and_boxes', 'trivia',
      'sudoku', 'minesweeper', 'merge2048', 'math_sprint', 'maze', 'pipes',
      'hangman', 'wordle_daily', 'simon', 'pattern_recall', 'odd_one_out',
    ]));
    for (final g in games) {
      expect(paletteIds, contains(g.themeId));
    }
  });

  test('every mind game carries a valid subcategory group', () {
    const validGroups = {'logic', 'word', 'memory', 'math', 'spatial'};
    final mindGames = games.where((g) => g.category == GameCategory.mind).toList();
    expect(mindGames.length, greaterThan(100));
    for (final g in mindGames) {
      expect(validGroups, contains(g.config['group']), reason: '${g.id}');
    }
    // Each subcategory is served by at least 2 templates (2+ games per
    // subcategory per the add-on deliverable).
    for (final group in validGroups) {
      final templatesInGroup = mindGames
          .where((g) => g.config['group'] == group)
          .map((g) => g.template)
          .toSet();
      expect(templatesInGroup.length, greaterThanOrEqualTo(2),
          reason: 'group $group');
    }
  });

  test('config contracts hold for sampled templates', () {
    final byId = {for (final g in games) g.template: g};
    final snake = games.firstWhere((g) => g.template == 'snake');
    expect(snake.config.containsKey('grid'), isTrue);
    expect(snake.config.containsKey('speed'), isTrue);
    expect(snake.config.containsKey('wrap'), isTrue);
    expect(byId['match3']!.config.containsKey('target'), isTrue);
    expect(byId['match3']!.config.containsKey('moves'), isTrue);
    expect(byId['sliding_puzzle']!.config.containsKey('size'), isTrue);
    expect(byId['word_search']!.config.containsKey('timeSec'), isTrue);
    expect(byId['memory_match']!.config.containsKey('pairs'), isTrue);
    expect(byId['tic_tac_toe']!.config.containsKey('aiLevel'), isTrue);
    final sudokuEasy = games.firstWhere(
      (g) => g.template == 'sudoku' && g.difficulty == Difficulty.easy,
    );
    expect(sudokuEasy.config['clues'], 50);
    final sudokuHard = games.firstWhere(
      (g) => g.template == 'sudoku' && g.difficulty == Difficulty.hard,
    );
    expect(sudokuHard.config['clues'] as int, lessThan(50));
    final trivia = games.where((g) => g.template == 'trivia').toList();
    for (final t in trivia) {
      expect(t.config.containsKey('qset'), isTrue);
      expect(t.config.containsKey('count'), isTrue);
      expect(t.config.containsKey('timePerQ'), isTrue);
    }
  });

  test('difficulty scaling moves one direction (easy < medium < hard speed)', () {
    final easy = (games.firstWhere(
      (g) => g.template == 'snake' && g.difficulty == Difficulty.easy,
    ).config['speed']) as num;
    final medium = (games.firstWhere(
      (g) => g.template == 'snake' && g.difficulty == Difficulty.medium,
    ).config['speed']) as num;
    final hard = (games.firstWhere(
      (g) => g.template == 'snake' && g.difficulty == Difficulty.hard,
    ).config['speed']) as num;
    expect(easy, lessThan(medium));
    expect(medium, lessThan(hard));
  });

  test('popularity in range and some games flagged new', () {
    for (final g in games) {
      expect(g.popularity, inInclusiveRange(0, 999));
    }
    expect(games.where((g) => g.isNew).length, greaterThan(20));
  });
}

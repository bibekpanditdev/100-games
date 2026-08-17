/// Deterministic catalog generator.
///
/// The 1000+ games are NOT hand-built: 16 engine templates × 30 visual
/// palettes × 3 difficulty tiers (plus trivia question-set/mode variants)
/// are expanded into ~1,400 [GameDefinition]s that get seeded into SQLite on
/// first launch. Everything is derived from stable values, so the catalog is
/// identical on every device and every launch.
library;

import '../../../core/theme/palettes.dart';
import '../../../core/utils/formatters.dart';
import '../domain/game_definition.dart';

class _TemplateSpec {
  const _TemplateSpec({
    required this.template,
    required this.noun,
    required this.category,
    required this.easy,
    required this.medium,
    required this.hard,
  });

  final String template;
  final String noun;
  final GameCategory category;

  /// Config maps per difficulty tier. Keys are frozen contracts with the
  /// engine implementations — see each engine under lib/features/games/.
  final Map<String, dynamic> easy;
  final Map<String, dynamic> medium;
  final Map<String, dynamic> hard;
}

const List<_TemplateSpec> _templates = [
  // Arcade ---------------------------------------------------------------
  _TemplateSpec(
    template: 'snake',
    noun: 'Snake',
    category: GameCategory.arcade,
    easy: {'grid': 16, 'speed': 4.0, 'wrap': true},
    medium: {'grid': 16, 'speed': 6.0, 'wrap': false},
    hard: {'grid': 20, 'speed': 8.0, 'wrap': false},
  ),
  _TemplateSpec(
    template: 'breakout',
    noun: 'Breaker',
    category: GameCategory.arcade,
    easy: {'rows': 4, 'speed': 180.0, 'lives': 3},
    medium: {'rows': 6, 'speed': 240.0, 'lives': 3},
    hard: {'rows': 8, 'speed': 300.0, 'lives': 2},
  ),
  _TemplateSpec(
    template: 'whack_a_mole',
    noun: 'Whack',
    category: GameCategory.arcade,
    easy: {'holes': 9, 'spawnMs': 900, 'durationSec': 45},
    medium: {'holes': 9, 'spawnMs': 700, 'durationSec': 35},
    hard: {'holes': 12, 'spawnMs': 500, 'durationSec': 25},
  ),
  _TemplateSpec(
    template: 'tap_reflex',
    noun: 'Reflex',
    category: GameCategory.arcade,
    easy: {'rounds': 10, 'windowMs': 1400},
    medium: {'rounds': 12, 'windowMs': 1000},
    hard: {'rounds': 15, 'windowMs': 700},
  ),
  _TemplateSpec(
    template: 'dodge_runner',
    noun: 'Runner',
    category: GameCategory.arcade,
    easy: {'lanes': 3, 'speed': 160.0, 'targetSec': 30},
    medium: {'lanes': 3, 'speed': 220.0, 'targetSec': 45},
    hard: {'lanes': 4, 'speed': 280.0, 'targetSec': 60},
  ),
  // Puzzle ----------------------------------------------------------------
  _TemplateSpec(
    template: 'match3',
    noun: 'Match',
    category: GameCategory.puzzle,
    easy: {'cols': 7, 'rows': 7, 'moves': 20, 'target': 2000},
    medium: {'cols': 8, 'rows': 8, 'moves': 18, 'target': 3000},
    hard: {'cols': 9, 'rows': 9, 'moves': 15, 'target': 4500},
  ),
  _TemplateSpec(
    template: 'sliding_puzzle',
    noun: 'Slide',
    category: GameCategory.puzzle,
    easy: {'size': 3},
    medium: {'size': 4},
    hard: {'size': 5},
  ),
  _TemplateSpec(
    template: 'block_fall',
    noun: 'Blocks',
    category: GameCategory.puzzle,
    easy: {'cols': 8, 'speed': 1.6, 'targetLines': 10},
    medium: {'cols': 9, 'speed': 2.2, 'targetLines': 15},
    hard: {'cols': 10, 'speed': 3.0, 'targetLines': 20},
  ),
  _TemplateSpec(
    template: 'word_search',
    noun: 'Word Hunt',
    category: GameCategory.puzzle,
    easy: {'size': 9, 'wordCount': 6, 'timeSec': 240},
    medium: {'size': 11, 'wordCount': 8, 'timeSec': 180},
    hard: {'size': 12, 'wordCount': 10, 'timeSec': 150},
  ),
  // Cards -----------------------------------------------------------------
  _TemplateSpec(
    template: 'memory_match',
    noun: 'Memory',
    category: GameCategory.cards,
    easy: {'pairs': 8, 'peekSec': 2},
    medium: {'pairs': 10, 'peekSec': 2},
    hard: {'pairs': 12, 'peekSec': 1},
  ),
  _TemplateSpec(
    template: 'higher_lower',
    noun: 'Hi-Lo',
    category: GameCategory.cards,
    easy: {'rounds': 10},
    medium: {'rounds': 12},
    hard: {'rounds': 15},
  ),
  _TemplateSpec(
    template: 'blackjack',
    noun: 'Blackjack',
    category: GameCategory.cards,
    easy: {'rounds': 3},
    medium: {'rounds': 5},
    hard: {'rounds': 7},
  ),
  // Board -----------------------------------------------------------------
  _TemplateSpec(
    template: 'tic_tac_toe',
    noun: 'Tic-Tac-Toe',
    category: GameCategory.board,
    easy: {'aiLevel': 1},
    medium: {'aiLevel': 2},
    hard: {'aiLevel': 3},
  ),
  _TemplateSpec(
    template: 'connect_four',
    noun: 'Connect Four',
    category: GameCategory.board,
    easy: {'aiLevel': 1},
    medium: {'aiLevel': 2},
    hard: {'aiLevel': 3},
  ),
  _TemplateSpec(
    template: 'dots_and_boxes',
    noun: 'Dots & Boxes',
    category: GameCategory.board,
    easy: {'size': 4, 'aiLevel': 1},
    medium: {'size': 5, 'aiLevel': 2},
    hard: {'size': 6, 'aiLevel': 3},
  ),
  // Mind — Puzzle & Mind Games module. Every config carries `group`
  // (logic / word / memory / math / spatial) for subcategory filtering and
  // the Daily Brain Training routine.
  _TemplateSpec(
    template: 'sudoku',
    noun: 'Sudoku',
    category: GameCategory.mind,
    easy: {'group': 'logic', 'clues': 50},
    medium: {'group': 'logic', 'clues': 40},
    hard: {'group': 'logic', 'clues': 30},
  ),
  _TemplateSpec(
    template: 'minesweeper',
    noun: 'Mines',
    category: GameCategory.mind,
    easy: {'group': 'logic', 'size': 8, 'mines': 10},
    medium: {'group': 'logic', 'size': 10, 'mines': 20},
    hard: {'group': 'logic', 'size': 12, 'mines': 35},
  ),
  _TemplateSpec(
    template: 'merge2048',
    noun: 'Merge',
    category: GameCategory.mind,
    easy: {'group': 'math', 'target': 1024},
    medium: {'group': 'math', 'target': 2048},
    hard: {'group': 'math', 'target': 4096},
  ),
  _TemplateSpec(
    template: 'math_sprint',
    noun: 'Math Sprint',
    category: GameCategory.mind,
    easy: {'group': 'math', 'durationSec': 90, 'maxOperand': 12},
    medium: {'group': 'math', 'durationSec': 75, 'maxOperand': 25},
    hard: {'group': 'math', 'durationSec': 60, 'maxOperand': 99},
  ),
  _TemplateSpec(
    template: 'maze',
    noun: 'Maze',
    category: GameCategory.mind,
    easy: {'group': 'spatial', 'size': 11, 'timeSec': 240},
    medium: {'group': 'spatial', 'size': 15, 'timeSec': 180},
    hard: {'group': 'spatial', 'size': 21, 'timeSec': 150},
  ),
  _TemplateSpec(
    template: 'pipes',
    noun: 'Pipes',
    category: GameCategory.mind,
    easy: {'group': 'spatial', 'size': 5},
    medium: {'group': 'spatial', 'size': 6},
    hard: {'group': 'spatial', 'size': 7},
  ),
  _TemplateSpec(
    template: 'hangman',
    noun: 'Hangman',
    category: GameCategory.mind,
    easy: {'group': 'word', 'minLen': 4, 'maxLen': 5, 'lives': 8},
    medium: {'group': 'word', 'minLen': 6, 'maxLen': 7, 'lives': 7},
    hard: {'group': 'word', 'minLen': 8, 'maxLen': 9, 'lives': 6},
  ),
  _TemplateSpec(
    template: 'wordle_daily',
    noun: 'Daily Word',
    category: GameCategory.mind,
    easy: {'group': 'word', 'maxGuesses': 7},
    medium: {'group': 'word', 'maxGuesses': 6},
    hard: {'group': 'word', 'maxGuesses': 5},
  ),
  _TemplateSpec(
    template: 'simon',
    noun: 'Simon',
    category: GameCategory.mind,
    easy: {'group': 'memory', 'startLength': 3, 'stepMs': 700},
    medium: {'group': 'memory', 'startLength': 3, 'stepMs': 550},
    hard: {'group': 'memory', 'startLength': 4, 'stepMs': 420},
  ),
  _TemplateSpec(
    template: 'pattern_recall',
    noun: 'Recall',
    category: GameCategory.mind,
    easy: {'group': 'memory', 'grid': 4, 'cells': 4, 'rounds': 8},
    medium: {'group': 'memory', 'grid': 5, 'cells': 6, 'rounds': 10},
    hard: {'group': 'memory', 'grid': 6, 'cells': 9, 'rounds': 12},
  ),
  _TemplateSpec(
    template: 'odd_one_out',
    noun: 'Odd One Out',
    category: GameCategory.mind,
    easy: {'group': 'memory', 'items': 6, 'rounds': 8},
    medium: {'group': 'memory', 'items': 9, 'rounds': 10},
    hard: {'group': 'memory', 'items': 12, 'rounds': 12},
  ),
];

class _TriviaSpec {
  const _TriviaSpec(this.qset, this.displayName);
  final String qset;
  final String displayName;
}

const List<_TriviaSpec> _triviaSets = [
  _TriviaSpec('general', 'General Knowledge'),
  _TriviaSpec('science', 'Science'),
  _TriviaSpec('movies', 'Movies'),
  _TriviaSpec('sports', 'Sports'),
  _TriviaSpec('history', 'History'),
  _TriviaSpec('geography', 'Geography'),
  _TriviaSpec('technology', 'Technology'),
  _TriviaSpec('mixed', 'Mixed'),
];

// (label suffix, timePerQ seconds with 0 = untimed, difficulty)
const List<(String, int, Difficulty)> _triviaModes = [
  ('Classic', 0, Difficulty.easy),
  ('Speed', 20, Difficulty.medium),
  ('Blitz', 12, Difficulty.hard),
];

class CatalogSeeder {
  const CatalogSeeder();

  /// Generates the full built-in catalog (1,398 games).
  static List<GameDefinition> generate() {
    final games = <GameDefinition>[];

    for (final t in _templates) {
      for (final palette in kPalettes) {
        for (final d in Difficulty.values) {
          final config = switch (d) {
            Difficulty.easy => t.easy,
            Difficulty.medium => t.medium,
            Difficulty.hard => t.hard,
          };
          final suffix = switch (d) {
            Difficulty.easy => '',
            Difficulty.medium => ' Plus',
            Difficulty.hard => ' Turbo',
          };
          final id = '${t.template}_${palette.id}_${d.name}';
          games.add(GameDefinition(
            id: id,
            title: '${palette.name} ${t.noun}$suffix',
            category: t.category,
            template: t.template,
            difficulty: d,
            themeId: palette.id,
            config: config,
            popularity: stableHash(id) % 1000,
            isNew: stableHash('new:$id') % 100 < 5,
          ));
        }
      }
    }

    // Trivia: 8 question sets × 3 modes × 2 lengths.
    for (final set in _triviaSets) {
      for (final (modeLabel, timePerQ, difficulty) in _triviaModes) {
        for (final (count, countLabel) in [(10, ''), (20, ' Marathon')]) {
          final palette = kPalettes[stableHash('${set.qset}$modeLabel$count') % kPalettes.length];
          final id = 'trivia_${set.qset}_${difficulty.name}'
              '${count == 20 ? '_m' : ''}';
          games.add(GameDefinition(
            id: id,
            title: '${set.displayName} $modeLabel$countLabel',
            category: GameCategory.trivia,
            template: 'trivia',
            difficulty: difficulty,
            themeId: palette.id,
            config: {'qset': set.qset, 'count': count, 'timePerQ': timePerQ},
            popularity: stableHash(id) % 1000,
            isNew: stableHash('new:$id') % 100 < 5,
          ));
        }
      }
    }

    assert(games.length >= 1000, 'Catalog must contain 1000+ games');
    return games;
  }
}

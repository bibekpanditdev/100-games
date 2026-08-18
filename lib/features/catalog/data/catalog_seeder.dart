/// Optimized production catalog generator.
///
/// Implements "Levels" for every game engine to provide a sense of 
/// progression and depth. Removes repetitive variations.
library;

import '../../../core/utils/formatters.dart';
import '../domain/game_definition.dart';

class _TemplateSpec {
  const _TemplateSpec({
    required this.template,
    required this.noun,
    required this.category,
    required this.baseConfig,
  });

  final String template;
  final String noun;
  final GameCategory category;
  final Map<String, dynamic> baseConfig;
}

const List<_TemplateSpec> _templates = [
  _TemplateSpec(
    template: 'snake', noun: 'Snake', category: GameCategory.arcade,
    baseConfig: {'grid': 16, 'speed': 5.0, 'wrap': true},
  ),
  _TemplateSpec(
    template: 'breakout', noun: 'Breaker', category: GameCategory.arcade,
    baseConfig: {'rows': 4, 'speed': 200.0, 'lives': 3},
  ),
  _TemplateSpec(
    template: 'dodge_runner', noun: 'Racer', category: GameCategory.arcade,
    baseConfig: {'lanes': 3, 'speed': 180.0, 'targetSec': 30},
  ),
  _TemplateSpec(
    template: 'color_match', noun: 'Burst', category: GameCategory.arcade,
    baseConfig: {'speed': 1.2},
  ),
  _TemplateSpec(
    template: 'quick_tap', noun: 'Tap', category: GameCategory.arcade,
    baseConfig: {'speed': 1.2},
  ),
  _TemplateSpec(
    template: 'match3', noun: 'Jewel', category: GameCategory.puzzle,
    baseConfig: {'cols': 7, 'rows': 7, 'moves': 20, 'target': 2500},
  ),
  _TemplateSpec(
    template: 'sudoku', noun: 'Sudoku', category: GameCategory.mind,
    baseConfig: {'group': 'logic', 'clues': 50},
  ),
  _TemplateSpec(
    template: 'merge2048', noun: '2048', category: GameCategory.mind,
    baseConfig: {'group': 'math', 'target': 512},
  ),
  _TemplateSpec(
    template: 'tic_tac_toe', noun: 'Tic-Tac-Toe', category: GameCategory.board,
    baseConfig: {'aiLevel': 1},
  ),
  _TemplateSpec(
    template: 'higher_lower', noun: 'Hi-Lo', category: GameCategory.cards,
    baseConfig: {'rounds': 10},
  ),
  _TemplateSpec(
    template: 'simon', noun: 'Memory', category: GameCategory.mind,
    baseConfig: {'group': 'memory', 'startLength': 3, 'stepMs': 600},
  ),
  _TemplateSpec(
    template: 'pattern_recall', noun: 'Recall', category: GameCategory.mind,
    baseConfig: {'group': 'memory', 'grid': 4, 'cells': 4, 'rounds': 8},
  ),
  _TemplateSpec(
    template: 'minesweeper', noun: 'Mines', category: GameCategory.mind,
    baseConfig: {'group': 'logic', 'size': 8, 'mines': 10},
  ),
  _TemplateSpec(
    template: 'cloud_glider', noun: 'Cloud Glider', category: GameCategory.arcade,
    baseConfig: {'speed': 1.0},
  ),
];

class CatalogSeeder {
  const CatalogSeeder();

  static List<GameDefinition> generate() {
    final games = <GameDefinition>[];
    final List<String> distinctPalettes = ['classic', 'cream', 'soft_blue', 'mint', 'ivory', 'slate'];

    for (var i = 0; i < _templates.length; i++) {
      final t = _templates[i];
      final paletteId = distinctPalettes[i % distinctPalettes.length];
      
      // Generate 12 Levels for each game template.
      for (var level = 1; level <= 12; level++) {
        final difficulty = level <= 4 ? Difficulty.easy : (level <= 8 ? Difficulty.medium : Difficulty.hard);
        
        // Scale config by level to make it harder.
        final config = Map<String, dynamic>.from(t.baseConfig);
        _scaleConfig(t.template, config, level);

        final id = '${t.template}_lvl_$level';
        games.add(GameDefinition(
          id: id,
          title: '${t.noun} Level $level',
          category: t.category,
          template: t.template,
          difficulty: difficulty,
          themeId: paletteId,
          level: level,
          config: config,
          popularity: 1000 - (level * 50) + (stableHash(id) % 100),
          isNew: level == 1,
        ));
      }
    }

    return games;
  }

  static void _scaleConfig(String template, Map<String, dynamic> config, int level) {
    final multiplier = 1.0 + (level - 1) * 0.20; 
    
    switch (template) {
      case 'snake':
        config['speed'] = 5.0 * multiplier;
        if (level > 4) config['wrap'] = false;
        break;
      case 'breakout':
        config['speed'] = 200.0 * multiplier;
        config['rows'] = 4 + (level ~/ 3);
        break;
      case 'dodge_runner':
        config['speed'] = 180.0 * multiplier;
        if (level > 6) config['lanes'] = 4;
        break;
      case 'merge2048':
        config['target'] = (level <= 3) ? 512 : (level <= 6 ? 1024 : (level <= 9 ? 2048 : 4096));
        break;
      case 'sudoku':
        config['clues'] = (55 - level * 3).clamp(17, 55);
        break;
      case 'match3':
        config['target'] = ((config['target'] as int) * multiplier).round();
        break;
      case 'tic_tac_toe':
        config['aiLevel'] = level == 1 ? 1 : (level == 2 ? 2 : 3);
        break;
      case 'higher_lower':
        config['rounds'] = 10 + (level * 2);
        break;
      case 'simon':
        config['stepMs'] = (600 - level * 50).clamp(200, 600);
        break;
      case 'pattern_recall':
        config['cells'] = 4 + (level ~/ 2);
        config['grid'] = 4 + (level ~/ 4);
        break;
      case 'minesweeper':
        config['size'] = 8 + (level ~/ 4);
        config['mines'] = (10 + level * 2).clamp(10, 40);
        break;
      case 'cloud_glider':
        config['speed'] = 1.0 + (level * 0.1);
        break;
    }
  }
}

/// Template registry: maps manifest `template` ids to engine instances.
///
/// Engines are aggregated per category — adding a new engine means
/// implementing [GameEngine] and appending it to the matching category
/// registrar (see docs/ADDING_A_GAME.md).
library;

import '../games/arcade/arcade_engines.dart';
import '../games/board/board_engines.dart';
import '../games/cards/cards_engines.dart';
import '../games/mind/logic_math_spatial_engines.dart';
import '../games/mind/word_memory_engines.dart';
import '../games/puzzle/puzzle_engines.dart';
import '../games/trivia/trivia_engines.dart';
import 'game_contracts.dart';

final List<GameEngine> allEngines = [
  ...buildArcadeEngines(),
  ...buildPuzzleEngines(),
  ...buildCardsEngines(),
  ...buildBoardEngines(),
  ...buildTriviaEngines(),
  ...buildLogicMathSpatialEngines(),
  ...buildWordMemoryEngines(),
];

final Map<String, GameEngine> _byTemplate = {
  for (final e in allEngines) e.templateId: e,
};

/// All template ids that can appear in manifests.
Set<String> get knownTemplates => _byTemplate.keys.toSet();

/// Looks up an engine; null for unknown templates (custom manifests
/// referencing a missing template show a friendly error card instead of
/// crashing).
GameEngine? engineFor(String template) => _byTemplate[template];

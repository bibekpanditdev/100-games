/// Aggregates every puzzle-category game engine for the engine registry.
library;

import '../../game_player/game_contracts.dart';
import 'block_fall/block_fall_engine.dart';
import 'match3/match3_engine.dart';
import 'sliding_puzzle/sliding_puzzle_engine.dart';
import 'word_search/word_search_engine.dart';

/// All puzzle game engines (match 3, sliding puzzle, block fall,
/// word search).
List<GameEngine> buildPuzzleEngines() => const [
      Match3Engine(),
      SlidingPuzzleEngine(),
      BlockFallEngine(),
      WordSearchEngine(),
    ];

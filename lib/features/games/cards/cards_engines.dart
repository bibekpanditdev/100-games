/// Aggregates every cards-category game engine for the engine registry.
library;

import '../../game_player/game_contracts.dart';
import 'blackjack/blackjack_engine.dart';
import 'higher_lower/higher_lower_engine.dart';
import 'memory_match/memory_match_engine.dart';

/// All cards game engines (memory match, higher or lower, blackjack).
List<GameEngine> buildCardsEngines() => const [
      MemoryMatchEngine(),
      HigherLowerEngine(),
      BlackjackEngine(),
    ];

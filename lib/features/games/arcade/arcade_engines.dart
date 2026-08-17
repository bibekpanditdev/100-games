/// Aggregates every arcade-category game engine for the engine registry.
library;

import '../../game_player/game_contracts.dart';
import 'breakout/breakout_engine.dart';
import 'dodge_runner/dodge_runner_engine.dart';
import 'snake/snake_engine.dart';
import 'tap_reflex/tap_reflex_engine.dart';
import 'whack_a_mole/whack_a_mole_engine.dart';

/// Builds the engines contributed by the arcade template family.
List<GameEngine> buildArcadeEngines() => const [
      SnakeEngine(),
      BreakoutEngine(),
      WhackAMoleEngine(),
      TapReflexEngine(),
      DodgeRunnerEngine(),
    ];

/// Registrar for the trivia game family.
library;

import '../../game_player/game_contracts.dart';
import 'trivia_engine.dart';

/// Builds the engines contributed by the trivia template family.
List<GameEngine> buildTriviaEngines() => [const TriviaEngine()];

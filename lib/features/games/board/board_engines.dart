/// Aggregates every board-category game engine for the engine registry.
library;

import '../../game_player/game_contracts.dart';
import 'connect_four/connect_four_engine.dart';
import 'dots_and_boxes/dots_and_boxes_engine.dart';
import 'tic_tac_toe/tic_tac_toe_engine.dart';

/// All board game engines (tic-tac-toe, connect four, dots and boxes).
List<GameEngine> buildBoardEngines() => const [
      TicTacToeEngine(),
      ConnectFourEngine(),
      DotsAndBoxesEngine(),
    ];

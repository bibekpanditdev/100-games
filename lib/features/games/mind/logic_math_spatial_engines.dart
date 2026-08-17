/// Mind-module engines: logic / math / spatial groups.
library;

import '../../game_player/game_contracts.dart';
import 'sudoku/sudoku_engine.dart';
import 'minesweeper/minesweeper_engine.dart';
import 'merge2048/merge2048_engine.dart';
import 'math_sprint/math_sprint_engine.dart';
import 'maze/maze_engine.dart';
import 'pipes/pipes_engine.dart';

/// Builds the logic/math/spatial mind-game engines.
List<GameEngine> buildLogicMathSpatialEngines() => const [
      SudokuEngine(),
      MinesweeperEngine(),
      Merge2048Engine(),
      MathSprintEngine(),
      MazeEngine(),
      PipesEngine(),
    ];

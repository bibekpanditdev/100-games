/// Mind-module engines: word / memory / match groups.
library;

import '../../game_player/game_contracts.dart';
import 'hangman/hangman_engine.dart';
import 'wordle_daily/wordle_daily_engine.dart';
import 'simon/simon_engine.dart';
import 'pattern_recall/pattern_recall_engine.dart';
import 'odd_one_out/odd_one_out_engine.dart';

/// Builds the word/memory/match mind-game engines.
List<GameEngine> buildWordMemoryEngines() => const [
      HangmanEngine(),
      WordleDailyEngine(),
      SimonEngine(),
      PatternRecallEngine(),
      OddOneOutEngine(),
    ];

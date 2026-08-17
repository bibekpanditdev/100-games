/// Central score → stars / coins conversion. Shared by every engine so the
/// economy stays balanced across all 1000+ games.
library;

import '../catalog/domain/game_definition.dart';

abstract final class Scoring {
  static const Map<Difficulty, int> _difficultyBonus = {
    Difficulty.easy: 0,
    Difficulty.medium: 15,
    Difficulty.hard: 35,
  };

  /// Coins earned for finishing a session (always >= 5 so every play pays).
  static int coinsFor({
    required int score,
    required bool won,
    required Difficulty difficulty,
  }) {
    final base = 10 + (score / 25).floor() + (won ? 20 : 0) + _difficultyBonus[difficulty]!;
    return base.clamp(5, 200);
  }

  /// 0–3 stars.
  ///  * 3 — clear win with a strong result (target beaten by 25%+)
  ///  * 2 — win
  ///  * 1 — loss with a non-zero score
  ///  * 0 — loss with nothing on the board
  /// A "win" for achievements/leaderboards is `stars >= 2`.
  static int starsFor({
    required int score,
    required bool won,
    required Difficulty difficulty,
    int? target,
  }) {
    if (won) {
      if (target != null && score >= target * 1.25) return 3;
      if (target == null) {
        final strong = switch (difficulty) {
          Difficulty.easy => 600,
          Difficulty.medium => 1000,
          Difficulty.hard => 1500,
        };
        if (score >= strong) return 3;
      }
      return 2;
    }
    return score > 0 ? 1 : 0;
  }
}

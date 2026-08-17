/// Optional adaptive difficulty (add-on spec §3): a tiny on-device
/// heuristic over recent per-template stars. No ML, no network — recent
/// strong results suggest stepping up; weak results suggest easing down.
library;

import '../catalog/domain/game_definition.dart';

abstract final class AdaptiveDifficulty {
  /// Minimum games before a suggestion is offered.
  static const int minHistory = 3;

  /// Suggests the next difficulty tier from recent star results (0–3
  /// each, most recent LAST). Returns null when there isn't enough
  /// history to judge.
  static Difficulty? suggest(List<int> recentStars) {
    if (recentStars.length < minHistory) return null;
    final window = recentStars.length >= 5
        ? recentStars.sublist(recentStars.length - 5)
        : recentStars;
    final avg = window.reduce((a, b) => a + b) / window.length;
    if (avg >= 2.5) return Difficulty.hard;
    if (avg >= 1.0) return Difficulty.medium;
    return Difficulty.easy;
  }
}

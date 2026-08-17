/// Data passed to the results screen after a session ends.
library;

import '../catalog/domain/game_definition.dart';
import '../gamification/achievements/achievement_definitions.dart';
import 'game_contracts.dart';

class ResultsPayload {
  const ResultsPayload({
    required this.definition,
    required this.outcome,
    required this.stars,
    required this.coinsEarned,
    required this.previousBest,
    required this.newAchievements,
  });

  final GameDefinition definition;
  final GameOutcome outcome;
  final int stars;
  final int coinsEarned;

  /// Personal best before this run (null if first run). "New best!" badge
  /// is shown when this run beat it.
  final int? previousBest;

  final List<AchievementDef> newAchievements;

  bool get newBest => previousBest != null && outcome.score > previousBest!;
}

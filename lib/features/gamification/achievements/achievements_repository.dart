/// Achievements persistence + evaluation engine (SQLite-backed).
library;

import 'package:sqflite/sqflite.dart';

import '../progress_controller.dart';
import '../../catalog/domain/game_definition.dart';
import '../../leaderboards/scores_repository.dart';
import 'achievement_definitions.dart';

class AchievementState {
  const AchievementState({required this.id, required this.progress, this.unlockedAt});

  final String id;
  final int progress;
  final DateTime? unlockedAt;

  bool get unlocked => unlockedAt != null;
}

class AchievementsRepository {
  AchievementsRepository(this._db);

  final Database _db;

  Future<Map<String, AchievementState>> loadAll() async {
    final rows = await _db.query('achievements');
    return {
      for (final r in rows)
        r['id']! as String: AchievementState(
          id: r['id']! as String,
          progress: r['progress']! as int,
          unlockedAt: r['unlocked_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(r['unlocked_at']! as int),
        ),
    };
  }

  /// Applies a finished session. Returns the achievements it unlocked.
  Future<List<AchievementDef>> applyResult(GameplaySnapshot snapshot) async {
    final states = await loadAll();
    final newlyUnlocked = <AchievementDef>[];
    final batch = _db.batch();

    for (final def in kAchievements) {
      final value = def.extract(snapshot);
      final current = states[def.id];
      final best = current == null || value > current.progress ? value : current.progress;
      final wasUnlocked = current?.unlocked ?? false;
      final nowUnlocked = best >= def.target;

      if (current == null || best != current.progress || nowUnlocked != wasUnlocked) {
        batch.insert(
          'achievements',
          {
            'id': def.id,
            'progress': best,
            'unlocked_at': nowUnlocked
                ? (current?.unlockedAt ?? DateTime.now().millisecondsSinceEpoch)
                : null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (nowUnlocked && !wasUnlocked) newlyUnlocked.add(def);
      }
    }

    await batch.commit(noResult: true);
    return newlyUnlocked;
  }

  Future<void> resetAll() async {
    await _db.delete('achievements');
  }
}

/// Minimal description of one finished session, used to build a full
/// [GameplaySnapshot].
class GameResultInput {
  const GameResultInput({
    required this.category,
    required this.template,
    required this.won,
    required this.score,
    required this.stars,
    this.stats = const {},
  });

  final GameCategory category;
  final String template;
  final bool won;
  final int score;
  final int stars;
  final Map<String, int> stats;
}

/// Builds snapshots from the other local stores and applies achievements.
class AchievementsService {
  AchievementsService({
    required this.repository,
    required this.scores,
    required this.progress,
    required this.db,
  });

  final AchievementsRepository repository;
  final ScoresRepository scores;
  final ProgressController progress;
  final Database db;

  Future<GameplaySnapshot> _buildSnapshot(GameResultInput input) async {
    final winsPerCategory = await scores.winsPerCategoryRaw();
    final templateWins = await scores.winsPerTemplateRaw();
    final brainRows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM brain_scores WHERE completed >= 5',
    );
    final brainDays = brainRows.isNotEmpty && brainRows.first['c'] is int
        ? brainRows.first['c']! as int
        : 0;
    return GameplaySnapshot(
      category: input.category,
      template: input.template,
      won: input.won,
      score: input.score,
      stars: input.stars,
      stats: input.stats,
      totalPlays: await scores.totalPlays(),
      totalWins: await scores.totalWins(),
      coinsEarnedTotal: progress.coinsEarnedTotal,
      streakDays: progress.streakDays,
      distinctGamesPlayed: await scores.distinctGamesPlayed(),
      categoryWins: winsPerCategory,
      templateWins: templateWins,
      brainTrainingDays: brainDays,
    );
  }

  /// Records a finished session and returns the achievements it unlocked.
  Future<List<AchievementDef>> applyAndCollectUnlocked(GameResultInput input) async {
    final snapshot = await _buildSnapshot(input);
    return repository.applyResult(snapshot);
  }

  Future<void> resetAll() => repository.resetAll();
}

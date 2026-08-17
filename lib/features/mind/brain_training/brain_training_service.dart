/// Daily Brain Training — a deterministic per-day routine of five mind
/// games (one per subcategory: logic / word / memory / math / spatial),
/// scored into a composite local "Brain Score" with history + streak.
/// Everything is computed on-device; zero network.
library;

import 'package:sqflite/sqflite.dart';

import '../../../core/utils/formatters.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/game_definition.dart';

/// Mind-game subcategories (the `group` config key on mind manifests).
abstract final class MindGroups {
  static const logic = 'logic';
  static const word = 'word';
  static const memory = 'memory';
  static const math = 'math';
  static const spatial = 'spatial';

  static const List<String> all = [logic, word, memory, math, spatial];

  static String label(String group) => switch (group) {
        logic => 'Logic',
        word => 'Word',
        memory => 'Memory',
        math => 'Math',
        spatial => 'Spatial',
        _ => 'Mind',
      };
}

class RoutineGame {
  const RoutineGame({required this.definition, required this.group});

  final GameDefinition definition;
  final String group;
}

class DailyRoutine {
  const DailyRoutine({required this.day, required this.games});

  final String day;
  final List<RoutineGame> games;
}

class RoutineGameResult {
  const RoutineGameResult({required this.score, required this.stars});

  final int score;
  final int stars;
}

class RoutineProgress {
  const RoutineProgress({
    required this.routine,
    required this.results,
    required this.brainScore,
    required this.complete,
  });

  final DailyRoutine routine;

  /// Best result today per game id.
  final Map<String, RoutineGameResult> results;

  /// Composite score so far (0..~4750).
  final int brainScore;

  /// True when every routine game has a result today.
  final bool complete;

  int get completedCount => results.length;
  int get total => routine.games.length;
}

class BrainScoreDay {
  const BrainScoreDay({required this.day, required this.score, required this.completed});

  final String day;
  final int score;
  final int completed;
}

class BrainTrainingService {
  BrainTrainingService({required Database db, required CatalogRepository catalog})
      : _db = db,
        _catalog = catalog;

  final Database _db;
  final CatalogRepository _catalog;

  /// Deterministic routine: one game per subcategory, stable for the day.
  Future<DailyRoutine> routineFor(DateTime date) async {
    final day = dayKey(date);
    final games = await _catalog.all();
    final mindGames = games.where((g) => g.category == GameCategory.mind).toList();

    final picks = <RoutineGame>[];
    for (final group in MindGroups.all) {
      final pool = mindGames.where((g) => g.config['group'] == group).toList();
      if (pool.isEmpty) continue;
      final pick = pool[stableHash('bt:$group:$day') % pool.length];
      picks.add(RoutineGame(definition: pick, group: group));
    }
    return DailyRoutine(day: day, games: picks);
  }

  /// Today's progress: best result per routine game + composite score.
  Future<RoutineProgress> progressFor(DateTime date) async {
    final routine = await routineFor(date);
    final startMs = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final endMs = startMs + 24 * 3600 * 1000 - 1;
    final ids = routine.games.map((g) => g.definition.id).toList();

    final results = <String, RoutineGameResult>{};
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(',');
      final rows = await _db.rawQuery(
        'SELECT game_id, MAX(score) AS best, MAX(stars) AS stars FROM scores '
        'WHERE played_at BETWEEN ? AND ? AND game_id IN ($placeholders) '
        'GROUP BY game_id',
        [startMs, endMs, ...ids],
      );
      for (final r in rows) {
        results[r['game_id']! as String] = RoutineGameResult(
          score: r['best']! as int,
          stars: r['stars']! as int,
        );
      }
    }

    var total = 0;
    for (final g in routine.games) {
      final r = results[g.definition.id];
      if (r != null) total += _points(r);
    }
    return RoutineProgress(
      routine: routine,
      results: results,
      brainScore: total,
      complete: routine.games.isNotEmpty && results.length == routine.games.length,
    );
  }

  /// Points for one game: capped score + star bonus (max 950 per game).
  int _points(RoutineGameResult r) =>
      (r.score.clamp(0, 1000) ~/ 10) + r.stars * 150;

  /// Upserts today's brain_scores row from current progress. Called after
  /// any finished game; cheap and idempotent.
  Future<void> refreshDay(DateTime date) async {
    final progress = await progressFor(date);
    final day = dayKey(date);
    await _db.insert(
      'brain_scores',
      {
        'day': day,
        'score': progress.brainScore,
        'completed': progress.completedCount,
        'details': '{}',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Most-recent-first history of recorded days.
  Future<List<BrainScoreDay>> history({int limit = 60}) async {
    final rows = await _db.query(
      'brain_scores',
      orderBy: 'day DESC',
      limit: limit,
    );
    return [
      for (final r in rows)
        BrainScoreDay(
          day: r['day']! as String,
          score: r['score']! as int,
          completed: r['completed']! as int,
        ),
    ];
  }

  /// Consecutive recorded days ending today (or yesterday, so the streak
  /// doesn't read zero during the day before playing). [now] injectable
  /// for tests.
  int historyStreak(List<BrainScoreDay> days, {DateTime? now}) {
    if (days.isEmpty) return 0;
    final set = days.map((d) => d.day).toSet();
    final today = dayKey(now ?? DateTime.now());
    var cursor = set.contains(today) ? today : previousDayKey(today);
    if (!set.contains(cursor)) return 0;
    var streak = 0;
    while (set.contains(cursor)) {
      streak++;
      cursor = previousDayKey(cursor);
    }
    return streak;
  }
}

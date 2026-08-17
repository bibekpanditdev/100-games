/// Local leaderboard persistence (SQLite). Fully offline; syncs to Google
/// Play Games opportunistically via PlayGamesService when the player has
/// signed in and is online.
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/storage/app_database.dart';
import '../catalog/domain/game_definition.dart';

class ScoreEntry {
  const ScoreEntry({
    required this.gameId,
    required this.gameTitle,
    required this.category,
    required this.score,
    required this.stars,
    required this.playedAt,
  });

  final String gameId;
  final String gameTitle;
  final GameCategory category;
  final int score;
  final int stars;
  final DateTime playedAt;
}

class ScoresRepository {
  ScoresRepository(this._db);

  final Database _db;

  Future<void> record({
    required GameDefinition game,
    required int score,
    required int stars,
  }) async {
    await _db.insert('scores', {
      'game_id': game.id,
      'category': game.category.name,
      'score': score,
      'stars': stars,
      'played_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Personal best for one game, or null.
  Future<ScoreEntry?> bestForGame(String gameId) async {
    final rows = await _db.rawQuery('''
      SELECT s.*, g.title AS title FROM scores s
      JOIN games g ON g.id = s.game_id
      WHERE s.game_id = ?
      ORDER BY s.score DESC LIMIT 1
    ''', [gameId]);
    return rows.isEmpty ? null : _rowToEntry(rows.first);
  }

  /// Top personal bests per game within a category ([category] null = all).
  Future<List<ScoreEntry>> topForCategory(GameCategory? category, {int limit = 50}) async {
    final where = category == null ? '' : 'WHERE s.category = ?';
    final args = category == null ? <Object?>[] : [category.name];
    final rows = await _db.rawQuery('''
      SELECT s.*, g.title AS title FROM scores s
      JOIN games g ON g.id = s.game_id
      $where
      GROUP BY s.game_id
      ORDER BY MAX(s.score) DESC
      LIMIT ?
    ''', [...args, limit]);
    return rows.map(_rowToEntry).toList();
  }

  /// Games played at least once (for stats / achievement snapshot).
  Future<int> distinctGamesPlayed() async {
    final rows = await _db.rawQuery('SELECT COUNT(DISTINCT game_id) AS c FROM scores');
    final v = rows.isNotEmpty ? rows.first['c'] : null;
    return v is int ? v : 0;
  }

  Future<int> totalPlays() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM scores');
    final v = rows.isNotEmpty ? rows.first['c'] : null;
    return v is int ? v : 0;
  }

  Future<int> totalWins() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM scores WHERE stars >= 2');
    final v = rows.isNotEmpty ? rows.first['c'] : null;
    return v is int ? v : 0;
  }

  /// Wins (stars >= 2) per category name, e.g. `{'puzzle': 12}`.
  Future<Map<String, int>> winsPerCategoryRaw() async {
    final rows = await _db.rawQuery(
      "SELECT category, COUNT(*) AS c FROM scores WHERE stars >= 2 GROUP BY category",
    );
    return {
      for (final r in rows) r['category']! as String: r['c']! as int,
    };
  }

  /// Wins (stars >= 2) per engine template, e.g. `{'sudoku': 7}` — powers
  /// template-specific achievements ("Solve 10 Sudoku puzzles").
  Future<Map<String, int>> winsPerTemplateRaw() async {
    final rows = await _db.rawQuery('''
      SELECT g.template AS template, COUNT(*) AS c
      FROM scores s JOIN games g ON g.id = s.game_id
      WHERE s.stars >= 2
      GROUP BY g.template
    ''');
    return {
      for (final r in rows) r['template']! as String: r['c']! as int,
    };
  }

  /// Top personal bests within one mind-game subcategory (logic / word /
  /// memory / math / spatial) — per-subcategory leaderboards per the
  /// add-on spec §6. [group] null = all mind games.
  Future<List<ScoreEntry>> topForMindGroup(String? group, {int limit = 50}) async {
    var rows = await _db.rawQuery('''
      SELECT s.*, g.title AS title, g.config AS config FROM scores s
      JOIN games g ON g.id = s.game_id
      WHERE s.category = 'mind'
      GROUP BY s.game_id
      ORDER BY MAX(s.score) DESC
    ''');
    if (group != null) {
      rows = rows.where((r) {
        try {
          final config = jsonDecode(r['config']! as String) as Map<String, dynamic>;
          return config['group'] == group;
        } catch (_) {
          return false;
        }
      }).toList();
    }
    return rows.take(limit).map(_rowToEntry).toList();
  }

  Future<void> resetAll() async {
    await _db.delete('scores');
  }

  ScoreEntry _rowToEntry(Map<String, Object?> row) => ScoreEntry(
        gameId: row['game_id']! as String,
        gameTitle: (row['title'] as String?) ?? row['game_id']! as String,
        category: GameCategory.fromString(row['category']! as String),
        score: row['score']! as int,
        stars: row['stars']! as int,
        playedAt: DateTime.fromMillisecondsSinceEpoch(row['played_at']! as int),
      );
}

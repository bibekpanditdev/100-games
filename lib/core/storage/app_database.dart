/// SQLite database (sqflite) — catalog, scores, achievements progress and
/// the offline analytics event queue. All app data lives on-device; the app
/// never requires connectivity.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  /// Opens (or creates) the app database. Pass [path] ':memory:' in tests.
  static Future<AppDatabase> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'thousand_games.db');
    final database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(database);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS brain_scores (
          day TEXT PRIMARY KEY,
          score INTEGER NOT NULL,
          completed INTEGER NOT NULL,
          details TEXT NOT NULL DEFAULT '{}'
        )
      ''');
    }
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE games (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        template TEXT NOT NULL,
        difficulty TEXT NOT NULL,
        theme TEXT NOT NULL,
        config TEXT NOT NULL,
        unlocked INTEGER NOT NULL DEFAULT 1,
        popularity INTEGER NOT NULL DEFAULT 0,
        is_new INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE scores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        game_id TEXT NOT NULL,
        category TEXT NOT NULL,
        score INTEGER NOT NULL,
        stars INTEGER NOT NULL,
        played_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_scores_game ON scores(game_id)');
    batch.execute('CREATE INDEX idx_scores_category ON scores(category)');
    batch.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        progress INTEGER NOT NULL DEFAULT 0,
        unlocked_at INTEGER
      )
    ''');
    batch.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ts INTEGER NOT NULL,
        params TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    batch.execute('''
      CREATE TABLE brain_scores (
        day TEXT PRIMARY KEY,
        score INTEGER NOT NULL,
        completed INTEGER NOT NULL,
        details TEXT NOT NULL DEFAULT '{}'
      )
    ''');
    await batch.commit(noResult: true);
  }
}

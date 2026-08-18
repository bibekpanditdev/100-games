/// Catalog data source: seeds the built-in catalog into SQLite on first
/// launch and merges user-supplied entries from
/// `assets/manifests/custom_games.json` (add games without code changes).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

import '../domain/game_definition.dart';
import 'catalog_seeder.dart';

class CatalogRepository {
  CatalogRepository(this._db);

  final Database _db;

  bool _seeded = false;

  /// Seeds built-ins + merges the custom manifest. Idempotent and cheap
  /// after the first run.
  Future<void> ensureSeeded() async {
    if (_seeded) return;
    final count = Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM games'),
        ) ??
        0;

    if (count == 0) {
      final batch = _db.batch();
      for (final g in CatalogSeeder.generate()) {
        _insert(batch, g);
      }
      await batch.commit(noResult: true);
    }

    await mergeCustomManifest();
    _seeded = true;
  }

  void _insert(Batch batch, GameDefinition g) {
    batch.insert(
      'games',
      {
        'id': g.id,
        'title': g.title,
        'category': g.category.name,
        'template': g.template,
        'difficulty': g.difficulty.name,
        'theme': g.themeId,
        'config': jsonEncode(g.config.raw),
        'unlocked': g.unlocked ? 1 : 0,
        'popularity': g.popularity,
        'is_new': g.isNew ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Merges `assets/manifests/custom_games.json`. Entries with an unknown/
  /// missing template or id are skipped safely — a bad manifest can never
  /// break the catalog.
  Future<void> mergeCustomManifest() async {
    try {
      final raw = await rootBundle.loadString('assets/manifests/custom_games.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      final entries = decoded['games'];
      if (entries is! List) return;

      final batch = _db.batch();
      for (final e in entries) {
        if (e is! Map<String, dynamic>) continue;
        final id = e['id'];
        final template = e['template'];
        if (id is! String || id.isEmpty || template is! String || template.isEmpty) {
          continue;
        }
        final def = GameDefinition.fromJson(e);
        _insert(batch, def);
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // Missing/corrupt custom manifest is never fatal.
    }
  }

  GameDefinition _rowToDef(Map<String, Object?> row) => GameDefinition(
        id: row['id']! as String,
        title: row['title']! as String,
        category: GameCategory.fromString(row['category']! as String),
        template: row['template']! as String,
        difficulty: Difficulty.fromString(row['difficulty']! as String),
        themeId: row['theme']! as String,
        config: GameConfig(jsonDecode(row['config']! as String) as Map<String, dynamic>),
        unlocked: (row['unlocked']! as int) == 1,
        popularity: row['popularity']! as int,
        isNew: (row['is_new']! as int) == 1,
      );

  Future<List<GameDefinition>> all() async {
    await ensureSeeded();
    final rows = await _db.query('games', orderBy: 'title COLLATE NOCASE');
    return rows.map(_rowToDef).toList();
  }

  Future<GameDefinition?> byId(String id) async {
    await ensureSeeded();
    final rows = await _db.query('games', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : _rowToDef(rows.first);
  }

  Future<int> count() async {
    await ensureSeeded();
    return Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM games'),
        ) ??
        0;
  }
}

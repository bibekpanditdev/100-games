/// Offline-safe analytics queue.
///
/// Events are written to the local SQLite `events` table and flushed to an
/// attached sink when one is available. The default sink is a no-op logger;
/// the README documents how to attach Firebase Analytics (or any backend)
/// without touching call sites — all calls are fire-and-forget and never
/// block gameplay.
library;

import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

typedef AnalyticsSink = Future<void> Function(String name, Map<String, Object?> params);

class AnalyticsService {
  AnalyticsService(this._db);

  final Database _db;

  AnalyticsSink? _sink;
  bool _flushing = false;

  /// Attach a remote sink (e.g. Firebase Analytics). Events queued while
  /// no sink was attached are flushed on attach.
  void attachSink(AnalyticsSink sink) {
    _sink = sink;
    unawaited(flush());
  }

  /// Fire-and-forget event. Never throws, never blocks.
  Future<void> log(String name, [Map<String, Object?> params = const {}]) async {
    try {
      await _db.insert('events', {
        'name': name,
        'ts': DateTime.now().millisecondsSinceEpoch,
        'params': jsonEncode(params),
      });
    } catch (_) {}
    if (_sink != null) unawaited(flush());
  }

  /// Sends queued events to the attached sink (if any), deleting them on
  /// success. Safe to call repeatedly.
  Future<void> flush() async {
    if (_sink == null || _flushing) return;
    _flushing = true;
    try {
      final rows = await _db.query('events', orderBy: 'id', limit: 200);
      for (final row in rows) {
        try {
          final params = jsonDecode(row['params']! as String);
          await _sink!(row['name']! as String, params is Map<String, Object?> ? params : {});
          await _db.delete('events', where: 'id = ?', whereArgs: [row['id']]);
        } catch (_) {
          // Keep the event for a later flush.
        }
      }
    } finally {
      _flushing = false;
    }
  }
}

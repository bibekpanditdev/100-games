/// Shared test environment: sqflite FFI for SQLite-backed classes and a
/// temp-dir Hive for box-backed controllers.
library;

import 'dart:io';

import 'package:hive/hive.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:game/core/storage/app_database.dart';

bool _ffiInitialized = false;
String? _hiveDir;

void setupTestEnv() {
  if (!_ffiInitialized) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiInitialized = true;
  }
  if (_hiveDir == null) {
    _hiveDir = Directory.systemTemp.createTempSync('tg_hive_test').path;
    Hive.init(_hiveDir!);
  }
}

/// Fresh in-memory SQLite database.
Future<AppDatabase> openTestDb() async {
  setupTestEnv();
  return AppDatabase.open(path: ':memory:');
}

/// Isolated Hive box per call (unique name).
Future<Box> openTestBox(String name) async {
  setupTestEnv();
  final unique = '$name-${DateTime.now().microsecondsSinceEpoch}-'
      '${_counter++}';
  return Hive.openBox(unique);
}

int _counter = 0;

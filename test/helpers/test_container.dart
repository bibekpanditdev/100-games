/// Shared Riverpod container + app pump helper for catalog widget tests.
///
/// Mirrors the overrides from `lib/main.dart`: in-memory SQLite for the
/// catalog/scores repos and isolated Hive boxes for settings/progress.
/// (The boxes must be opened before building the closures — the
/// ChangeNotifierProvider override functions are synchronous.)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/core/theme/app_theme.dart';
import 'package:game/features/catalog/data/catalog_repository.dart';
import 'package:game/features/catalog/presentation/catalog_providers.dart';
import 'package:game/features/gamification/progress_controller.dart';
import 'package:game/features/leaderboards/scores_repository.dart';
import 'package:game/features/settings/settings_controller.dart';

import 'test_env.dart';

/// Builds a [ProviderContainer] over a fresh in-memory catalog DB and
/// isolated Hive boxes. Disposed automatically via [addTearDown].
Future<ProviderContainer> buildTestContainer() async {
  setupTestEnv();
  final db = await openTestDb();
  final settingsBox = await openTestBox('settings');
  final progressBox = await openTestBox('progress');
  final container = ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      catalogRepoProvider.overrideWithValue(CatalogRepository(db.db)),
      scoresRepoProvider.overrideWithValue(ScoresRepository(db.db)),
      settingsProvider.overrideWith((ref) => SettingsController(settingsBox)),
      progressProvider.overrideWith((ref) => ProgressController(progressBox)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps [home] inside a themed MaterialApp wired to [container].
///
/// Pass [onGenerateRoute] to observe/stub named navigation (see
/// `home_screen_test.dart`).
Future<void> pumpCatalogApp(
  WidgetTester tester,
  ProviderContainer container, {
  Widget? home,
  RouteFactory? onGenerateRoute,
}) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildLightTheme(),
        home: home,
        onGenerateRoute: onGenerateRoute,
      ),
    ),
  );
}

/// Minimal route table for navigation tests: any pushed route renders a
/// Scaffold showing `ROUTE_<name>` and records its arguments in [args].
RouteFactory recordRoutes(Map<String, Object?> args) {
  return (settings) {
    args[settings.name ?? ''] = settings.arguments;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(
        body: Center(child: Text('ROUTE_${settings.name}')),
      ),
    );
  };
}

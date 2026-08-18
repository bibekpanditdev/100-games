/// Entry point. Startup order matters for offline-safety:
///  1. Local storage (Hive + SQLite) — must succeed; everything else builds
///     on it.
///  2. Catalog seeding (first launch only).
///  3. Ads SDK init — fire-and-forget; offline devices simply skip ads.
/// The UI never waits on anything network-related.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/routing.dart';
import 'core/services/audio_service.dart';
import 'core/services/feedback.dart';
import 'core/storage/app_database.dart';
import 'features/ads/ads_service.dart';
import 'features/analytics/analytics_service.dart';
import 'features/catalog/data/catalog_repository.dart';
import 'features/catalog/presentation/catalog_providers.dart';
import 'features/gamification/progress_controller.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    // Local storage — the only hard startup dependency.
    await Hive.initFlutter();
    final settingsBox = await Hive.openBox('settings');
    final progressBox = await Hive.openBox('progress');
    final gameStateBox = await Hive.openBox('gamestate');
    final db = await AppDatabase.open();

    final settings = SettingsController(settingsBox);
    final progress = ProgressController(progressBox);
    final catalog = CatalogRepository(db.db);
    await catalog.ensureSeeded();

    AppFeedback.configure(hapticsOn: settings.hapticsOn, soundOn: settings.soundOn);
    MotionSettings.reduced = settings.reducedMotion;

    // Non-blocking, fail-silent.
    AdsService.instance.init();
    AudioService.I.init();

    runApp(
      ProviderScope(
        overrides: [
          dbProvider.overrideWithValue(db),
          // Riverpod disposes created ChangeNotifiers itself — no manual dispose.
          settingsProvider.overrideWith((ref) => settings),
          progressProvider.overrideWith((ref) => progress),
          gameStateBoxProvider.overrideWithValue(gameStateBox),
        ],
        child: const ThousandGamesApp(),
      ),
    );

    AnalyticsService(db.db).log('app_open');
  } catch (e, stack) {
    debugPrint('FATAL STARTUP ERROR: $e\n$stack');
    // Still try to run the app to show an error if possible, 
    // or just let it fail visibly.
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Startup Error: $e')),
      ),
    ));
  }
}

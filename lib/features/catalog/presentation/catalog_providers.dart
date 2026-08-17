/// Riverpod wiring. Storage-backed providers are overridden in `main()`
/// (and in tests) — see `lib/main.dart`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/storage/app_database.dart';
import '../../../core/utils/formatters.dart';
import '../../ads/ads_service.dart';
import '../../analytics/analytics_service.dart';
import '../../gamification/achievements/achievements_repository.dart';
import '../../gamification/progress_controller.dart';
import '../../leaderboards/scores_repository.dart';
import '../../settings/settings_controller.dart';
import '../data/catalog_repository.dart';
import '../domain/game_definition.dart';

final dbProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('dbProvider must be overridden in main()'),
);

final catalogRepoProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(dbProvider).db),
);

final scoresRepoProvider = Provider<ScoresRepository>(
  (ref) => ScoresRepository(ref.watch(dbProvider).db),
);

final achievementsRepoProvider = Provider<AchievementsRepository>(
  (ref) => AchievementsRepository(ref.watch(dbProvider).db),
);

final settingsProvider = ChangeNotifierProvider<SettingsController>(
  (ref) => throw UnimplementedError('settingsProvider must be overridden in main()'),
);

final progressProvider = ChangeNotifierProvider<ProgressController>(
  (ref) => throw UnimplementedError('progressProvider must be overridden in main()'),
);

/// Hive box persisting in-progress boards for long puzzles (save/resume
/// across app restarts). Keyed by game id.
final gameStateBoxProvider = Provider<Box>(
  (ref) => throw UnimplementedError('gameStateBoxProvider must be overridden in main()'),
);

final achievementsServiceProvider = Provider<AchievementsService>(
  (ref) => AchievementsService(
    repository: ref.watch(achievementsRepoProvider),
    scores: ref.watch(scoresRepoProvider),
    progress: ref.watch(progressProvider),
    db: ref.watch(dbProvider).db,
  ),
);

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.watch(dbProvider).db),
);

final adsProvider = Provider<AdsService>((ref) => AdsService.instance);

/// Full catalog, seeded on first watch. UI watches this FutureProvider.
final catalogGamesProvider = FutureProvider<List<GameDefinition>>(
  (ref) => ref.watch(catalogRepoProvider).all(),
);

/// Single game lookup.
final gameByIdProvider = FutureProvider.family<GameDefinition?, String>(
  (ref, id) => ref.watch(catalogRepoProvider).byId(id),
);

/// Personal best for a game (shown on cards / detail).
final gameBestProvider = FutureProvider.family<ScoreEntry?, String>(
  (ref, id) => ref.watch(scoresRepoProvider).bestForGame(id),
);

/// Deterministic per-day "Daily Challenge" pick.
final dailyChallengeProvider = FutureProvider<GameDefinition?>((ref) async {
  final games = await ref.watch(catalogGamesProvider.future);
  if (games.isEmpty) return null;
  final key = dayKey(DateTime.now());
  return games[stableHash('daily:$key') % games.length];
});

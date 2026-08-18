/// Achievements screen: grid over the static [kAchievements] catalog with
/// live local progress from SQLite, plus an optional Google Play Games sync
/// action. Definitions are static, so the grid always renders — an empty
/// store simply shows everything locked at progress 0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feedback.dart';
import '../../../core/services/play_games_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../gamification/achievements/achievement_definitions.dart';
import '../../gamification/achievements/achievements_repository.dart';

/// Persisted achievement progress keyed by definition id.
///
/// Public so the Settings screen's "Reset all progress" can invalidate it.
final achievementStatesProvider =
    FutureProvider<Map<String, AchievementState>>(
  (ref) => ref.watch(achievementsRepoProvider).loadAll(),
);

/// Local achievement catalog with unlock counts and progress bars.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final states = ref.watch(achievementStatesProvider);
    final statesMap =
        states.valueOrNull ?? const <String, AchievementState>{};
    final unlocked = statesMap.values.where((s) => s.unlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Achievements'),
            Text(
              '$unlocked of ${kAchievements.length} unlocked',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Google Play Games achievements',
            onPressed: () => _openPlayGames(context),
            icon: const Icon(Icons.sports_esports_outlined),
          ),
        ],
      ),
      body: states.when(
        loading: () => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: _gridDelegate,
          itemCount: 6,
          itemBuilder: (_, __) =>
              const SkeletonBox(height: double.infinity, radius: 14),
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load achievements",
          message: 'Something went wrong reading local progress. ($error)',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(achievementStatesProvider),
        ),
        data: (map) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: _gridDelegate,
          itemCount: kAchievements.length,
          itemBuilder: (context, index) => _AchievementCard(
            definition: kAchievements[index],
            state: map[kAchievements[index].id],
          ),
        ),
      ),
    );
  }

  static const SliverGridDelegateWithFixedCrossAxisCount _gridDelegate =
      SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    mainAxisExtent: 192,
  );

  /// Opens the native Play Games achievements UI, signing in first when
  /// needed. Offline devices just get a friendly snackbar — never a crash.
  Future<void> _openPlayGames(BuildContext context) async {
    AppFeedback.tap();
    try {
      if (!PlayGamesService.instance.signedIn) {
        final signedIn = await PlayGamesService.instance.signIn();
        if (!context.mounted) return;
        if (!signedIn) {
          _snack(context, 'Sign-in unavailable offline');
          return;
        }
      }
      await PlayGamesService.instance.showAchievements();
    } catch (_) {
      if (context.mounted) _snack(context, 'Sign-in unavailable offline');
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// One achievement cell: icon, title, description, progress bar and a
/// check badge once unlocked (locked cells render muted/grayscale).
class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.definition, this.state});

  final AchievementDef definition;
  final AchievementState? state;

  bool get _unlocked => state?.unlocked ?? false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = definition.target;
    final progress = (state?.progress ?? 0).clamp(0, target);

    return Semantics(
      label: '${definition.title}: ${definition.description}. '
          '${_unlocked ? 'Unlocked' : 'Progress $progress of $target'}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _unlocked
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _unlocked
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFor(definition.iconId),
                    size: 24,
                    color: _unlocked
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_unlocked)
                  Icon(Icons.check_circle, size: 20, color: scheme.primary)
                else
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              definition.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              definition.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _unlocked ? 1.0 : progress / target,
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _unlocked ? 'Unlocked' : '${compactNumber(progress)} / ${compactNumber(target)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps an [AchievementDef.iconId] to its glyph (see achievement defs).
IconData _iconFor(String iconId) => switch (iconId) {
      'play' => Icons.play_arrow,
      'trophy' => Icons.emoji_events,
      'bolt' => Icons.bolt,
      'extension' => Icons.extension,
      'style' => Icons.style,
      'grid' => Icons.grid_on,
      'quiz' => Icons.quiz,
      'flame' => Icons.local_fire_department,
      'coin' => Icons.monetization_on,
      'compass' => Icons.explore,
      'psychology' => Icons.psychology,
      _ => Icons.emoji_events_outlined,
    };

/// Game detail screen: hero thumbnail, metadata, instructions, personal
/// best and the Play entry point.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/game_thumbnail.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../game_player/engine_registry.dart';
import '../../gamification/adaptive_difficulty.dart';
import 'catalog_providers.dart';
import '../domain/game_definition.dart';

/// Shows everything about one game, resolved through [gameByIdProvider].
class GameDetailScreen extends ConsumerWidget {
  const GameDetailScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gameByIdProvider(gameId));
    final def = async.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(def?.title ?? 'Game')),
      body: async.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            SkeletonBox(height: 200, radius: 16),
            SizedBox(height: 16),
            SkeletonBox(height: 24, width: 180),
            SizedBox(height: 12),
            SkeletonBox(height: 20, width: 240),
            SizedBox(height: 24),
            SkeletonBox(height: 80, radius: 12),
          ],
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load game",
          message: 'Something went wrong reading the catalog. ($error)',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(gameByIdProvider(gameId)),
        ),
        data: (game) => game == null
            ? const EmptyState(
                icon: Icons.videogame_asset_outlined,
                title: 'Game not found',
                message: 'This game is no longer in the catalog.',
              )
            : _DetailBody(definition: game, gameId: gameId),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.definition, required this.gameId});

  final GameDefinition definition;
  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final best = ref.watch(gameBestProvider(gameId)).valueOrNull;
    final instructions =
        engineFor(definition.template)?.instructions ?? '';
    // Offline adaptive suggestion from recent results with this engine.
    final suggested = AdaptiveDifficulty.suggest(
      ref.watch(progressProvider.select((p) => p.recentStarsFor(definition.template))),
    );
    final showSuggestion =
        suggested != null && suggested != definition.difficulty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: GameThumbnail(definition: definition),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                definition.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CategoryChip(category: definition.category),
                  DifficultyChip(difficulty: definition.difficulty),
                  const OfflineBadge(),
                  if (showSuggestion)
                    Tooltip(
                      message: 'Based on your recent results with this '
                          'game type',
                      child: ActionChip(
                        avatar: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        label: Text('Try ${suggested.label}'),
                        onPressed: () => Navigator.of(context).pushNamed(
                          Routes.game,
                          arguments: definition.id,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (instructions.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          instructions,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Your best',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              if (best == null)
                Text(
                  'No score yet — be the first to set one!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Row(
                  children: [
                    Text(
                      'Best: ${compactNumber(best.score)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    StarRating(stars: best.stars.clamp(0, 3).toInt(), size: 20),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context)
                    .pushNamed(Routes.game, arguments: definition.id),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

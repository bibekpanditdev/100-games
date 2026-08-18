/// GameCard — the atomic catalog tile used in grids and carousels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/badges.dart';
import '../../../../shared/widgets/game_thumbnail.dart';
import '../../domain/game_definition.dart';
import '../catalog_providers.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.definition,
    this.onTap,
    this.compact = false,
    this.playCount = 0,
    this.bestStars,
  });

  final GameDefinition definition;
  final VoidCallback? onTap;
  final bool compact;
  final int playCount;
  final int? bestStars;

  static const double compactWidth = 110;
  static const double compactHeight = 180;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: compact ? compactWidth / 95 : 1,
                child: Hero(
                  tag: 'thumb_${definition.id}',
                  child: GameThumbnail(definition: definition),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        definition.title,
                        maxLines: compact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 12 : 14,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'LVL ${definition.level}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            PlayCountChip(count: playCount),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderGameCard extends ConsumerWidget {
  const ProviderGameCard({
    super.key,
    required this.definition,
    this.compact = false,
  });

  final GameDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final best = ref.watch(gameBestProvider(definition.id));
    final progress = ref.watch(progressProvider);

    return GameCard(
      definition: definition,
      compact: compact,
      playCount: progress.playCountOf(definition.id),
      bestStars: best.value?.stars,
      onTap: () {
        Navigator.of(context).pushNamed(
          '/game',
          arguments: definition.id,
        );
      },
    );
  }
}

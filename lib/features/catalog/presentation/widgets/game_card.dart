/// GameCard — the atomic catalog tile used in grids and carousels.
///
/// The card is a pure (provider-free) widget so it stays trivially
/// testable; provider wiring (play counts, personal-best stars, default
/// navigation) lives in [ProviderGameCard] below.
library;

import 'package:flutter/material.dart';

import '../../../../shared/widgets/badges.dart';
import '../../../../shared/widgets/game_thumbnail.dart';
import '../../../../shared/widgets/star_rating.dart';
import '../../domain/game_definition.dart';

/// A single game tile.
///
/// * [compact] — carousel variant: fixed 110x150 with a shorter thumbnail
///   and a one-line title. Default (grid) variant fills its parent cell.
/// * [playCount] — lifetime play count rendered via [PlayCountChip].
/// * [bestStars] — personal-best stars (0..3); `null` hides the rating.
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

  /// Carousel variant (fixed size) vs grid variant (fills the cell).
  final bool compact;

  /// Lifetime plays, shown next to the difficulty chip.
  final int playCount;

  /// Personal best as 0..3 stars; `null` hides the rating entirely.
  final int? bestStars;

  /// Width/height of the carousel (compact) variant.
  static const double compactWidth = 110;
  static const double compactHeight = 150;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = Semantics(
      label: '${definition.title}, ${definition.category.label}, '
          '${definition.difficulty.label}',
      button: true,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        elevation: 1,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: compact ? compactWidth / 80 : 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GameThumbnail(definition: definition),
                    const Positioned(top: 4, right: 4, child: OfflineBadge()),
                    if (bestStars != null)
                      Positioned(
                        left: 4,
                        bottom: 4,
                        child: _StarScrim(stars: bestStars!),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          definition.title,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DifficultyChip(difficulty: definition.difficulty),
                              const SizedBox(width: 4),
                              PlayCountChip(count: playCount),
                            ],
                          ),
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

    if (!compact) return card;
    return SizedBox(
      width: compactWidth,
      height: compactHeight,
      child: card,
    );
  }
}

/// Personal-best stars overlaid on the thumbnail with a theme-aware scrim
/// so they stay readable on any palette background.
class _StarScrim extends StatelessWidget {
  const _StarScrim({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: StarRating(stars: stars, max: 3, size: 14),
    );
  }
}

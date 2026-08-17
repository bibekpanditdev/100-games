/// [GameCard] wired to app state.
///
/// Watching [gameBestProvider] here — one small widget per card — keeps
/// best-score refreshes from rebuilding whole carousels/grids.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing.dart';
import '../../domain/game_definition.dart';
import '../catalog_providers.dart';
import 'game_card.dart';

/// A [GameCard] that pulls its play count from [progressProvider] and its
/// personal-best stars from [gameBestProvider].
///
/// Tapping opens the game route (`Routes.game`) unless [onTap] is given.
class ProviderGameCard extends ConsumerWidget {
  const ProviderGameCard({
    super.key,
    required this.definition,
    this.onTap,
    this.compact = false,
  });

  final GameDefinition definition;
  final VoidCallback? onTap;

  /// Whether to render the fixed-size carousel variant.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final best = ref.watch(gameBestProvider(definition.id)).valueOrNull;
    return GameCard(
      definition: definition,
      compact: compact,
      playCount: progress.playCountOf(definition.id),
      bestStars: best == null ? null : best.stars.clamp(0, 3).toInt(),
      onTap: onTap ?? () => _openGame(context),
    );
  }

  void _openGame(BuildContext context) {
    Navigator.of(context).pushNamed(Routes.game, arguments: definition.id);
  }
}

/// Small chips: category, difficulty, offline badge, play counts.
library;

import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../features/catalog/domain/game_definition.dart';

IconData categoryIcon(GameCategory c) => switch (c) {
      GameCategory.arcade => Icons.videogame_asset,
      GameCategory.puzzle => Icons.extension,
      GameCategory.cards => Icons.style,
      GameCategory.board => Icons.grid_on,
      GameCategory.trivia => Icons.quiz,
      GameCategory.mind => Icons.psychology,
    };

/// Distinct accent per category, contrast-checked against the theme surface
/// (>= 3:1 as a UI component color; text on chips still uses theme tokens).
/// Mind games get their own deep-teal identity (spec §1/§4 of the add-on).
Color categoryAccent(BuildContext context, GameCategory c) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (c) {
    GameCategory.arcade => dark ? const Color(0xFFFFB864) : const Color(0xFF8A4A00),
    GameCategory.puzzle => dark ? const Color(0xFFBAC3FF) : const Color(0xFF2F3A8F),
    GameCategory.cards => dark ? const Color(0xFFFFB77C) : const Color(0xFF7A4E00),
    GameCategory.board => dark ? const Color(0xFF82B1A6) : const Color(0xFF0F5132),
    GameCategory.trivia => dark ? const Color(0xFFCE93D8) : const Color(0xFF6A1B9A),
    GameCategory.mind => dark ? const Color(0xFF4DB6AC) : const Color(0xFF00695C),
  };
}

class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.category});

  final GameCategory category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(categoryIcon(category), size: 16),
      label: Text(category.label),
      visualDensity: VisualDensity.compact,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
    );
  }
}

/// Difficulty is encoded with icon + color (not color alone).
class DifficultyChip extends StatelessWidget {
  const DifficultyChip({super.key, required this.difficulty});

  final Difficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon) = switch (difficulty) {
      Difficulty.easy => (Colors.green.shade700, Icons.check_circle_outline),
      Difficulty.medium => (Colors.orange.shade800, Icons.remove_circle_outline),
      Difficulty.hard => (theme.colorScheme.error, Icons.dangerous_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            difficulty.label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.secondaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 13, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Text(
            'Offline OK',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PlayCountChip extends StatelessWidget {
  const PlayCountChip({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.play_circle_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          compactNumber(count),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

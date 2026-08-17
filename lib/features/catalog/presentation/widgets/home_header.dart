/// Home screen header: app title, coin + streak chips and quick links.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing.dart';
import '../../../../core/utils/formatters.dart';
import '../catalog_providers.dart';

/// AppBar-style header for [HomeScreen].
///
/// Row 1: app title + leaderboards / achievements / settings icons.
/// Row 2: coin chip (tap = settings) + streak flame chip.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '1000+ Games',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Leaderboards',
                icon: const Icon(Icons.emoji_events),
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.leaderboards),
              ),
              IconButton(
                tooltip: 'Achievements',
                icon: const Icon(Icons.military_tech),
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.achievements),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.settings),
              ),
            ],
          ),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.monetization_on,
                label: compactNumber(progress.coins),
                tooltip: 'Coins — tap for settings',
                onTap: () =>
                    Navigator.of(context).pushNamed(Routes.settings),
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.local_fire_department,
                label: '${progress.streakDays}',
                tooltip: 'Day streak',
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: chip,
      ),
    );
  }
}

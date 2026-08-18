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
                  'GAME',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: () => Navigator.of(context).pushNamed(Routes.leaderboards),
              ),
              IconButton(
                icon: const Icon(Icons.military_tech_outlined),
                onPressed: () => Navigator.of(context).pushNamed(Routes.achievements),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _HeaderChip(
                icon: Icons.monetization_on,
                label: compactNumber(progress.coins),
                onTap: () => Navigator.of(context).pushNamed(Routes.settings),
              ),
              const SizedBox(width: 8),
              _HeaderChip(
                icon: Icons.local_fire_department,
                label: '${progress.streakDays}',
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: chip,
    );
  }
}

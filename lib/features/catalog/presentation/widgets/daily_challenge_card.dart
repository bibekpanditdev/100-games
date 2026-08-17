/// Daily Challenge hero card for the home screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../domain/game_definition.dart';
import '../catalog_providers.dart';

/// Highlights the deterministic daily pick from [dailyChallengeProvider]
/// with a palette-accent gradient and a Play button.
class DailyChallengeCard extends ConsumerWidget {
  const DailyChallengeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final daily = ref.watch(dailyChallengeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: daily.when(
        loading: () => const SkeletonBox(height: 132, radius: 16),
        error: (_, __) => const SizedBox.shrink(),
        data: (def) => def == null
            ? const SizedBox.shrink()
            : _DailyCard(definition: def, accent: theme.colorScheme.primary),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.definition, required this.accent});

  final GameDefinition definition;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = paletteById(definition.themeId);
    final onAccent = GamePalette.contrastOn(palette.accent);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accent, Color.lerp(palette.accent, accent, 0.55)!],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: onAccent.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.today_outlined, size: 13, color: onAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Daily Challenge',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: onAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    definition.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${definition.category.label} • ${definition.difficulty.label}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onAccent.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => Navigator.of(context)
                  .pushNamed(Routes.game, arguments: definition.id),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}

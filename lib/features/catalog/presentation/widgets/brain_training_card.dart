/// Daily Brain Training hero card for the home screen — shows today's
/// routine progress (x/5) and jumps to the Brain dashboard.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/routing.dart';
import '../../../../shared/widgets/skeleton.dart';
import '../../../mind/brain_training/brain_providers.dart';

class BrainTrainingCard extends ConsumerWidget {
  const BrainTrainingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = ref.watch(brainProgressProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: progress.when(
        loading: () => const SkeletonBox(height: 96, radius: 16),
        error: (_, __) => const SizedBox.shrink(),
        data: (p) => Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).pushNamed(Routes.brain),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Brain Training',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.complete
                              ? 'Complete! Score ${p.brainScore} — see your trend'
                              : '${p.completedCount} of ${p.total} mind games played today',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                    semanticLabel: 'Open brain training',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

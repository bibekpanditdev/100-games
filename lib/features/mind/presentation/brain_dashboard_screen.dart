/// Daily Brain Training dashboard: today's five-game routine (one per mind
/// subcategory), composite Brain Score, streak, and a local-only history
/// chart. Renders correctly with zero, partial and full history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing.dart';
import '../../../core/utils/formatters.dart';
import '../../catalog/domain/game_definition.dart';
import '../brain_training/brain_providers.dart';
import '../brain_training/brain_training_service.dart';
import '../../../gamification/progress_controller.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/game_thumbnail.dart';
import '../../../shared/widgets/skeleton.dart';

class BrainDashboardScreen extends ConsumerWidget {
  const BrainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(brainProgressProvider);
    final historyAsync = ref.watch(brainHistoryProvider);
    final streak = ref.watch(progressProvider.select((p) => p.streakDays));

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Brain Training')),
    body: progressAsync.when(
        loading: () => const ListView(
              children: [
                SizedBox(height: 24),
                Center(child: SkeletonBox(width: 220, height: 96, radius: 16)),
                SizedBox(height: 16),
                SkeletonBox(height: 64, radius: 12),
                SizedBox(height: 12),
                SkeletonBox(height: 64, radius: 12),
              ],
            ),
        error: (e, _) => EmptyState(
              icon: Icons.psychology_alt,
              title: 'Brain training unavailable',
              message: 'Something went wrong loading today\'s routine. '
                  'Your saved scores are safe — try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(brainProgressProvider),
            ),
        data: (progress) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _ScoreHeader(progress: progress, streak: streak),
              const SizedBox(height: 16),
              Text('Today\'s routine', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final game in progress.routine.games)
                _RoutineTile(
                  game: game,
                  result: progress.results[game.definition.id],
                ),
              const SizedBox(height: 24),
              Text('Brain Score history', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              historyAsync.when(
                loading: () => const SkeletonBox(height: 160, radius: 16),
                error: (e, _) => const SizedBox.shrink(),
                data: (history) => _HistoryChart(days: history),
              ),
              const SizedBox(height: 8),
              Text(
                'One game per subcategory each day — logic, word, memory, math '
                'and spatial. Scores are stored on this device only.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.progress, required this.streak});

  final RoutineProgress progress;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${progress.brainScore}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Brain Score', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              progress.complete
                  ? 'Routine complete — brilliant! Come back tomorrow.'
                  : '${progress.completedCount} of ${progress.total} games played today',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_fire_department,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 4),
                Text('$streak-day play streak', style: theme.textTheme.labelLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.game, required this.result});

  final RoutineGame game;
  final RoutineGameResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = result != null;
    final def = game.definition;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            children: [
              GameThumbnail(definition: def, size: 48),
              if (done)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(def.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          done ? 'Score ${result!.score} • ${'★' * result!.stars}' : MindGroups.label(game.group),
        ),
        trailing: FilledButton.tonal(
          onPressed: () =>
              Navigator.of(context).pushNamed(Routes.game, arguments: def.id),
          child: Text(done ? 'Improve' : 'Play'),
        ),
        onTap: () =>
            Navigator.of(context).pushNamed(Routes.game, arguments: def.id),
      ),
    );
  }
}

/// Local-only line chart of brain score over time. Handles empty, single,
/// and multi-point histories without crashing.
class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.days});

  final List<BrainScoreDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Oldest-first for left-to-right plotting.
    final points = days.reversed.toList(growable: false);

    if (points.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No history yet',
        message: 'Finish today\'s routine to start your Brain Score trend.',
      );
    }

    final maxScore = points
        .map((d) => d.score)
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 5000);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: CustomPaint(
                painter: _LineChartPainter(
                  points: points.map((d) => d.score).toList(),
                  max: maxScore * 1.15,
                  line: theme.colorScheme.primary,
                  fill: theme.colorScheme.primary.withOpacity(0.12),
                  grid: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Semantics(
                  label: 'Brain score chart, ${points.length} days, '
                      'latest ${points.last.score}',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Oldest: ${_shortDay(points.first.day)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Latest: ${compactNumber(points.last.score)} '
                  '(${_shortDay(points.last.day)})',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shortDay(String dayKey) => dayKey.substring(5);
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.max,
    required this.line,
    required this.fill,
    required this.grid,
  });

  final List<int> points;
  final double max;
  final Color line;
  final Color fill;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    // Horizontal guide lines (25/50/75%).
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = pad + h * (1 - f);
      canvas.drawLine(Offset(pad, y), Offset(pad + w, y), gridPaint);
    }

    Offset pos(int i, int v) => Offset(
          pad + (points.length == 1 ? w / 2 : w * i / (points.length - 1)),
          pad + h * (1 - (v / max).clamp(0.0, 1.0)),
        );

    final path = Path()..moveTo(pad, pad + h);
    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = pos(i, points[i]);
      path.lineTo(p.dx, p.dy);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    path.lineTo(points.length == 1 ? pad + w / 2 : pad + w, pad + h);
    path.close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dot on the latest point.
    final last = pos(points.length - 1, points.last);
    canvas.drawCircle(last, 4, Paint()..color = line);
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

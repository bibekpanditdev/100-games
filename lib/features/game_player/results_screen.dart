/// Game-over screen: score, stars, coins earned, newly unlocked
/// achievements, and Play Again / Next Game / Home actions.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing.dart';
import '../../core/services/feedback.dart';
import '../../core/utils/formatters.dart';
import '../catalog/presentation/catalog_providers.dart';
import '../../shared/widgets/star_rating.dart';
import 'results_payload.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.payload});

  final ResultsPayload payload;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  String? _nextGameId;

  @override
  void initState() {
    super.initState();
    if (widget.payload.stars >= 2) {
      AppFeedback.win();
    }
    if (widget.payload.coinsEarned > 0) {
      AppFeedback.coin();
    }
    if (widget.payload.newAchievements.isNotEmpty) {
      AppFeedback.unlock();
    }
    _pickNextGame();
  }

  Future<void> _pickNextGame() async {
    final games = await ref.read(catalogGamesProvider.future);
    if (!mounted) return;
    final sameCategory =
        games.where((g) => g.category == widget.payload.definition.category).toList();
    if (sameCategory.isEmpty) return;
    final pick = sameCategory[Random().nextInt(sameCategory.length)];
    setState(() => _nextGameId = pick.id);
  }

  void _playAgain() {
    Navigator.of(context).pushReplacementNamed(
      Routes.game,
      arguments: widget.payload.definition.id,
    );
  }

  void _nextGame() {
    final id = _nextGameId;
    if (id == null) return;
    Navigator.of(context).pushReplacementNamed(Routes.game, arguments: id);
  }

  void _home() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _stars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final payload = widget.payload;
    final reducedMotion = ref.watch(settingsProvider.select((s) => s.reducedMotion));
    final won = payload.stars >= 2;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            if (won && !reducedMotion) const _ConfettiLayer(),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      won ? 'LEVEL COMPLETE' : 'LEVEL FAILED',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StarRating(
                      stars: payload.stars,
                      animation: _stars,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      compactNumber(payload.outcome.score),
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text('Score', style: theme.textTheme.labelLarge),
                    if (payload.newBest) ...[
                      const SizedBox(height: 8),
                      Chip(
                        avatar: const Icon(Icons.emoji_events, size: 18),
                        label: const Text('New personal best!'),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on, color: theme.colorScheme.tertiary),
                            const SizedBox(width: 8),
                            Text(
                              '+${payload.coinsEarned} coins',
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (payload.newAchievements.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text('Achievement unlocked!', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final a in payload.newAchievements)
                            Chip(
                              avatar: const Icon(Icons.military_tech, size: 20),
                              label: Text(a.title),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _playAgain,
                      icon: const Icon(Icons.replay),
                      label: const Text('Play again'),
                    ),
                    const SizedBox(height: 8),
                    if (_nextGameId != null)
                      OutlinedButton.icon(
                        onPressed: _nextGame,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('Next game'),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _home,
                      child: const Text('Back to home'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lightweight painter-based confetti — no dependencies, no jank.
class _ConfettiLayer extends StatefulWidget {
  const _ConfettiLayer();

  @override
  State<_ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<_ConfettiLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  static const _pieceCount = 60;
  final List<_Piece> _pieces = List.generate(_pieceCount, (i) => _Piece(i));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(_controller.value, _pieces),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Piece {
  _Piece(int seed)
      : x = (seed * 37 % 100) / 100,
        speed = 0.4 + (seed * 13 % 10) / 20,
        size = 4.0 + (seed * 7 % 6),
        colorIndex = seed % 8,
        sway = (seed * 29 % 10) / 10 - 0.5,
        rotSpeed = (seed * 17 % 10) / 5;

  final double x;
  final double speed;
  final double size;
  final int colorIndex;
  final double sway;
  final double rotSpeed;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.pieces);

  final double t;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [
      Color(0xFF0072B2), Color(0xFFE69F00), Color(0xFF009E73),
      Color(0xFFCC79A7), Color(0xFF56B4E9), Color(0xFFD55E00),
      Color(0xFFF0E442), Color(0xFF7B5EA7),
    ];
    final paint = Paint();
    for (final p in pieces) {
      final y = (t * p.speed + p.x) % 1.1 - 0.05;
      final x = p.x + p.sway * 0.05 * (0.5 + (y % 0.2));
      canvas.save();
      canvas.translate(x * size.width, y * size.height);
      canvas.rotate(t * p.rotSpeed * 6.28);
      paint.color = colors[p.colorIndex].withValues(alpha: 0.9);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => true;
}

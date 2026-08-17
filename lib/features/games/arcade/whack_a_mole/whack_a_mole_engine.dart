/// Whack-a-mole engine: moles pop from a grid of holes for a short window
/// each — tap them for points before they duck away. Empty-hole taps cost
/// points, so swing carefully and beat the target score before time runs
/// out.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'whack_a_mole_logic.dart';

/// Catalog engine for the `whack_a_mole` template.
class WhackAMoleEngine implements GameEngine {
  const WhackAMoleEngine();

  @override
  String get templateId => 'whack_a_mole';

  @override
  String get instructions =>
      'Tap the moles as they pop up before they duck back down. Each hit is '
      'worth 15 points but smacking an empty hole costs 5 — reach the target '
      'score before the timer ends.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) =>
      WhackAMoleGame(session: session);
}

/// The whack-a-mole gameplay screen for one session.
class WhackAMoleGame extends StatefulWidget {
  const WhackAMoleGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<WhackAMoleGame> createState() => _WhackAMoleGameState();
}

class _WhackAMoleGameState extends State<WhackAMoleGame> {
  static const int _tickMs = 50;

  late final WhackAMoleLogic _logic;
  late final int _columns;

  Timer? _timer;
  int _hudScore = -1;
  int _hudHits = -1;
  int _hudRemain = -1;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final holes = _bounded(cfg.getInt('holes', 9), 6, 16);
    final spawnMs = _bounded(cfg.getInt('spawnMs', 700), 300, 1500);
    final durationSec = _bounded(cfg.getInt('durationSec', 35), 10, 90);
    _columns = holes >= 12 ? 4 : 3;
    _logic = WhackAMoleLogic(
      holes: holes,
      spawnMs: spawnMs,
      durationSec: durationSec,
      random: Random(),
    );
    widget.session.addListener(_onSessionChanged);
    _pushHud();
    _ensureTicker();
  }

  @override
  void dispose() {
    _cancelTicker();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  // Timer ---------------------------------------------------------------------

  void _onSessionChanged() {
    if (widget.session.isFinished || widget.session.isPaused) {
      _cancelTicker();
    } else {
      _ensureTicker();
    }
    if (mounted) setState(() {});
  }

  void _ensureTicker() {
    if (_timer != null || !_interactive) return;
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), _onTick);
  }

  void _cancelTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (!_interactive) return;
    _logic.advance(_tickMs);
    _pushHud();
    if (_logic.isTimeUp) {
      _cancelTicker();
      if (_logic.won) AudioService.I.sfx(SfxKeys.win);
      widget.session.finish(
        won: _logic.won,
        stats: {'hits': _logic.hits},
      );
      return;
    }
    if (mounted) setState(() {});
  }

  void _pushHud() {
    final remaining = _logic.remainingSec;
    if (_logic.score == _hudScore &&
        _logic.hits == _hudHits &&
        remaining == _hudRemain) {
      return;
    }
    if (remaining != _hudRemain && remaining > 0 && remaining <= 5) {
      AudioService.I.sfx(SfxKeys.tick);
    }
    _hudScore = _logic.score;
    _hudHits = _logic.hits;
    _hudRemain = remaining;
    final progress = _logic.durationSec == 0
        ? 0.0
        : 1 - _logic.elapsedMs / _logic.totalMs;
    widget.session.updateHud(
      score: _logic.score,
      status: 'Time $remaining',
      detail: 'Hits ${_logic.hits}',
      progress: progress.clamp(0.0, 1.0).toDouble(),
    );
  }

  // Input ---------------------------------------------------------------------

  void _whack(int hole) {
    if (!_interactive) return;
    final hit = _logic.whack(hole);
    if (hit) {
      AudioService.I.sfx(SfxKeys.hit);
      HapticFeedback.mediumImpact();
    } else if (!_logic.isTimeUp) {
      AudioService.I.sfx(SfxKeys.wrong);
    }
    _pushHud();
    if (mounted) setState(() {});
  }

  // Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Semantics(
        label: 'Whack-a-mole board with ${_logic.holes} holes. Tap a hole '
            'when a mole pops up.',
        child: _buildBoard(),
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    final rows = (_logic.holes / _columns).ceil();
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the hole grid pleasantly round on wide screens.
        final maxWidth = constraints.maxWidth < 480
            ? constraints.maxWidth
            : 480.0;
        return Center(
          child: SizedBox(
            width: maxWidth,
            child: Container(
              decoration: BoxDecoration(
                color: palette.boardB,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = 0; r < rows; r++)
                    Row(
                      children: [
                        for (var c = 0; c < _columns; c++)
                          Expanded(
                            child: _buildHole(r * _columns + c, maxWidth),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHole(int index, double boardWidth) {
    if (index >= _logic.holes) return const SizedBox.expand();
    final palette = widget.session.palette;
    final moleUp = _logic.activeHole == index;
    final holeLabel = 'Hole ${index + 1}'
        '${moleUp ? ', mole is up' : ', empty'}';
    return Semantics(
      button: true,
      label: holeLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _whack(index),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The hole itself.
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.boardA,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.backgroundDark,
                    width: 3,
                  ),
                ),
              ),
              // The mole pops up with a springy scale animation.
              AnimatedScale(
                scale: moleUp ? 1 : 0,
                duration: const Duration(milliseconds: 130),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  width: boardWidth / _columns * 0.5,
                  height: boardWidth / _columns * 0.5,
                  child: const CustomPaint(
                    painter: _MolePainter(),
                    size: Size.infinite,
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

/// A mole: round body (colour channel) plus a triangular snout and eyes
/// (shape channel) so it never relies on colour alone.
class _MolePainter extends CustomPainter {
  const _MolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyColor = kPieceColors[1]; // orange
    final snoutColor = kPieceColors[5]; // vermillion
    final center = Offset(w / 2, h / 2);
    final radius = w * 0.46;

    canvas.drawCircle(center, radius, Paint()..color = bodyColor);

    // Triangular snout.
    final snout = Path()
      ..moveTo(w / 2, h * 0.42)
      ..lineTo(w * 0.68, h * 0.78)
      ..lineTo(w * 0.32, h * 0.78)
      ..close();
    canvas.drawPath(snout, Paint()..color = snoutColor);

    // Eyes.
    final eyePaint = Paint()..color = GamePalette.contrastOn(bodyColor);
    canvas.drawCircle(Offset(w * 0.36, h * 0.34), w * 0.07, eyePaint);
    canvas.drawCircle(Offset(w * 0.64, h * 0.34), w * 0.07, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _MolePainter oldDelegate) => false;
}

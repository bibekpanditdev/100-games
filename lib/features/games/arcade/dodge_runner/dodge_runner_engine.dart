/// Dodge-runner engine: obstacles scroll down the lanes — tap the left or
/// right half of the board (or the arrow buttons) to switch lanes and
/// survive to the target time. One paid continue clears the obstacles
/// around you.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'dodge_runner_logic.dart';

/// Catalog engine for the `dodge_runner` template.
class DodgeRunnerEngine implements GameEngine {
  const DodgeRunnerEngine();

  @override
  String get templateId => 'dodge_runner';

  @override
  String get instructions =>
      'Tap the left or right half of the road (or the arrow buttons) to '
      'switch lanes and dodge the falling blocks. Survive until the timer '
      'runs out to win.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) =>
      DodgeRunnerGame(session: session);
}

/// The dodge-runner gameplay screen for one session.
class DodgeRunnerGame extends StatefulWidget {
  const DodgeRunnerGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<DodgeRunnerGame> createState() => _DodgeRunnerGameState();
}

class _DodgeRunnerGameState extends State<DodgeRunnerGame>
    with SingleTickerProviderStateMixin {
  late final int _lanes;
  late final double _speedPxPerSec;
  late final int _targetSec;
  late final AnimationController _loop;

  DodgeRunnerLogic? _logic;
  Duration _lastElapsed = Duration.zero;
  bool _awaitingContinue = false;
  int _hudRemain = -1;
  int _hudLane = -1;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _lanes = _bounded(cfg.getInt('lanes', 3), 3, 4);
    _speedPxPerSec = cfg.getDouble('speed', 220).clamp(100.0, 400.0).toDouble();
    _targetSec = _bounded(cfg.getInt('targetSec', 45), 10, 120);
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onLoopTick);
    widget.session.onExtraLifeGranted = _onExtraLife;
    widget.session.addListener(_onSessionChanged);
    unawaited(_loop.repeat());
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _loop.dispose();
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool _running(GameSessionController session) =>
      !session.isPaused && !session.isFinished && !_awaitingContinue;

  // Game loop ----------------------------------------------------------------

  void _onSessionChanged() {
    _syncLoop();
    if (mounted) setState(() {});
  }

  void _syncLoop() {
    if (widget.session.isFinished || !_running(widget.session)) {
      if (_loop.isAnimating) _loop.stop();
      _lastElapsed = Duration.zero;
      return;
    }
    if (!_loop.isAnimating) {
      _lastElapsed = Duration.zero;
      unawaited(_loop.repeat());
    }
  }

  void _onLoopTick() {
    final logic = _logic;
    if (logic == null || !_running(widget.session)) return;
    final elapsed = _loop.lastElapsedDuration ?? Duration.zero;
    final dt =
        (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.25) return;
    logic.advance(dt);
    _pushHud(logic);
    if (logic.survived) {
      _loop.stop();
      AudioService.I.sfx(SfxKeys.win);
      widget.session.finish(
        won: true,
        stats: {'survivedSec': logic.survivedSec},
      );
      return;
    }
    if (logic.isDead) {
      _handleDeath();
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleDeath() async {
    if (_awaitingContinue || widget.session.isFinished) return;
    AudioService.I.sfx(SfxKeys.die);
    _awaitingContinue = true;
    _syncLoop();
    if (mounted) setState(() {});
    // Ask the shell BEFORE finishing; a true result means the
    // onExtraLifeGranted callback has already revived the player.
    final continued = await widget.session.requestContinue();
    if (!mounted) return;
    if (!continued) {
      widget.session.finish(
        won: false,
        stats: {'survivedSec': _logic?.survivedSec ?? 0},
      );
    }
  }

  void _onExtraLife() {
    if (widget.session.isFinished) return;
    final logic = _logic;
    if (logic == null) return;
    logic.revive();
    _awaitingContinue = false;
    _pushHud(logic);
    if (mounted) setState(() {});
    _syncLoop();
  }

  void _pushHud(DodgeRunnerLogic logic) {
    if (logic.remainingSec == _hudRemain && logic.playerLane == _hudLane) {
      return;
    }
    _hudRemain = logic.remainingSec;
    _hudLane = logic.playerLane;
    widget.session.updateHud(
      status: 'Time ${logic.remainingSec}s',
      detail: 'Lane ${logic.playerLane + 1}',
      progress: min(1.0, logic.elapsedSec / _targetSec),
    );
  }

  // Controls ------------------------------------------------------------------

  void _switchLane(int delta) {
    final logic = _logic;
    if (logic == null || !_running(widget.session)) return;
    if (logic.moveLane(delta)) {
      AudioService.I.sfx(SfxKeys.jump);
      _pushHud(logic);
      if (mounted) setState(() {});
    }
  }

  // Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildBoard()),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        if (_logic == null && width > 0 && height > 0) {
          // Convert the px/s speed into board-heights per second.
          final boardsPerSec = max(0.22, _speedPxPerSec / height);
          _logic = DodgeRunnerLogic(
            lanes: _lanes,
            targetSec: _targetSec,
            random: Random(),
          )..speedPerSec = boardsPerSec;
        }
        return Semantics(
          label:
              'Dodge track with $_lanes lanes. Tap the left or right half to '
              'change lanes.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final localX =
                  details.localPosition.dx.clamp(0.0, width).toDouble();
              _switchLane(localX < width / 2 ? -1 : 1);
            },
            child: CustomPaint(
              painter: _DodgeTrackPainter(
                logic: _logic,
                lanes: _lanes,
                palette: palette,
              ),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Semantics(
      label: 'Lane switch controls',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _laneButton(Icons.arrow_back, 'Switch to the lane on the left',
                () => _switchLane(-1)),
            _laneButton(Icons.arrow_forward, 'Switch to the lane on the right',
                () => _switchLane(1)),
          ],
        ),
      ),
    );
  }

  Widget _laneButton(IconData icon, String label, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        icon: Icon(icon, size: 30),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: _running(widget.session) ? onPressed : null,
      ),
    );
  }
}

/// Paints the lane strips, scrolling obstacles and the player block.
class _DodgeTrackPainter extends CustomPainter {
  const _DodgeTrackPainter({
    required this.logic,
    required this.lanes,
    required this.palette,
  });

  final DodgeRunnerLogic? logic;
  final int lanes;
  final GamePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final laneWidth = size.width / lanes;
    for (var i = 0; i < lanes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * laneWidth, 0, laneWidth, size.height),
        Paint()..color = i % 2 == 0 ? palette.boardA : palette.boardB,
      );
    }

    final board = logic;
    if (board == null) return;

    // Obstacles: Draw as simple modern "boxes" or "blocks" with shadows
    final obstacleHeight = DodgeRunnerLogic.obstacleHeight * size.height;

    for (final obstacle in board.obstacles) {
      final color = kPieceColors[obstacle.colorIndex % kPieceColors.length];
      final rect = Rect.fromLTWH(
        obstacle.lane * laneWidth + laneWidth * 0.15,
        obstacle.y * size.height,
        laneWidth * 0.70,
        obstacleHeight,
      );
      
      // Draw Obstacle as a "Crate" for realistic arcade feel
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = const Color(0xFF5D4037));
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(4), const Radius.circular(2)),
        Paint()..color = color.withValues(alpha: 0.8),
      );
      // Crate "X" detail
      final pX = Paint()..color = Colors.black.withValues(alpha: 0.2)..style = PaintingStyle.stroke..strokeWidth = 2;
      canvas.drawLine(rect.topLeft, rect.bottomRight, pX);
      canvas.drawLine(rect.topRight, rect.bottomLeft, pX);
    }

    // Player: HIGH QUALITY CAR MODEL
    final playerTop = DodgeRunnerLogic.playerY * size.height;
    final playerHeight = DodgeRunnerLogic.playerHeight * size.height;
    final pWidth = laneWidth * 0.7;
    final pLeft = board.playerLane * laneWidth + (laneWidth - pWidth) / 2;
    
    _drawRealisticCar(canvas, Offset(pLeft, playerTop), Size(pWidth, playerHeight), palette.accent);
  }

  void _drawRealisticCar(Canvas canvas, Offset pos, Size size, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final glassPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final lightPaint = Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // 1. Shadow
    canvas.drawRRect(RRect.fromRectAndRadius((pos & size).shift(const Offset(4, 4)), const Radius.circular(10)), Paint()..color = Colors.black.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    // 2. Main Body (Aerodynamic)
    final body = Path()
      ..moveTo(pos.dx + size.width * 0.1, pos.dy + size.height * 0.9)
      ..lineTo(pos.dx + size.width * 0.9, pos.dy + size.height * 0.9)
      ..lineTo(pos.dx + size.width * 0.95, pos.dy + size.height * 0.4)
      ..lineTo(pos.dx + size.width * 0.8, pos.dy + size.height * 0.2)
      ..lineTo(pos.dx + size.width * 0.2, pos.dy + size.height * 0.2)
      ..lineTo(pos.dx + size.width * 0.05, pos.dy + size.height * 0.4)
      ..close();
    canvas.drawPath(body, paint);

    // 3. Cabin / Windshield
    final cabin = Path()
      ..moveTo(pos.dx + size.width * 0.25, pos.dy + size.height * 0.4)
      ..lineTo(pos.dx + size.width * 0.75, pos.dy + size.height * 0.4)
      ..lineTo(pos.dx + size.width * 0.65, pos.dy + size.height * 0.22)
      ..lineTo(pos.dx + size.width * 0.35, pos.dy + size.height * 0.22)
      ..close();
    canvas.drawPath(cabin, glassPaint);

    // 4. Headlights (Bright white)
    canvas.drawCircle(Offset(pos.dx + size.width * 0.22, pos.dy + size.height * 0.3), 4, lightPaint);
    canvas.drawCircle(Offset(pos.dx + size.width * 0.78, pos.dy + size.height * 0.3), 4, lightPaint);

    // 5. Wheels (Sides)
    const wheelColor = Color(0xFF1A1A1A);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx - 2, pos.dy + size.height * 0.65, 6, size.height * 0.2), const Radius.circular(2)), Paint()..color = wheelColor);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pos.dx + size.width - 4, pos.dy + size.height * 0.65, 6, size.height * 0.2), const Radius.circular(2)), Paint()..color = wheelColor);
  }

  @override
  bool shouldRepaint(covariant _DodgeTrackPainter oldDelegate) => true;
}

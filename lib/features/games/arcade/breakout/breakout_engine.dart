/// Breakout engine: drag or button-steer the paddle, bounce the ball into
/// the brick wall and clear every brick to win. Losing the last ball offers
/// one paid continue that restores a life and relaunches the ball.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'breakout_logic.dart';

/// Catalog engine for the `breakout` template.
class BreakoutEngine implements GameEngine {
  const BreakoutEngine();

  @override
  String get templateId => 'breakout';

  @override
  String get instructions =>
      'Drag or use the buttons to slide the paddle and tap to launch the '
      'ball. Bounce it into every brick to clear the level — you lose a ball '
      'each time it drops past the paddle.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) => BreakoutGame(session: session);
}

/// The breakout gameplay screen for one session.
class BreakoutGame extends StatefulWidget {
  const BreakoutGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<BreakoutGame> createState() => _BreakoutGameState();
}

class _BreakoutGameState extends State<BreakoutGame>
    with SingleTickerProviderStateMixin {
  late final int _rows;
  late final double _speedPxPerSec;
  late final AnimationController _loop;

  BreakoutLogic? _logic;
  Duration _lastElapsed = Duration.zero;
  bool _awaitingContinue = false;
  int _hudScore = -1;
  int _hudLives = -1;
  int _hudBricks = -1;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _rows = _bounded(cfg.getInt('rows', 6), 3, 10);
    _speedPxPerSec = cfg.getDouble('speed', 240).clamp(120.0, 420.0).toDouble();
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
    final bricksBefore = logic.bricksRemaining;
    final wasDescending = logic.ballLaunched && logic.ballVY > 0;
    final phase = logic.advance(dt);
    if (logic.bricksRemaining < bricksBefore) {
      AudioService.I.sfx(SfxKeys.hit);
    } else if (wasDescending && logic.ballVY < 0) {
      AudioService.I.sfx(SfxKeys.place);
    }
    _pushHud(logic);
    if (phase == BreakoutStepPhase.cleared) {
      _loop.stop();
      AudioService.I.sfx(SfxKeys.win);
      widget.session.finish(
        won: true,
        stats: {'bricks': logic.bricksCleared},
      );
      return;
    }
    if (phase == BreakoutStepPhase.lifeLost) {
      AudioService.I.sfx(SfxKeys.die);
    }
    if (phase == BreakoutStepPhase.lifeLost && logic.isDefeated) {
      _handleDefeat();
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleDefeat() async {
    if (_awaitingContinue || widget.session.isFinished) return;
    _awaitingContinue = true;
    _syncLoop();
    if (mounted) setState(() {});
    // Ask the shell BEFORE finishing; a true result means the
    // onExtraLifeGranted callback has already restored the player.
    final continued = await widget.session.requestContinue();
    if (!mounted) return;
    if (!continued) {
      widget.session.finish(
        won: false,
        stats: {'bricks': _logic?.bricksCleared ?? 0},
      );
    }
  }

  void _onExtraLife() {
    if (widget.session.isFinished) return;
    final logic = _logic;
    if (logic == null) return;
    logic
      ..grantExtraLife()
      ..stickBallToPaddle();
    _awaitingContinue = false;
    _pushHud(logic);
    if (mounted) setState(() {});
    _syncLoop();
  }

  void _pushHud(BreakoutLogic logic) {
    if (logic.score == _hudScore &&
        logic.lives == _hudLives &&
        logic.bricksRemaining == _hudBricks) {
      return;
    }
    _hudScore = logic.score;
    _hudLives = logic.lives;
    _hudBricks = logic.bricksRemaining;
    widget.session.updateHud(
      score: logic.score,
      status: 'Lives ${logic.lives}',
      detail: 'Bricks ${logic.bricksRemaining}',
    );
  }

  // Controls ------------------------------------------------------------------

  void _movePaddleBy(double dx) {
    final logic = _logic;
    if (logic == null || !_running(widget.session)) return;
    logic.nudgePaddle(dx);
    if (mounted) setState(() {});
  }

  void _launchBall() {
    final logic = _logic;
    if (logic == null || !_running(widget.session) || logic.ballLaunched) {
      return;
    }
    logic.launch();
    if (mounted) setState(() {});
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
          _logic = BreakoutLogic(
            rows: _rows,
            boardWidth: width,
            boardHeight: height,
            speedPxPerSec: _speedPxPerSec,
            random: Random(),
          );
        }
        return Semantics(
          label: 'Breakout board. Drag horizontally to move the paddle, tap '
              'to launch the ball.',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _launchBall,
            onHorizontalDragUpdate: (details) =>
                _movePaddleBy(details.delta.dx),
            child: CustomPaint(
              painter: _BreakoutBoardPainter(
                logic: _logic,
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
    final logic = _logic;
    return Semantics(
      label: 'Paddle controls',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            _paddleButton(Icons.arrow_back, 'Move paddle left', () {
              _movePaddleBy(-(logic?.paddleWidth ?? 60) * 0.8);
            }),
            Expanded(
              child: Center(
                child: Text(
                  logic == null || logic.ballLaunched
                      ? 'Drag to steer'
                      : 'Tap to launch',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            _paddleButton(Icons.arrow_forward, 'Move paddle right', () {
              _movePaddleBy((logic?.paddleWidth ?? 60) * 0.8);
            }),
          ],
        ),
      ),
    );
  }

  Widget _paddleButton(IconData icon, String label, VoidCallback onPressed) {
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

/// Paints the brick wall, paddle and ball.
class _BreakoutBoardPainter extends CustomPainter {
  const _BreakoutBoardPainter({required this.logic, required this.palette});

  final BreakoutLogic? logic;
  final GamePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final board = logic;
    if (board == null) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = palette.boardA,
    );

    for (final brick in board.bricks) {
      if (!brick.alive) continue;
      final color = kPieceColors[brick.colorIndex % kPieceColors.length];
      final rect = Rect.fromLTWH(
        brick.left,
        brick.top,
        brick.width,
        brick.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()..color = color,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..color = GamePalette.contrastOn(color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Paddle in the accent colour.
    final paddleRect = Rect.fromLTWH(
      board.paddleX - board.paddleWidth / 2,
      board.paddleTop,
      board.paddleWidth,
      board.paddleHeight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddleRect, const Radius.circular(6)),
      Paint()..color = palette.accent,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddleRect, const Radius.circular(6)),
      Paint()
        ..color = GamePalette.contrastOn(palette.accent)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Ball: light circle with a dark outline so it reads on any palette.
    canvas.drawCircle(
      Offset(board.ballX, board.ballY),
      board.ballRadius,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(board.ballX, board.ballY),
      board.ballRadius,
      Paint()
        ..color = const Color(0xFF15151E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _BreakoutBoardPainter oldDelegate) => true;
}

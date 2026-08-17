/// Snake engine: steer an ever-growing snake with the D-pad or swipes,
/// eat food for points, avoid the walls (unless wrapping) and your own
/// tail. One paid continue revives the snake mid-board with the score kept.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'snake_logic.dart';

/// Catalog engine for the `snake` template.
class SnakeEngine implements GameEngine {
  const SnakeEngine();

  @override
  String get templateId => 'snake';

  @override
  String get instructions =>
      'Steer the snake with the D-pad or swipes and eat food to grow. '
      'Crashing into a wall (unless wrapping is on) or your own tail ends '
      'the run — an extra life revives you in the middle of the board.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) => SnakeGame(session: session);
}

/// The snake gameplay screen for one session.
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

class _SnakeGameState extends State<SnakeGame>
    with SingleTickerProviderStateMixin {
  late final SnakeLogic _logic;
  late final double _stepSec;
  late final int _speedLabel;
  late final AnimationController _loop;

  double _accumulator = 0;
  Duration _lastElapsed = Duration.zero;
  bool _awaitingContinue = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final grid = _bounded(cfg.getInt('grid', 16), 8, 26);
    final speed = cfg.getDouble('speed', 6).clamp(3.0, 12.0);
    _speedLabel = speed.round();
    _stepSec = 1 / speed;
    _logic = SnakeLogic(
      size: grid,
      wrap: cfg.getBool('wrap', false),
      random: Random(),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onLoopTick);
    widget.session.onExtraLifeGranted = _onExtraLife;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
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

  bool get _running =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_awaitingContinue &&
      !_logic.dead;

  // Game loop ----------------------------------------------------------------

  void _onSessionChanged() {
    _syncLoop();
    if (mounted) setState(() {});
  }

  /// Stops the vsync ticker while paused / awaiting a continue / finished
  /// and restarts it on resume.
  void _syncLoop() {
    if (widget.session.isFinished || !_running) {
      if (_loop.isAnimating) _loop.stop();
      _accumulator = 0;
      _lastElapsed = Duration.zero;
      return;
    }
    if (!_loop.isAnimating) {
      _accumulator = 0;
      _lastElapsed = Duration.zero;
      unawaited(_loop.repeat());
    }
  }

  void _onLoopTick() {
    if (!_running) return;
    final elapsed = _loop.lastElapsedDuration ?? Duration.zero;
    final dt =
        (elapsed - _lastElapsed).inMicroseconds / Duration.microsecondsPerSecond;
    _lastElapsed = elapsed;
    // Skip the first frame after a restart plus any lag spike.
    if (dt <= 0 || dt > 0.25) return;
    _accumulator += dt;
    var died = false;
    var ate = false;
    while (_accumulator >= _stepSec) {
      _accumulator -= _stepSec;
      switch (_logic.tick()) {
        case SnakeTickResult.died:
          died = true;
        case SnakeTickResult.ate:
          ate = true;
        case SnakeTickResult.moved:
          break;
      }
      if (died) break;
    }
    if (ate) {
      AudioService.I.sfx(SfxKeys.powerup);
      _pushHud();
    }
    if (died) {
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
      widget.session.finish(won: false, stats: {'length': _logic.length});
    }
  }

  void _onExtraLife() {
    if (widget.session.isFinished) return;
    _logic.revive();
    AudioService.I.sfx(SfxKeys.correct);
    _awaitingContinue = false;
    _pushHud();
    if (mounted) setState(() {});
    _syncLoop();
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.score,
      status: 'Length ${_logic.length}',
      detail: 'Speed $_speedLabel',
    );
  }

  // Controls ------------------------------------------------------------------

  void _turn(SnakeDirection direction) {
    if (!_running) return;
    _logic.queueTurn(direction);
  }

  void _onSwipe(double dx, double dy) {
    const threshold = 120.0;
    if (dx.abs() > dy.abs()) {
      if (dx.abs() < threshold) return;
      _turn(dx > 0 ? SnakeDirection.right : SnakeDirection.left);
    } else {
      if (dy.abs() < threshold) return;
      _turn(dy > 0 ? SnakeDirection.down : SnakeDirection.up);
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
        final side = min(constraints.maxWidth, constraints.maxHeight);
        return Center(
          child: Semantics(
            label:
                'Snake board, ${_logic.size} by ${_logic.size} grid. Swipe or '
                'use the D-pad buttons to steer.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (details) => _onSwipe(
                details.velocity.pixelsPerSecond.dx,
                0,
              ),
              onVerticalDragEnd: (details) => _onSwipe(
                0,
                details.velocity.pixelsPerSecond.dy,
              ),
              child: SizedBox(
                width: side,
                height: side,
                child: CustomPaint(
                  painter: _SnakeBoardPainter(logic: _logic, palette: palette),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Semantics(
      label: 'Snake direction controls',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dpadButton(Icons.arrow_back, 'Move snake left',
                SnakeDirection.left),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dpadButton(
                    Icons.arrow_upward, 'Move snake up', SnakeDirection.up),
                _dpadButton(
                    Icons.arrow_downward, 'Move snake down', SnakeDirection.down),
              ],
            ),
            _dpadButton(Icons.arrow_forward, 'Move snake right',
                SnakeDirection.right),
          ],
        ),
      ),
    );
  }

  Widget _dpadButton(IconData icon, String label, SnakeDirection direction) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        icon: Icon(icon, size: 30),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: _running ? () => _turn(direction) : null,
      ),
    );
  }
}

/// Paints the checkerboard, the food (circle + diamond) and the snake.
class _SnakeBoardPainter extends CustomPainter {
  const _SnakeBoardPainter({required this.logic, required this.palette});

  final SnakeLogic logic;
  final GamePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / logic.size;
    final tileA = Paint()..color = palette.boardA;
    final tileB = Paint()..color = palette.boardB;
    for (var y = 0; y < logic.size; y++) {
      for (var x = 0; x < logic.size; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell + 1, cell + 1),
          (x + y) % 2 == 0 ? tileA : tileB,
        );
      }
    }

    // Food: colour + shape redundancy (circle with an inner diamond).
    final foodColor = kPieceColors[5];
    final foodCenter =
        Offset((logic.food.x + 0.5) * cell, (logic.food.y + 0.5) * cell);
    canvas.drawCircle(foodCenter, cell * 0.34, Paint()..color = foodColor);
    final snout = cell * 0.18;
    final diamond = Path()
      ..moveTo(foodCenter.dx, foodCenter.dy - snout)
      ..lineTo(foodCenter.dx + snout, foodCenter.dy)
      ..lineTo(foodCenter.dx, foodCenter.dy + snout)
      ..lineTo(foodCenter.dx - snout, foodCenter.dy)
      ..close();
    canvas.drawPath(
      diamond,
      Paint()..color = GamePalette.contrastOn(foodColor),
    );

    // Body (tail to neck), then a lighter head with direction-facing eyes.
    final inset = cell * 0.1;
    final radius = Radius.circular(cell * 0.3);
    final segmentRect = Rect.fromLTWH(inset, inset, cell - 2 * inset, cell - 2 * inset);
    final bodyPaint = Paint()..color = palette.accent;
    for (var i = logic.body.length - 1; i >= 1; i--) {
      final p = logic.body[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          segmentRect.shift(Offset(p.x * cell, p.y * cell)),
          radius,
        ),
        bodyPaint,
      );
    }
    final head = logic.head;
    final headPaint = Paint()
      ..color = Color.lerp(palette.accent, Colors.white, 0.35)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        segmentRect.shift(Offset(head.x * cell, head.y * cell)),
        radius,
      ),
      headPaint,
    );
    _drawEyes(canvas, cell, head, headPaint.color);
  }

  void _drawEyes(Canvas canvas, double cell, Point<int> head, Color headColor) {
    final step = logic.direction.delta;
    final center =
        Offset((head.x + 0.5) * cell, (head.y + 0.5) * cell);
    final forward = Offset(step.x.toDouble(), step.y.toDouble()) * (cell * 0.16);
    final side = Offset(-step.y.toDouble(), step.x.toDouble()) * (cell * 0.16);
    final eyePaint = Paint()..color = GamePalette.contrastOn(headColor);
    canvas.drawCircle(center + forward + side, cell * 0.08, eyePaint);
    canvas.drawCircle(center + forward - side, cell * 0.08, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _SnakeBoardPainter oldDelegate) => true;
}

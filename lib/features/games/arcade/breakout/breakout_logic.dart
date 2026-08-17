/// Pure breakout rules: brick layouts, sub-stepped ball integration with
/// wall, paddle and brick collisions, lives and continue state.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// Outcome of one [BreakoutLogic.advance] step.
enum BreakoutStepPhase { playing, lifeLost, cleared }

/// One rectangular brick cell (plain doubles; no Flutter types).
class BreakoutBrick {
  BreakoutBrick({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.colorIndex,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  /// Index into the shared piece-colour cycle.
  final int colorIndex;

  bool alive = true;

  double get right => left + width;

  double get bottom => top + height;
}

/// Arkanoid-style board in pixel coordinates: bricks at the top, a paddle
/// near the bottom and one ball. The widget drives [advance] with frame dt.
class BreakoutLogic {
  BreakoutLogic({
    required this.rows,
    required this.boardWidth,
    required this.boardHeight,
    required double speedPxPerSec,
    required Random random,
  }) : _random = random {
    ballSpeed = speedPxPerSec * (boardWidth / 400);
    ballRadius = min(12.0, max(5.0, boardWidth * 0.022));
    paddleWidth = boardWidth * 0.24;
    paddleHeight = min(16.0, max(8.0, boardHeight * 0.025));
    paddleTop = boardHeight * 0.92;
    paddleX = boardWidth / 2;
    _buildBricks();
    stickBallToPaddle();
  }

  /// Brick rows (4 / 6 / 8 in the catalog).
  final int rows;

  /// Fixed brick column count.
  final int cols = 8;

  final double boardWidth;
  final double boardHeight;
  final Random _random;

  static const int brickPoints = 25;
  static const double maxBounceAngle = pi / 3; // 60 degrees from vertical

  late final double ballSpeed;
  late final double ballRadius;
  late final double paddleWidth;
  late final double paddleHeight;
  late final double paddleTop;

  /// Paddle centre x.
  double paddleX = 0;

  double ballX = 0;
  double ballY = 0;
  double ballVX = 0;
  double ballVY = 0;

  /// False while the ball rides the paddle, waiting for a launch tap.
  bool ballLaunched = false;

  int lives = 3;
  int score = 0;
  int bricksCleared = 0;

  final List<BreakoutBrick> bricks = <BreakoutBrick>[];

  bool _justLostLife = false;

  int get bricksRemaining => bricks.where((b) => b.alive).length;

  bool get isDefeated => lives <= 0;

  void _buildBricks() {
    final gap = boardWidth * 0.01;
    final margin = boardWidth * 0.03;
    final brickWidth = (boardWidth - 2 * margin - (cols - 1) * gap) / cols;
    final brickHeight = boardHeight * 0.035;
    final top = boardHeight * 0.08;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        bricks.add(
          BreakoutBrick(
            left: margin + c * (brickWidth + gap),
            top: top + r * (brickHeight + gap),
            width: brickWidth,
            height: brickHeight,
            colorIndex: r * cols + c,
          ),
        );
      }
    }
  }

  /// Places the ball on the paddle, ready to be launched.
  void stickBallToPaddle() {
    ballLaunched = false;
    ballX = paddleX;
    ballY = paddleTop - ballRadius - 1;
    ballVX = 0;
    ballVY = 0;
  }

  /// Launches the ball upward at a random angle (up to ~35 degrees off
  /// vertical so it always leaves the paddle cleanly).
  void launch() {
    final angle = -pi / 2 + (_random.nextDouble() - 0.5) * (pi / 2.6);
    ballVX = cos(angle) * ballSpeed;
    ballVY = sin(angle) * ballSpeed;
    ballLaunched = true;
  }

  /// Moves the paddle centre to [x], clamped to the walls. A stuck ball
  /// follows the paddle.
  void movePaddleTo(double x) {
    final half = paddleWidth / 2;
    paddleX = min(boardWidth - half, max(half, x));
    if (!ballLaunched) {
      ballX = paddleX;
      ballY = paddleTop - ballRadius - 1;
    }
  }

  void nudgePaddle(double dx) => movePaddleTo(paddleX + dx);

  /// Advances the ball by [dt] seconds using sub-steps that never tunnel
  /// through bricks or the paddle.
  BreakoutStepPhase advance(double dt) {
    if (ballLaunched) {
      final distance = ballSpeed * dt;
      final substeps = max(1, (distance / (ballRadius * 0.6)).ceil());
      for (var i = 0; i < substeps && ballLaunched; i++) {
        _advanceBall(dt / substeps);
      }
    }
    if (bricksRemaining == 0) return BreakoutStepPhase.cleared;
    if (_justLostLife) {
      _justLostLife = false;
      return BreakoutStepPhase.lifeLost;
    }
    return BreakoutStepPhase.playing;
  }

  void _advanceBall(double dt) {
    ballX += ballVX * dt;
    ballY += ballVY * dt;

    // Side and top walls.
    if (ballX - ballRadius < 0) {
      ballX = ballRadius;
      ballVX = ballVX.abs();
    }
    if (ballX + ballRadius > boardWidth) {
      ballX = boardWidth - ballRadius;
      ballVX = -ballVX.abs();
    }
    if (ballY - ballRadius < 0) {
      ballY = ballRadius;
      ballVY = ballVY.abs();
    }

    // Paddle (only while heading down).
    if (ballVY > 0 &&
        ballY + ballRadius >= paddleTop &&
        ballY - ballRadius < paddleTop + paddleHeight &&
        ballX >= paddleX - paddleWidth / 2 - ballRadius &&
        ballX <= paddleX + paddleWidth / 2 + ballRadius) {
      _bounceOffPaddle();
    }

    _handleBrickCollisions();

    // Floor — ball lost.
    if (ballY - ballRadius > boardHeight) {
      lives -= 1;
      _justLostLife = true;
      stickBallToPaddle();
    }
  }

  /// Paddle bounce angle varies with the hit position: the centre sends the
  /// ball straight up, the edges send it up to [maxBounceAngle] sideways.
  void _bounceOffPaddle() {
    final halfSpan = paddleWidth / 2 + ballRadius;
    final rel = ((ballX - paddleX) / halfSpan).clamp(-1.0, 1.0);
    final angle = rel * maxBounceAngle;
    ballVX = sin(angle) * ballSpeed;
    ballVY = -cos(angle) * ballSpeed;
    ballY = paddleTop - ballRadius - 0.5;
  }

  /// Kills the first brick the ball overlaps and reflects the ball along
  /// the axis of least penetration (or the dominant velocity axis when the
  /// centre has already entered the brick).
  bool _handleBrickCollisions() {
    for (final brick in bricks) {
      if (!brick.alive) continue;
      final closestX = max(brick.left, min(ballX, brick.right));
      final closestY = max(brick.top, min(ballY, brick.bottom));
      final dx = ballX - closestX;
      final dy = ballY - closestY;
      if (dx * dx + dy * dy > ballRadius * ballRadius) continue;
      brick.alive = false;
      score += brickPoints;
      bricksCleared += 1;
      if (dx == 0 && dy == 0) {
        // Centre inside the brick: reflect along the dominant axis and
        // push the ball fully clear of the brick.
        if (ballVX.abs() >= ballVY.abs()) {
          final fromLeft = ballX < brick.left + brick.width / 2;
          ballVX = fromLeft ? -ballVX.abs() : ballVX.abs();
          ballX = fromLeft
              ? brick.left - ballRadius - 0.5
              : brick.right + ballRadius + 0.5;
        } else {
          final fromTop = ballY < brick.top + brick.height / 2;
          ballVY = fromTop ? -ballVY.abs() : ballVY.abs();
          ballY = fromTop
              ? brick.top - ballRadius - 0.5
              : brick.bottom + ballRadius + 0.5;
        }
      } else if (dx.abs() > dy.abs()) {
        ballVX = dx > 0 ? ballVX.abs() : -ballVX.abs();
        ballX = closestX + (dx > 0 ? ballRadius + 0.5 : -ballRadius - 0.5);
      } else {
        ballVY = dy > 0 ? ballVY.abs() : -ballVY.abs();
        ballY = closestY + (dy > 0 ? ballRadius + 0.5 : -ballRadius - 0.5);
      }
      return true;
    }
    return false;
  }

  /// Restores a life after a paid continue.
  void grantExtraLife() => lives += 1;
}

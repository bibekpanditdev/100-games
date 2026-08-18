/// Pure dodge-runner rules: lane switching, scrolling obstacle rows with a
/// structural fairness guarantee, collision detection and survival timing.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// One scrolling obstacle block.
class DodgeObstacle {
  DodgeObstacle({required this.lane, required this.colorIndex, this.y = -0.12});

  /// Lane index, `0 .. lanes - 1`.
  final int lane;

  /// Index into the shared piece-colour cycle.
  final int colorIndex;

  /// Vertical position in board heights: 0 = top edge, 1 = bottom edge.
  /// Spawned slightly above the visible board.
  double y;
}

/// Endless-runner style dodger: the player occupies one lane near the
/// bottom while obstacle rows scroll down; survive [targetSec] seconds.
class DodgeRunnerLogic {
  DodgeRunnerLogic({
    required this.lanes,
    required this.targetSec,
    required Random random,
  })   : _random = random,
        playerLane = lanes ~/ 2;

  /// Lane count (3 or 4 in the catalog).
  final int lanes;

  /// Seconds to survive for the win.
  final int targetSec;

  final Random _random;

  /// Obstacle height in board heights.
  static const double obstacleHeight = 0.1;

  /// Player height in board heights.
  static const double playerHeight = 0.07;

  /// Player band top edge in board heights.
  static const double playerY = 0.85;

  /// Scroll speed in board-heights per second. The widget sets this from
  /// the configured px/s speed and the measured board height.
  double speedPerSec = 0.45;

  double elapsedSec = 0;
  int playerLane;
  final List<DodgeObstacle> obstacles = <DodgeObstacle>[];

  double _spawnAccumSec = 0;
  int _spawnCount = 0;
  bool _dead = false;

  bool get isDead => _dead;

  bool get survived => elapsedSec >= targetSec;

  bool get won => survived && !_dead;

  bool get isOver => _dead || survived;

  /// Whole seconds survived, capped at the target.
  int get survivedSec => min(targetSec, elapsedSec.round());

  /// Whole seconds left on the survival clock.
  int get remainingSec => max(0, targetSec - elapsedSec.ceil());

  /// Vertical gap between spawn rows: at least 3.4 obstacle heights so two
  /// rows can never merge into an impassable wall (capped only on the slow
  /// end so very slow boards don't stall).
  double get spawnIntervalSec {
    final raw = (obstacleHeight * 3.4) / speedPerSec;
    return raw > 1.4 ? 1.4 : raw;
  }

  /// Switches one lane left (-1) or right (+1). Returns false at the board
  /// edge or once the run is over.
  bool moveLane(int delta) {
    if (isOver || delta == 0) return false;
    final next = playerLane + delta;
    if (next < 0 || next >= lanes) return false;
    playerLane = next;
    return true;
  }

  /// Advances the world by [dt] seconds: scrolls obstacles, spawns new
  /// rows and checks the collision + survival conditions.
  void advance(double dt) {
    if (isOver) return;
    elapsedSec += dt;
    final dy = speedPerSec * dt;
    for (final obstacle in obstacles) {
      obstacle.y += dy;
    }
    obstacles.removeWhere((o) => o.y > 1.25);
    _spawnAccumSec += dt;
    // Catch-up spawns stack with the same vertical spacing they missed.
    var stagger = 0.0;
    while (_spawnAccumSec >= spawnIntervalSec) {
      _spawnAccumSec -= spawnIntervalSec;
      _spawnRow(atY: -0.12 - stagger);
      stagger += spawnIntervalSec * speedPerSec;
    }
    if (elapsedSec >= targetSec) return;
    if (collides) _dead = true;
  }

  /// Spawns one obstacle row of 1-2 blocks, always leaving at least two
  /// lanes free — all lanes can never be blocked in the same row.
  void _spawnRow({required double atY}) {
    final laneOrder = [for (var i = 0; i < lanes; i++) i]..shuffle(_random);
    final count = lanes - 2 >= 2 && _random.nextBool() ? 2 : 1;
    for (var i = 0; i < count; i++) {
      obstacles.add(
        DodgeObstacle(
          lane: laneOrder[i],
          colorIndex: _spawnCount + i,
          y: atY,
        ),
      );
    }
    _spawnCount += count;
  }

  /// True when any obstacle overlaps the player's lane and height band.
  bool get collides => obstacles.any(
        (o) =>
            o.lane == playerLane &&
            o.y + obstacleHeight >= playerY &&
            o.y <= playerY + playerHeight,
      );

  /// Removes obstacles in the lower half — used after a paid continue so
  /// revival is never an instant re-death.
  void clearNearPlayer() => obstacles.removeWhere((o) => o.y > 0.4);

  /// Revives after a paid continue: clears the lower board and resumes.
  void revive() {
    _dead = false;
    clearNearPlayer();
  }
}

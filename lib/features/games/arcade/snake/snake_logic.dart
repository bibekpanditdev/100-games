/// Pure snake rules: tick-based movement, a buffered turn queue, food
/// spawning and collision detection on a square grid.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// The four cardinal travel directions.
enum SnakeDirection { up, down, left, right }

/// Outcome of one [SnakeLogic.tick].
enum SnakeTickResult { moved, ate, died }

extension SnakeDirectionX on SnakeDirection {
  /// Cell delta for one step: x grows rightward, y grows downward.
  Point<int> get delta => switch (this) {
        SnakeDirection.up => const Point<int>(0, -1),
        SnakeDirection.down => const Point<int>(0, 1),
        SnakeDirection.left => const Point<int>(-1, 0),
        SnakeDirection.right => const Point<int>(1, 0),
      };

  /// The direction that would reverse travel.
  SnakeDirection get opposite => switch (this) {
        SnakeDirection.up => SnakeDirection.down,
        SnakeDirection.down => SnakeDirection.up,
        SnakeDirection.left => SnakeDirection.right,
        SnakeDirection.right => SnakeDirection.left,
      };
}

/// Classic snake on a `size x size` grid. The body is head-first; cells are
/// `(x, y)` points with `(0, 0)` in the top-left corner.
class SnakeLogic {
  /// Creates a fresh three-cell snake in the middle, heading right.
  SnakeLogic({
    required this.size,
    this.wrap = false,
    required Random random,
  }) : _random = random {
    _reset();
  }

  /// Builds the logic in an explicit state (used by tests and puzzles).
  SnakeLogic.withState({
    required this.size,
    required this.wrap,
    required List<Point<int>> cells,
    required this.direction,
    required Point<int> food,
    required Random random,
  })  : _random = random,
        _body = List<Point<int>>.of(cells),
        _food = food;

  /// Grid side length in cells.
  final int size;

  /// Whether leaving the grid wraps to the far side instead of dying.
  final bool wrap;

  /// Points awarded per food eaten.
  static const int foodPoints = 10;

  final Random _random;

  List<Point<int>> _body;
  Point<int> _food;

  /// Current travel direction (updated as queued turns are consumed).
  SnakeDirection direction = SnakeDirection.right;

  /// Buffered player turns, consumed one per tick.
  final List<SnakeDirection> _turnQueue = <SnakeDirection>[];

  /// Points scored so far (kept across [revive]).
  int score = 0;

  /// Whether the snake has crashed; only [revive] clears it.
  bool dead = false;

  /// Head-first body cells.
  List<Point<int>> get body => List<Point<int>>.unmodifiable(_body);

  Point<int> get head => _body.first;

  Point<int> get food => _food;

  int get length => _body.length;

  /// The direction the next tick will travel (first queued turn, or the
  /// current direction when the queue is empty).
  SnakeDirection get effectiveDirection =>
      _turnQueue.isEmpty ? direction : _turnQueue.first;

  /// Buffers a turn. Reversals and duplicates of the *effective* direction
  /// are ignored; up to two turns buffer so a quick double-turn (for
  /// example up then left while heading right) executes one tick apart
  /// instead of collapsing into an illegal reversal.
  void queueTurn(SnakeDirection value) {
    if (dead) return;
    final reference = _turnQueue.isEmpty ? direction : _turnQueue.last;
    if (value == reference || value == reference.opposite) return;
    if (_turnQueue.length >= 2) return;
    _turnQueue.add(value);
  }

  /// Advances one cell: consumes the next queued turn, handles wall
  /// wrap/death, self collision (moving onto the vacating tail tip is
  /// legal) and food consumption.
  SnakeTickResult tick() {
    if (dead) return SnakeTickResult.died;
    if (_turnQueue.isNotEmpty) direction = _turnQueue.removeAt(0);
    final step = direction.delta;
    var x = head.x + step.x;
    var y = head.y + step.y;
    if (x < 0 || x >= size || y < 0 || y >= size) {
      if (!wrap) {
        dead = true;
        return SnakeTickResult.died;
      }
      x = (x + size) % size;
      y = (y + size) % size;
    }
    final next = Point<int>(x, y);
    final ate = next == _food;
    // When not eating, the tail tip vacates its cell this very tick.
    final blocking = ate ? _body : _body.sublist(0, _body.length - 1);
    if (blocking.contains(next)) {
      dead = true;
      return SnakeTickResult.died;
    }
    _body.insert(0, next);
    if (ate) {
      score += foodPoints;
      spawnFood();
      return SnakeTickResult.ate;
    }
    _body.removeLast();
    return SnakeTickResult.moved;
  }

  /// Places food on a uniformly random free cell.
  void spawnFood() {
    final occupied = _body.toSet();
    final free = <Point<int>>[
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
          if (!occupied.contains(Point<int>(x, y))) Point<int>(x, y),
    ];
    if (free.isEmpty) return; // Board full — keep the last food cell.
    _food = free[_random.nextInt(free.length)];
  }

  /// Revives after a paid continue: fresh snake in the middle, score kept.
  void revive() => _reset();

  void _reset() {
    final y = size ~/ 2;
    final startX = size ~/ 3;
    _body = [for (var i = 0; i < 3; i++) Point<int>(startX - i, y)];
    direction = SnakeDirection.right;
    _turnQueue.clear();
    dead = false;
    spawnFood();
  }
}

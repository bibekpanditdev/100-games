/// Pipes pure logic — rotate-to-connect: a spanning tree of pipe segments
/// radiating from a central source, scrambled by rotating every tile
/// (solvability guaranteed by construction: the generated orientation is
/// always reachable again, one twist per tile).
///
/// No Flutter imports — deterministic given a seeded [Random] and fully
/// unit-testable standalone.
library;

import 'dart:math';

/// Compass connection bitmasks (north, east, south, west).
abstract final class PipeDirs {
  static const int n = 1;
  static const int e = 2;
  static const int s = 4;
  static const int w = 8;

  static const List<int> all = [n, e, s, w];

  /// The bit for the neighbour's side of a connection.
  static int opposite(int d) => ((d << 2) | (d >> 2)) & 0xF;

  static int dx(int d) => d == e ? 1 : (d == w ? -1 : 0);
  static int dy(int d) => d == s ? 1 : (d == n ? -1 : 0);

  /// Number of open ends in a mask.
  static int count(int mask) {
    var c = 0;
    for (final d in all) {
      if (mask & d != 0) c++;
    }
    return c;
  }
}

/// One rotate-to-connect pipes board.
class PipesLogic {
  PipesLogic({required this.size, Random? random})
      : assert(size >= 3 && size <= 9, 'pipes boards stay between 3×3 and 9×9'),
        _random = random ?? Random(),
        _connections = List<int>.filled(size * size, 0),
        _rotation = List<int>.filled(size * size, 0) {
    _generateTree();
    _scramble();
    _live = computeLive();
  }

  /// Tiles per board side.
  final int size;
  final Random _random;

  /// Connection bitmask per cell at rotation 0 — the solved layout.
  final List<int> _connections;

  /// Player-applied quarter-turn rotation per cell (0–3, clockwise).
  final List<int> _rotation;

  /// Source cell (board centre) — the pump; always live.
  late final int source;

  /// Degree-1 cells other than the source. The puzzle is solved when every
  /// endpoint is connected to the source.
  late final Set<int> endpoints;

  /// Player rotations performed (the scramble does not count).
  int rotations = 0;

  Set<int> _live = const {};

  // --- Board state ----------------------------------------------------------

  /// Solved-orientation connections of a cell.
  int connectionsOf(int index) => _connections[index];

  /// Connections of a cell under its current rotation.
  int maskOf(int index) => rotateMask(_connections[index], _rotation[index]);

  /// Copies the current rotations (save/resume payload).
  List<int> rotationSnapshot() => List<int>.of(_rotation);

  /// Rotates a connection bitmask clockwise by [times] quarter turns.
  static int rotateMask(int mask, int times) {
    var m = mask & 0xF;
    for (var i = times & 3; i > 0; i--) {
      m = ((m << 1) | (m >> 3)) & 0xF;
    }
    return m;
  }

  bool isLive(int index) => _live.contains(index);

  /// Endpoints currently connected to the source.
  int get liveEndpointCount {
    var c = 0;
    for (final e in endpoints) {
      if (_live.contains(e)) c++;
    }
    return c;
  }

  bool get isSolved {
    for (final e in endpoints) {
      if (!_live.contains(e)) return false;
    }
    return true;
  }

  // --- Moves ----------------------------------------------------------------

  /// Rotates a tile 90° clockwise. Returns false for an out-of-range index.
  bool rotateCell(int index) {
    if (index < 0 || index >= _rotation.length) return false;
    _rotation[index] = (_rotation[index] + 1) & 3;
    rotations += 1;
    _live = computeLive();
    return true;
  }

  /// A tile whose rotation currently changes its shape (hint target), or
  /// null when every tile already sits in a solved-equivalent orientation.
  int? hintIndex() {
    for (var i = 0; i < _rotation.length; i++) {
      if (maskOf(i) != _connections[i]) return i;
    }
    return null;
  }

  /// Twists one tile back to its solved orientation (hints). Returns true
  /// when the tile actually moved.
  bool rotateToSolved(int index) {
    if (index < 0 || index >= _rotation.length) return false;
    if (_rotation[index] == 0) return false;
    _rotation[index] = 0;
    _live = computeLive();
    return true;
  }

  /// Restores the full solved orientation (testing / reveal).
  void resetRotationsToSolved() {
    for (var i = 0; i < _rotation.length; i++) {
      _rotation[i] = 0;
    }
    _live = computeLive();
  }

  /// Applies a persisted rotation list (save/resume). Validates first, so a
  /// malformed payload never mutates the board. Returns false on mismatch.
  bool restoreRotations(List<int> saved, {int moves = 0}) {
    if (saved.length != _rotation.length) return false;
    for (final r in saved) {
      if (r < 0 || r > 3) return false;
    }
    for (var i = 0; i < saved.length; i++) {
      _rotation[i] = saved[i];
    }
    rotations = moves < 0 ? 0 : moves;
    _live = computeLive();
    return true;
  }

  /// Minimum number of (clockwise) twists that restores the solved board.
  /// Shape-symmetric tiles count their nearest equivalent orientation.
  int minRotationsToSolve() {
    var sum = 0;
    for (var i = 0; i < _rotation.length; i++) {
      final mask = _connections[i];
      var best = 4;
      for (var k = 0; k < 4; k++) {
        if (rotateMask(mask, k) != mask) continue; // k ≠ solved orientation
        final steps = (k - _rotation[i] + 4) % 4;
        if (steps < best) best = steps;
      }
      if (best < 4) sum += best;
    }
    return sum;
  }

  // --- Generation -----------------------------------------------------------

  void _generateTree() {
    final total = size * size;
    final visited = List<bool>.filled(total, false);
    final root = _random.nextInt(total);
    visited[root] = true;
    final stack = <int>[root];
    while (stack.isNotEmpty) {
      final cell = stack.last;
      final x = cell % size;
      final y = cell ~/ size;
      final nbs = <int>[
        for (final d in PipeDirs.all)
          if (_inside(x + PipeDirs.dx(d), y + PipeDirs.dy(d)) &&
              !visited[(y + PipeDirs.dy(d)) * size + x + PipeDirs.dx(d)])
            (y + PipeDirs.dy(d)) * size + x + PipeDirs.dx(d),
      ]..shuffle(_random);
      if (nbs.isEmpty) {
        stack.removeLast();
        continue;
      }
      final nb = nbs.first;
      _connect(cell, nb);
      visited[nb] = true;
      stack.add(nb);
    }
    source = (size ~/ 2) * size + size ~/ 2;
    endpoints = {
      for (var i = 0; i < total; i++)
        if (i != source && PipeDirs.count(_connections[i]) == 1) i,
    };
  }

  bool _inside(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  void _connect(int a, int b) {
    final ax = a % size;
    final ay = a ~/ size;
    final bx = b % size;
    final by = b ~/ size;
    final d = ax < bx
        ? PipeDirs.e
        : ax > bx
            ? PipeDirs.w
            : ay < by
                ? PipeDirs.s
                : PipeDirs.n;
    _connections[a] |= d;
    _connections[b] |= PipeDirs.opposite(d);
  }

  /// Rotating the solved layout keeps it solvable; the guard loop just
  /// avoids handing the player an accidentally finished board.
  void _scramble() {
    var guard = 0;
    do {
      for (var i = 0; i < _rotation.length; i++) {
        _rotation[i] = _random.nextInt(4);
      }
      guard++;
    } while (guard < 16 && computeLive().containsAll(endpoints));
  }

  // --- Connectivity ---------------------------------------------------------

  /// Cells connected to the source under the CURRENT rotations (BFS; two
  /// tiles link only when both carry the facing connection bits).
  Set<int> computeLive() {
    final live = <int>{source};
    final queue = <int>[source];
    var head = 0;
    while (head < queue.length) {
      final cell = queue[head++];
      final x = cell % size;
      final y = cell ~/ size;
      final mask = maskOf(cell);
      for (final d in PipeDirs.all) {
        if (mask & d == 0) continue;
        final nx = x + PipeDirs.dx(d);
        final ny = y + PipeDirs.dy(d);
        if (!_inside(nx, ny)) continue;
        final nb = ny * size + nx;
        if (live.contains(nb)) continue;
        if (maskOf(nb) & PipeDirs.opposite(d) != 0) {
          live.add(nb);
          queue.add(nb);
        }
      }
    }
    return live;
  }
}

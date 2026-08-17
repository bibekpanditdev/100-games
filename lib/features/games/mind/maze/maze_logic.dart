/// Maze pure logic — perfect-maze generation via an iterative recursive
/// backtracker on a (size×2+1) wall grid, plus BFS connectivity and
/// shortest-path solving for hints and the win check.
///
/// No Flutter imports — deterministic given a seeded [Random] and fully
/// unit-testable standalone.
library;

import 'dart:math';

const List<(int, int)> _dirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
];

/// A perfect (spanning-tree) maze: every cell is reachable from every other
/// cell by exactly one path.
class MazeLogic {
  MazeLogic({required this.size, Random? random})
      : assert(size >= 3 && size % 2 == 1, 'maze size must be odd and >= 3'),
        _random = random ?? Random() {
    _generate();
  }

  /// Maze cells per side; the wall grid is (size×2+1)².
  final int size;
  final Random _random;

  late final List<List<bool>> _walls;
  int _edges = 0;

  /// Side length of the wall grid.
  int get wallDim => size * 2 + 1;

  /// Passages knocked between adjacent cells. A perfect maze over size²
  /// cells always has exactly size² − 1 (connected + acyclic).
  int get edgeCount => _edges;

  /// Entry cell (top-left) and exit cell (bottom-right).
  (int, int) get start => (0, 0);
  (int, int) get exit => (size - 1, size - 1);

  bool _inBounds(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  /// True where the wall grid is solid rock (out-of-bounds reads as wall).
  bool isWall(int wx, int wy) =>
      wx < 0 || wy < 0 || wx >= wallDim || wy >= wallDim || _walls[wy][wx];

  void _generate() {
    final dim = wallDim;
    _walls = [
      for (var y = 0; y < dim; y++) List<bool>.filled(dim, true),
    ];
    // Carve every cell floor first; the backtracker below then only
    // removes the walls *between* cells, each removal adding exactly one
    // spanning-tree edge.
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        _walls[y * 2 + 1][x * 2 + 1] = false;
      }
    }
    final visited = [
      for (var y = 0; y < size; y++) List<bool>.filled(size, false),
    ];
    visited[0][0] = true;
    final stack = <(int, int)>[(0, 0)];
    while (stack.isNotEmpty) {
      final (cx, cy) = stack.last;
      final nbs = <(int, int)>[
        for (final (dx, dy) in _dirs)
          if (_inBounds(cx + dx, cy + dy) && !visited[cy + dy][cx + dx])
            (cx + dx, cy + dy),
      ]..shuffle(_random);
      if (nbs.isEmpty) {
        stack.removeLast();
        continue;
      }
      final (nx, ny) = nbs.first;
      visited[ny][nx] = true;
      _walls[cy + ny + 1][cx + nx + 1] = false;
      _edges += 1;
      stack.add((nx, ny));
    }
  }

  /// Whether two orthogonally adjacent cells have an open passage between
  /// them (no such wall).
  bool isOpen(int ax, int ay, int bx, int by) {
    if ((ax - bx).abs() + (ay - by).abs() != 1) return false;
    if (!_inBounds(ax, ay) || !_inBounds(bx, by)) return false;
    return !isWall(ax + bx + 1, ay + by + 1);
  }

  /// Cells reachable from (x, y) through open passages, itself included.
  Set<(int, int)> reachableFrom(int x, int y) {
    final seen = <(int, int)>{(x, y)};
    final queue = <(int, int)>[(x, y)];
    var head = 0;
    while (head < queue.length) {
      final (cx, cy) = queue[head++];
      for (final (dx, dy) in _dirs) {
        final nb = (cx + dx, cy + dy);
        if (seen.contains(nb)) continue;
        if (isOpen(cx, cy, nb.$1, nb.$2)) {
          seen.add(nb);
          queue.add(nb);
        }
      }
    }
    return seen;
  }

  /// Connectivity check — a perfect maze reaches every cell from anywhere.
  bool get isConnected => reachableFrom(0, 0).length == size * size;

  /// BFS shortest path [from] → [to] (both inclusive). Empty when
  /// unreachable — never the case inside a perfect maze.
  List<(int, int)> solvePath({(int, int)? from, (int, int)? to}) {
    final startCell = from ?? start;
    final goal = to ?? exit;
    if (startCell == goal) return [startCell];
    final parent = <(int, int), (int, int)>{};
    final seen = <(int, int)>{startCell};
    final queue = <(int, int)>[startCell];
    var head = 0;
    while (head < queue.length) {
      final cell = queue[head++];
      for (final (dx, dy) in _dirs) {
        final nb = (cell.$1 + dx, cell.$2 + dy);
        if (seen.contains(nb)) continue;
        if (!isOpen(cell.$1, cell.$2, nb.$1, nb.$2)) continue;
        parent[nb] = cell;
        if (nb == goal) {
          final path = <(int, int)>[goal];
          var cur = goal;
          while (cur != startCell) {
            cur = parent[cur]!;
            path.add(cur);
          }
          return path.reversed.toList();
        }
        seen.add(nb);
        queue.add(nb);
      }
    }
    return const [];
  }
}

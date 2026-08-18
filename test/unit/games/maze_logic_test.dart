import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/mind/maze/maze_logic.dart';

const List<(int, int)> _dirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
];

/// Counts simple paths between two cells by backtracking DFS. On a tree
/// (no cycles) the walk is forced, so this stays linear.
int _countSimplePaths(MazeLogic maze, (int, int) a, (int, int) b) {
  int dfs((int, int) cur, Set<(int, int)> visited) {
    if (cur == b) return 1;
    visited.add(cur);
    var paths = 0;
    for (final (dx, dy) in _dirs) {
      final nb = (cur.$1 + dx, cur.$2 + dy);
      if (visited.contains(nb)) continue;
      if (!maze.isOpen(cur.$1, cur.$2, nb.$1, nb.$2)) continue;
      paths += dfs(nb, visited);
    }
    visited.remove(cur);
    return paths;
  }

  return dfs(a, <(int, int)>{});
}

void main() {
  for (final size in [11, 15, 21]) {
    group('maze ${size}×$size', () {
      test('is a perfect maze: connected with exactly size²−1 passages', () {
        final maze = MazeLogic(size: size, random: Random(5));
        // Connected...
        expect(maze.isConnected, isTrue);
        // ...and acyclic: a spanning tree over size² cells has size² − 1
        // edges, which forces exactly one path between any two cells.
        expect(maze.edgeCount, size * size - 1);
      });

      test('BFS solution exists from start to exit', () {
        final maze = MazeLogic(size: size, random: Random(9));
        final path = maze.solvePath();
        expect(path, isNotEmpty);
        expect(path.first, maze.start);
        expect(path.last, maze.exit);
        for (var i = 1; i < path.length; i++) {
          final prev = path[i - 1];
          final cur = path[i];
          expect(
            (prev.$1 - cur.$1).abs() + (prev.$2 - cur.$2).abs(),
            1,
            reason: 'path steps must be between adjacent cells',
          );
          expect(maze.isOpen(prev.$1, prev.$2, cur.$1, cur.$2), isTrue);
        }
        // Shortest paths never revisit a cell.
        expect(path.toSet().length, path.length);
      });

      test('exactly one path between random cell pairs', () {
        final maze = MazeLogic(size: size, random: Random(11));
        final rng = Random(3);
        for (var t = 0; t < 10; t++) {
          final a = (rng.nextInt(size), rng.nextInt(size));
          final b = (rng.nextInt(size), rng.nextInt(size));
          expect(_countSimplePaths(maze, a, b), 1);
        }
      });

      test('deterministic per seed', () {
        final a = MazeLogic(size: size, random: Random(42));
        final b = MazeLogic(size: size, random: Random(42));
        expect(a.wallDim, b.wallDim);
        for (var y = 0; y < a.wallDim; y++) {
          for (var x = 0; x < a.wallDim; x++) {
            expect(a.isWall(x, y), b.isWall(x, y));
          }
        }
      });

      test('border is solid and out-of-bounds reads as wall', () {
        final maze = MazeLogic(size: size, random: Random(13));
        final dim = maze.wallDim;
        for (var i = 0; i < dim; i++) {
          expect(maze.isWall(i, 0), isTrue);
          expect(maze.isWall(i, dim - 1), isTrue);
          expect(maze.isWall(0, i), isTrue);
          expect(maze.isWall(dim - 1, i), isTrue);
        }
        expect(maze.isWall(-1, 2), isTrue);
        expect(maze.isWall(2, dim), isTrue);
        // Moves off the grid are blocked.
        expect(maze.isOpen(0, 0, -1, 0), isFalse);
        expect(maze.isOpen(size - 1, size - 1, size - 1, size), isFalse);
        // Diagonal "moves" are not passages at all.
        expect(maze.isOpen(0, 0, 1, 1), isFalse);
      });
    });
  }
}

/// 2048-style merge puzzle — pure logic, deterministic with a seeded RNG.
library;

import 'dart:math';

enum MoveDirection { left, right, up, down }

class Merge2048Logic {
  Merge2048Logic({this.size = 4, Random? random})
      : _random = random ?? Random(),
        _grid = List.generate(size, (_) => List.filled(size, 0));

  final int size;
  final Random _random;
  final List<List<int>> _grid;

  int score = 0;
  int moves = 0;
  bool gameOver = false;
  bool won = false;

  int tileAt(int x, int y) => _grid[y][x];

  int get bestTile {
    var best = 0;
    for (final row in _grid) {
      for (final v in row) {
        if (v > best) best = v;
      }
    }
    return best;
  }

  /// Initial two tiles.
  void start() {
    spawnTile();
    spawnTile();
  }

  /// Spawns a 2 (90%) or 4 (10%) on a random free cell. Returns false when
  /// the board is full.
  bool spawnTile() {
    final free = <(int, int)>[
      for (var y = 0; y < size; y++)
        for (var x = 0; x < size; x++)
          if (_grid[y][x] == 0) (x, y),
    ];
    if (free.isEmpty) return false;
    final (x, y) = free[_random.nextInt(free.length)];
    _grid[y][x] = _random.nextDouble() < 0.9 ? 2 : 4;
    return true;
  }

  /// Applies a move. Returns the points gained (0 = nothing moved).
  int move(MoveDirection dir) {
    if (gameOver) return 0;
    final before = _snapshot();
    var gained = 0;

    for (var i = 0; i < size; i++) {
      final line = _extractLine(dir, i);
      final merged = _mergeLine(line);
      gained += merged.$2;
      _writeLine(dir, i, merged.$1);
    }

    if (_snapshot() != before) {
      moves++;
      score += gained;
      if (gained >= 128) _bigMerge = true;
      spawnTile();
      if (bestTile >= winTile) won = true;
      if (!canMove()) gameOver = true;
    }
    return gained;
  }

  int winTile = 2048;
  bool _bigMerge = false;

  /// Whether a merge of 128+ happened on the last move (for the sfx hook).
  bool consumeBigMerge() {
    final v = _bigMerge;
    _bigMerge = false;
    return v;
  }

  bool canMove() {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (_grid[y][x] == 0) return true;
        if (x + 1 < size && _grid[y][x] == _grid[y][x + 1]) return true;
        if (y + 1 < size && _grid[y][x] == _grid[y + 1][x]) return true;
      }
    }
    return false;
  }

  List<int> _extractLine(MoveDirection dir, int i) => switch (dir) {
        MoveDirection.left => List<int>.from(_grid[i]),
        MoveDirection.right => List<int>.from(_grid[i].reversed),
        MoveDirection.up => [for (var y = 0; y < size; y++) _grid[y][i]],
        MoveDirection.down => [for (var y = size - 1; y >= 0; y--) _grid[y][i]],
      };

  void _writeLine(MoveDirection dir, int i, List<int> line) {
    switch (dir) {
      case MoveDirection.left:
        _grid[i] = List<int>.from(line);
      case MoveDirection.right:
        _grid[i] = List<int>.from(line.reversed);
      case MoveDirection.up:
        for (var y = 0; y < size; y++) {
          _grid[y][i] = line[y];
        }
      case MoveDirection.down:
        for (var y = 0; y < size; y++) {
          _grid[size - 1 - y][i] = line[y];
        }
    }
  }

  /// Collapses one line towards index 0. Returns (newLine, pointsGained).
  (List<int>, int) _mergeLine(List<int> line) {
    final nonZero = [for (final v in line) if (v != 0) v];
    final result = <int>[];
    var gained = 0;
    var i = 0;
    while (i < nonZero.length) {
      // Leftmost pair merges first: [2,2,2,2] -> [4,4], not [8].
      if (i + 1 < nonZero.length && nonZero[i] == nonZero[i + 1]) {
        final merged = nonZero[i] * 2;
        result.add(merged);
        gained += merged;
        i += 2;
      } else {
        result.add(nonZero[i]);
        i++;
      }
    }
    while (result.length < size) {
      result.add(0);
    }
    return (result, gained);
  }

  List<List<int>> _snapshot() => [for (final row in _grid) List<int>.from(row)];
}

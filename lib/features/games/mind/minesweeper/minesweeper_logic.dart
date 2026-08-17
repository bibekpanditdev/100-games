/// Minesweeper pure logic — fully procedural, offline, first-tap-safe.
library;

import 'dart:math';

enum MsCellState { hidden, revealed, flagged }

class MinesweeperLogic {
  MinesweeperLogic({required this.size, required this.mineCount, Random? random})
      : assert(mineCount < size * size - 9, 'too many mines for a safe first tap'),
        _random = random ?? Random(),
        _mines = List.generate(size, (_) => List.filled(size, false)),
        _state = List.generate(size, (_) => List.filled(size, MsCellState.hidden)),
        _adjacent = List.generate(size, (_) => List.filled(size, 0));

  final int size;
  final int mineCount;
  final Random _random;

  final List<List<bool>> _mines;
  final List<List<MsCellState>> _state;
  final List<List<int>> _adjacent;

  bool _minesPlaced = false;
  bool _hitMine = false;
  int revealedCount = 0;
  int flaggedCount = 0;

  bool get hitMine => _hitMine;
  bool get won => !_hitMine && revealedCount == size * size - mineCount;
  bool get lost => _hitMine;

  bool isMine(int x, int y) => _mines[y][x];
  int adjacentMines(int x, int y) => _adjacent[y][x];
  MsCellState stateOf(int x, int y) => _state[y][x];

  bool _inBounds(int x, int y) => x >= 0 && y >= 0 && x < size && y < size;

  /// Mines are placed after the first reveal so the first tap (and its
  /// neighbors) is always safe.
  void _placeMines(int safeX, int safeY) {
    var placed = 0;
    while (placed < mineCount) {
      final x = _random.nextInt(size);
      final y = _random.nextInt(size);
      if (_mines[y][x]) continue;
      if ((x - safeX).abs() <= 1 && (y - safeY).abs() <= 1) continue;
      _mines[y][x] = true;
      placed++;
    }
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        var n = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (_inBounds(x + dx, y + dy) && _mines[y + dy][x + dx]) n++;
          }
        }
        _adjacent[y][x] = n;
      }
    }
    _minesPlaced = true;
  }

  /// Reveals a cell; flood-fills zero-adjacent regions. Returns the number
  /// of newly revealed cells (0 for an invalid action).
  int reveal(int x, int y) {
    if (!_inBounds(x, y) || hitMine || won) return 0;
    if (_state[y][x] != MsCellState.hidden) return 0;
    if (!_minesPlaced) _placeMines(x, y);

    if (_mines[y][x]) {
      _state[y][x] = MsCellState.revealed;
      _hitMine = true;
      return 1;
    }
    return _flood(x, y);
  }

  int _flood(int x, int y) {
    var count = 0;
    final stack = <[int, int]>[
      [x, y]
    ];
    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final px = pos[0];
      final py = pos[1];
      if (!_inBounds(px, py)) continue;
      if (_state[py][px] != MsCellState.hidden || _mines[py][px]) continue;
      _state[py][px] = MsCellState.revealed;
      count++;
      if (_adjacent[py][px] == 0) {
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            stack.add([px + dx, py + dy]);
          }
        }
      }
    }
    revealedCount += count;
    return count;
  }

  /// Toggles a flag. Returns true if the flag state changed.
  bool toggleFlag(int x, int y) {
    if (!_inBounds(x, y) || hitMine || won) return false;
    final s = _state[y][x];
    if (s == MsCellState.revealed) return false;
    if (s == MsCellState.hidden) {
      _state[y][x] = MsCellState.flagged;
      flaggedCount++;
    } else {
      _state[y][x] = MsCellState.hidden;
      flaggedCount--;
    }
    return true;
  }

  /// All mine coordinates (for the lose-reveal).
  List<(int, int)> minePositions() => [
        for (var y = 0; y < size; y++)
          for (var x = 0; x < size; x++)
            if (_mines[y][x]) (x, y),
      ];
}

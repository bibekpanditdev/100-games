/// Pure match-3 board rules: match detection, cascades, refill and hints.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// A pair of flat cell indices (a swap, or a hinted move).
typedef Match3Swap = ({int a, int b});

/// Outcome of one full cascade resolution.
class Match3ResolveResult {
  const Match3ResolveResult({
    required this.cascades,
    required this.cleared,
    required this.scoreGained,
  });

  /// Number of consecutive match waves that fired (>= 1).
  final int cascades;

  /// Total tiles cleared across all waves.
  final int cleared;

  /// 60 points per tile multiplied by the cascade wave (wave 1 = x1,
  /// wave 2 = x2, ...).
  final int scoreGained;
}

/// Classic match-3 grid of piece indices `0 .. pieceCount - 1`.
///
/// Cells are stored row-major; `-1` marks a hole mid-resolution.
class Match3Board {
  /// Creates a fresh board with no initial matches and at least one
  /// legal swap available.
  Match3Board({
    required this.rows,
    required this.cols,
    this.pieceCount = 6,
    required Random random,
  })  : assert(pieceCount >= 3, 'Need at least 3 piece kinds'),
        _random = random {
    _generateUntilPlayable();
  }

  /// Builds a board from an explicit grid (row-major) — used by tests.
  Match3Board.fromGrid({
    required List<List<int>> grid,
    this.pieceCount = 6,
    required Random random,
  })  : assert(grid.isNotEmpty && grid.first.isNotEmpty),
        rows = grid.length,
        cols = grid.first.length,
        _random = random {
    _cells = [for (final row in grid) ...row];
  }

  final int rows;
  final int cols;
  final int pieceCount;
  final Random _random;

  List<int> _cells = <int>[];

  int get cellCount => rows * cols;

  int pieceAt(int r, int c) => _cells[r * cols + c];

  int pieceAtFlat(int index) => _cells[index];

  /// True when two flat indices are orthogonally adjacent.
  bool isAdjacent(int a, int b) {
    final dr = (a ~/ cols) - (b ~/ cols);
    final dc = (a % cols) - (b % cols);
    return dr * dr + dc * dc == 1;
  }

  /// All cells belonging to a horizontal or vertical run of 3+ identical
  /// pieces. L and T shapes are the union of their two runs.
  Set<int> detectMatchedCells() {
    final matched = <int>{};
    for (var r = 0; r < rows; r++) {
      final base = r * cols;
      var runStart = 0;
      for (var c = 1; c <= cols; c++) {
        final ends = c == cols || _cells[base + c] != _cells[base + runStart];
        if (ends) {
          if (c - runStart >= 3 && _cells[base + runStart] >= 0) {
            for (var k = runStart; k < c; k++) {
              matched.add(base + k);
            }
          }
          runStart = c;
        }
      }
    }
    for (var c = 0; c < cols; c++) {
      var runStart = 0;
      for (var r = 1; r <= rows; r++) {
        final ends = r == rows ||
            _cells[r * cols + c] != _cells[runStart * cols + c];
        if (ends) {
          if (r - runStart >= 3 && _cells[runStart * cols + c] >= 0) {
            for (var k = runStart; k < r; k++) {
              matched.add(k * cols + c);
            }
          }
          runStart = r;
        }
      }
    }
    return matched;
  }

  /// A swap is legal when the cells are adjacent AND it creates a match.
  bool isValidSwap(int a, int b) {
    if (!isAdjacent(a, b)) return false;
    _swapCells(a, b);
    final createsMatch = detectMatchedCells().isNotEmpty;
    _swapCells(a, b);
    return createsMatch;
  }

  /// Swaps two cells unconditionally (the widget validates first).
  void applySwap(int a, int b) => _swapCells(a, b);

  /// Finds any legal swap, or null when the board is dead.
  Match3Swap? findValidMove() {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        if (c + 1 < cols && isValidSwap(i, i + 1)) {
          return (a: i, b: i + 1);
        }
        if (r + 1 < rows && isValidSwap(i, i + cols)) {
          return (a: i, b: i + cols);
        }
      }
    }
    return null;
  }

  bool hasValidMove() => findValidMove() != null;

  /// Resolves every cascade wave: clear matches, collapse columns, refill
  /// from the top, repeat while new matches form.
  Match3ResolveResult resolveMatches() {
    var cascades = 0;
    var cleared = 0;
    var score = 0;
    // The cap is a safety net; real cascades are far shorter.
    while (cascades < 64) {
      final matched = detectMatchedCells();
      if (matched.isEmpty) break;
      cascades += 1;
      cleared += matched.length;
      score += 60 * matched.length * cascades;
      for (final i in matched) {
        _cells[i] = -1;
      }
      _collapseAndRefill();
    }
    return Match3ResolveResult(
      cascades: cascades,
      cleared: cleared,
      scoreGained: score,
    );
  }

  /// Regenerates the whole board: no initial matches, at least one legal
  /// swap. Used on start-up and when the board dead-ends.
  void shuffle() => _generateUntilPlayable();

  void _generateUntilPlayable() {
    for (var attempt = 0; attempt < 1000; attempt++) {
      _generateInitialBoard();
      if (detectMatchedCells().isEmpty && hasValidMove()) return;
    }
  }

  /// Fills the grid left-to-right / top-to-bottom, avoiding any placement
  /// that would complete a 3-run with the already-filled neighbours.
  void _generateInitialBoard() {
    _cells = List<int>.filled(rows * cols, 0);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        var value = _random.nextInt(pieceCount);
        var guard = 0;
        while (_completesRunAt(r, c, value) && guard < pieceCount * 2) {
          value = (value + 1) % pieceCount;
          guard += 1;
        }
        _cells[r * cols + c] = value;
      }
    }
  }

  bool _completesRunAt(int r, int c, int value) {
    final twoLeft = c >= 2 && pieceAt(r, c - 1) == value && pieceAt(r, c - 2) == value;
    final twoUp = r >= 2 && pieceAt(r - 1, c) == value && pieceAt(r - 2, c) == value;
    return twoLeft || twoUp;
  }

  void _collapseAndRefill() {
    for (var c = 0; c < cols; c++) {
      var write = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        final value = _cells[r * cols + c];
        if (value != -1) {
          _cells[write * cols + c] = value;
          write -= 1;
        }
      }
      for (var r = write; r >= 0; r--) {
        _cells[r * cols + c] = _random.nextInt(pieceCount);
      }
    }
  }

  void _swapCells(int a, int b) {
    final tmp = _cells[a];
    _cells[a] = _cells[b];
    _cells[b] = tmp;
  }
}

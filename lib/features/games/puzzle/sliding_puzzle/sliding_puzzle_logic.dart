/// Pure n x n sliding puzzle (classic 15-puzzle) rules.
///
/// Shuffling walks random legal moves backwards from the solved state, so
/// every produced position is guaranteed solvable by construction.
library;

import 'dart:math';

/// State and rules for a numbered-tile sliding puzzle with one blank.
class SlidingPuzzle {
  /// Creates a shuffled, always-solvable puzzle.
  SlidingPuzzle({required this.size, required Random random})
      : assert(size >= 2, 'Minimum playable size is 2x2') {
    _cells = _solved(size);
    shuffle(random);
  }

  /// Builds a puzzle from explicit row-major tiles (0 = blank) — used by
  /// tests and tools. The tiles are taken as given (no solvability check).
  SlidingPuzzle.fromTiles({required this.size, required List<int> tiles})
      : assert(tiles.length == size * size, 'tiles must be size*size') {
    _cells = List<int>.of(tiles);
  }

  final int size;

  List<int> _cells = <int>[];
  int _moves = 0;

  /// Previous blank position — used to avoid undo-hint ties.
  int _lastBlank = -1;

  int get moves => _moves;

  int get blankIndex => _cells.indexOf(0);

  int tileAt(int r, int c) => _cells[r * size + c];

  int tileAtFlat(int index) => _cells[index];

  /// Read-only snapshot of the row-major tiles.
  List<int> get tiles => List<int>.unmodifiable(_cells);

  bool get isSolved {
    for (var i = 0; i < _cells.length - 1; i++) {
      if (_cells[i] != i + 1) return false;
    }
    return _cells.last == 0;
  }

  /// A tile can slide when it shares a row or column with the blank (the
  /// whole segment between it and the blank shifts over).
  bool canSlide(int index) {
    if (index < 0 || index >= _cells.length || _cells[index] == 0) {
      return false;
    }
    final blank = blankIndex;
    final sameRow = index ~/ size == blank ~/ size;
    final sameCol = index % size == blank % size;
    return sameRow || sameCol;
  }

  /// Slides the tile at [index] (and the segment between it and the blank)
  /// toward the blank. Returns the values of the tiles that moved, in
  /// order; empty list when the slide is illegal. Counts as one move.
  List<int> slideFrom(int index) {
    if (!canSlide(index)) return const <int>[];
    final blank = blankIndex;
    final br = blank ~/ size;
    final bc = blank % size;
    final r = index ~/ size;
    final c = index % size;
    final int step;
    if (r == br) {
      step = c > bc ? 1 : -1;
    } else {
      step = r > br ? size : -size;
    }
    final moved = <int>[];
    var pos = blank;
    while (pos != index) {
      final next = pos + step;
      moved.add(_cells[next]);
      _cells[pos] = _cells[next];
      pos = next;
    }
    _cells[index] = 0;
    _moves += 1;
    _lastBlank = blank;
    return moved;
  }

  /// Sum of each tile's grid distance from its goal cell (blank excluded).
  int manhattan() => _manhattanOf(_cells, size);

  /// Flat index of the tile whose slide is the best Manhattan-distance
  /// step toward the solution, or -1 when already solved. Ties avoid
  /// undoing the previous slide.
  int hintIndex() {
    if (isSolved) return -1;
    var bestIndex = -1;
    var bestScore = 1 << 30;
    for (var i = 0; i < _cells.length; i++) {
      if (!canSlide(i)) continue;
      final distance = _manhattanOf(_cellsAfterSlide(i), size);
      final score = distance * 2 + (i == _lastBlank ? 1 : 0);
      if (score < bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// Re-shuffles by walking random legal slides from the solved state.
  /// Solvability is guaranteed; the walk never immediately undoes itself.
  void shuffle(Random random) {
    do {
      _cells = _solved(size);
      _moves = 0;
      _lastBlank = -1;
      var previous = -1;
      final steps = size * size * 20;
      for (var i = 0; i < steps; i++) {
        final blank = blankIndex;
        final br = blank ~/ size;
        final bc = blank % size;
        final options = <int>[
          if (br > 0) blank - size,
          if (br < size - 1) blank + size,
          if (bc > 0) blank - 1,
          if (bc < size - 1) blank + 1,
        ]..removeWhere((t) => t == previous);
        final pick = options[random.nextInt(options.length)];
        slideFrom(pick);
        previous = blank;
      }
    } while (isSolved || manhattan() < size);
    _moves = 0;
    _lastBlank = -1;
  }

  static List<int> _solved(int n) =>
      List<int>.generate(n * n, (i) => i + 1)..[n * n - 1] = 0;

  static int _manhattanOf(List<int> cells, int n) {
    var total = 0;
    for (var i = 0; i < cells.length; i++) {
      final value = cells[i];
      if (value == 0) continue;
      final goal = value - 1;
      total += (i ~/ n - goal ~/ n).abs() + (i % n - goal % n).abs();
    }
    return total;
  }

  /// Tiles after sliding from [index], without mutating this puzzle.
  List<int> _cellsAfterSlide(int index) {
    final copy = List<int>.of(_cells);
    final blank = copy.indexOf(0);
    final br = blank ~/ size;
    final bc = blank % size;
    final r = index ~/ size;
    final c = index % size;
    final int step;
    if (r == br) {
      step = c > bc ? 1 : -1;
    } else {
      step = r > br ? size : -size;
    }
    var pos = blank;
    while (pos != index) {
      copy[pos] = copy[pos + step];
      pos += step;
    }
    copy[index] = 0;
    return copy;
  }
}

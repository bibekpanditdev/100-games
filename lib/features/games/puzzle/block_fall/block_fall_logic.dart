/// Pure block-fall (Tetris-lite) rules: 7 tetrominoes, rotation with
/// simple wall kicks, gravity, line clears, scoring and top-out.
///
/// Deterministic given a seeded [Random] — no Flutter imports.
library;

import 'dart:math';

/// A 2D grid position with row (r) and column (c).
class GridPos {
  const GridPos(this.r, this.c);

  final int r;
  final int c;
}

/// One tetromino kind: a bounding box and its base cell offsets.
///
/// Rotations are derived by rotating the offsets inside the box:
/// (r, c) -> (c, box - 1 - r) for a clockwise quarter turn.
class TetrominoDef {
  const TetrominoDef(this.box, this.baseCells);

  final int box;
  final List<GridPos> baseCells;

  List<List<GridPos>> rotations() {
    var cells = List<GridPos>.of(baseCells);
    final states = <List<GridPos>>[];
    for (var i = 0; i < 4; i++) {
      states.add(List<GridPos>.unmodifiable(cells));
      cells = [for (final p in cells) GridPos(p.c, box - 1 - p.r)];
    }
    return states;
  }
}

/// The classic seven tetrominoes in I, O, T, S, Z, J, L order.
/// The list index doubles as the piece (and colour) id.
const List<TetrominoDef> kTetrominoes = [
  TetrominoDef(4, [GridPos(1, 0), GridPos(1, 1), GridPos(1, 2), GridPos(1, 3)]),
  TetrominoDef(2, [GridPos(0, 0), GridPos(0, 1), GridPos(1, 0), GridPos(1, 1)]),
  TetrominoDef(3, [GridPos(0, 1), GridPos(1, 0), GridPos(1, 1), GridPos(1, 2)]),
  TetrominoDef(3, [GridPos(0, 1), GridPos(0, 2), GridPos(1, 0), GridPos(1, 1)]),
  TetrominoDef(3, [GridPos(0, 0), GridPos(0, 1), GridPos(1, 1), GridPos(1, 2)]),
  TetrominoDef(3, [GridPos(0, 0), GridPos(1, 0), GridPos(1, 1), GridPos(1, 2)]),
  TetrominoDef(3, [GridPos(0, 2), GridPos(1, 0), GridPos(1, 1), GridPos(1, 2)]),
];

/// Line-clear scores: 1 line = 100, 2 = 300, 3 = 500, 4 (tetris) = 800,
/// all multiplied by the current level.
const List<int> kLineScores = [0, 100, 300, 500, 800];

/// Grid-based falling-block game state. The grid holds piece ids or -1.
class BlockFallLogic {
  BlockFallLogic({
    required this.cols,
    this.rows = 18,
    required Random random,
  })  : assert(cols >= 6, 'Board too narrow for tetrominoes'),
        grid = List<List<int>>.generate(rows, (_) => List<int>.filled(cols, -1)),
        _random = random {
    start();
  }

  final int cols;
  final int rows;
  final List<List<int>> grid;
  final Random _random;
  final List<List<List<GridPos>>> _rotations = [
    for (final def in kTetrominoes) def.rotations(),
  ];

  int score = 0;
  int lines = 0;
  int level = 1;
  bool gameOver = false;

  /// Gravity speed in cells per second; the widget's ticker reads this.
  double gravitySpeed = 1.6;

  int? _type;
  int _rot = 0;
  int _row = 0;
  int _col = 0;
  int _nextType = 0;
  final List<int> _bag = <int>[];

  int? get activeType => _type;

  int get rotation => _rot;

  int get activeRow => _row;

  int get pieceCol => _col;

  int get nextType => _nextType;

  bool get hasActive => _type != null;

  /// Resets everything and spawns the first piece.
  void start() {
    for (final row in grid) {
      row.fillRange(0, cols, -1);
    }
    score = 0;
    lines = 0;
    level = 1;
    gameOver = false;
    _type = null;
    _bag.clear();
    _nextType = _drawFromBag();
    spawnNext();
  }

  /// Spawns the queued next piece at the top of the board.
  /// Returns false (and flags top-out) when it does not fit.
  bool spawnNext() => _spawn(_nextType, advanceQueue: true);

  /// Spawns a specific tetromino — used by tests and previews.
  bool spawn(int type) => _spawn(type, advanceQueue: false);

  bool _spawn(int type, {required bool advanceQueue}) {
    if (advanceQueue) {
      _nextType = _drawFromBag();
    }
    _type = type;
    _rot = 0;
    _row = 0;
    _col = (cols - kTetrominoes[type].box) ~/ 2;
    if (!_fits(type, _rot, _row, _col)) {
      _type = null;
      gameOver = true;
      return false;
    }
    return true;
  }

  /// 7-bag randomiser: every kind appears once per shuffled bag.
  int _drawFromBag() {
    if (_bag.isEmpty) {
      _bag.addAll(List<int>.generate(kTetrominoes.length, (i) => i));
      _bag.shuffle(_random);
    }
    return _bag.removeLast();
  }

  bool _fits(int type, int rot, int row, int col) {
    for (final p in _rotations[type][rot]) {
      final r = row + p.r;
      final c = col + p.c;
      if (c < 0 || c >= cols || r >= rows) return false;
      if (r >= 0 && grid[r][c] != -1) return false;
    }
    return true;
  }

  /// Moves the active piece by (dr, dc) when it fits.
  bool move(int dr, int dc) {
    final type = _type;
    if (type == null || gameOver) return false;
    if (!_fits(type, _rot, _row + dr, _col + dc)) return false;
    _row += dr;
    _col += dc;
    return true;
  }

  /// Rotates clockwise, kicking left/right by one when blocked.
  bool rotate() {
    final type = _type;
    if (type == null || gameOver) return false;
    final next = (_rot + 1) % 4;
    for (final kick in const [0, -1, 1]) {
      if (_fits(type, next, _row, _col + kick)) {
        _rot = next;
        _col += kick;
        return true;
      }
    }
    return false;
  }

  /// One gravity cell. Returns false when the piece could not descend and
  /// locked (a fresh piece has then been spawned).
  bool stepDown() {
    if (move(1, 0)) return true;
    lockPiece();
    return false;
  }

  /// Drops straight to the floor and locks. Returns cells travelled.
  int hardDrop() {
    var distance = 0;
    while (move(1, 0)) {
      distance += 1;
    }
    lockPiece();
    return distance;
  }

  /// Stamps the active piece into the grid, clears full lines, adds the
  /// score and spawns the next piece. Returns lines cleared by this lock.
  int lockPiece() {
    final type = _type;
    if (type == null) return 0;
    for (final p in _rotations[type][_rot]) {
      final r = _row + p.r;
      final c = _col + p.c;
      if (r >= 0 && r < rows && c >= 0 && c < cols) grid[r][c] = type;
    }
    _type = null;
    final cleared = _clearFullLines();
    lines += cleared;
    level = 1 + lines ~/ 10;
    score += kLineScores[cleared > 4 ? 4 : cleared] * level;
    spawnNext();
    return cleared;
  }

  int _clearFullLines() {
    var cleared = 0;
    for (var r = rows - 1; r >= 0; r--) {
      if (grid[r].every((v) => v != -1)) {
        grid.removeAt(r);
        grid.insert(0, List<int>.filled(cols, -1));
        cleared += 1;
        r += 1; // re-check the row that just shifted down
      }
    }
    return cleared;
  }

  /// Extra-life support: empties the top [count] rows and clears the
  /// top-out flag so a fresh piece can spawn.
  void clearTopRows(int count) {
    for (var r = 0; r < count && r < rows; r++) {
      grid[r].fillRange(0, cols, -1);
    }
    _type = null;
    gameOver = false;
  }

  /// Grid copy with the active piece stamped in, for rendering.
  List<List<int>> viewGrid() {
    final view = [for (final row in grid) List<int>.of(row)];
    final type = _type;
    if (type != null) {
      for (final p in _rotations[type][_rot]) {
        final r = _row + p.r;
        final c = _col + p.c;
        if (r >= 0 && r < rows && c >= 0 && c < cols) view[r][c] = type;
      }
    }
    return view;
  }
}

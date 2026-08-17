/// Pure connect-four rules: gravity drops, four-in-a-row detection in all
/// four directions and a three-tier CPU — level 3 combines immediate
/// win/block checks with a 4-ply minimax that prefers centre columns.
///
/// Deterministic given a seeded [Random]. No Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// Classic 7x6 drop-disc board.
class ConnectFourLogic {
  /// Creates an empty board for the given CPU strength.
  ConnectFourLogic({
    required this.aiLevel,
    required Random random,
    this.cols = 7,
    this.rows = 6,
  })  : assert(aiLevel >= 1 && aiLevel <= 3, 'aiLevel must be 1..3'),
        _random = random,
        board = List<int>.filled(cols * rows, 0);

  /// Test helper: builds a logic wrapping an explicit row-major grid
  /// (row 0 on top). The grid must be gravity-consistent.
  ConnectFourLogic.fromGrid({
    required List<int> grid,
    required this.aiLevel,
    required Random random,
    this.cols = 7,
    this.rows = 6,
  })  : assert(grid.length == cols * rows, 'grid must be cols*rows'),
        _random = random,
        board = List<int>.of(grid);

  /// 1 easy (centre-biased random), 2 medium (win / block), 3 hard
  /// (win / block + 4-ply minimax with centre preference).
  final int aiLevel;
  final Random _random;
  final int cols;
  final int rows;

  static const int player = 1;
  static const int cpu = 2;

  /// Row-major grid: 0 empty, [player] blue, [cpu] orange. Row 0 is the
  /// top; discs stack from `rows - 1` upward.
  final List<int> board;

  /// [player] or [cpu] once four-in-a-row exists, else null.
  int? winner;

  /// Flat index of the most recently dropped disc.
  int? lastMove;

  static const List<(int, int)> _directions = [
    (0, 1), // horizontal
    (1, 0), // vertical
    (1, 1), // diagonal down-right
    (1, -1), // diagonal down-left
  ];

  /// Column order used for ties: centre outwards.
  late final List<int> _centerOrder = _buildCenterOrder();

  List<int> _buildCenterOrder() {
    final mid = cols ~/ 2;
    final order = <int>[];
    for (var d = 0; d <= mid + 1; d++) {
      for (final col in [mid - d, mid + d]) {
        if (col >= 0 && col < cols && !order.contains(col)) order.add(col);
      }
    }
    return order;
  }

  bool get isDraw => winner == null && board.every((cell) => cell != 0);
  bool get isGameOver => winner != null || isDraw;

  /// Row a disc dropped into [col] would land on, or -1 when full/invalid.
  int landingRow(int col) {
    if (col < 0 || col >= cols) return -1;
    for (var r = rows - 1; r >= 0; r--) {
      if (board[r * cols + col] == 0) return r;
    }
    return -1;
  }

  bool canDrop(int col) => landingRow(col) >= 0;

  /// Drops [who] into [col]; returns the flat landing index or -1 when the
  /// move is illegal (full column, out of range, game over).
  int drop(int col, int who) {
    if (isGameOver) return -1;
    final idx = _place(col, who);
    if (idx < 0) return -1;
    lastMove = idx;
    if (winsAt(idx, who)) winner = who;
    return idx;
  }

  /// Player move. Returns true when applied.
  bool play(int col) => drop(col, player) >= 0;

  /// Computes and applies the CPU answer, returning the chosen column.
  int? cpuMove() {
    if (isGameOver) return null;
    final col = _pickColumn();
    if (col < 0) return null;
    drop(col, cpu);
    return col;
  }

  /// Best column for [who] (level-3 strength) — used for hints when
  /// [who] is [player].
  int bestColumnFor(int who) {
    final win = _immediateWinningColumn(who);
    if (win != null) return win;
    final block = _immediateWinningColumn(who == player ? cpu : player);
    if (block != null) return block;
    return _searchRoot(4, who);
  }

  /// True when a disc just placed at [idx] completes four in a row for
  /// [who] along any of the four directions.
  bool winsAt(int idx, int who) {
    final r = idx ~/ cols;
    final c = idx % cols;
    for (final (dr, dc) in _directions) {
      var count = 1;
      for (var s = 1; s < 4; s++) {
        final rr = r + dr * s;
        final cc = c + dc * s;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) break;
        if (board[rr * cols + cc] != who) break;
        count += 1;
      }
      for (var s = 1; s < 4; s++) {
        final rr = r - dr * s;
        final cc = c - dc * s;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) break;
        if (board[rr * cols + cc] != who) break;
        count += 1;
      }
      if (count >= 4) return true;
    }
    return false;
  }

  /// Scans the whole board for any four-in-a-row (test convenience).
  static int? boardWinner(List<int> b, {int cols = 7, int rows = 6}) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final who = b[r * cols + c];
        if (who == 0) continue;
        for (final (dr, dc) in _directions) {
          var count = 1;
          for (var s = 1; s < 4; s++) {
            final rr = r + dr * s;
            final cc = c + dc * s;
            if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) break;
            if (b[rr * cols + cc] != who) break;
            count += 1;
          }
          if (count >= 4) return who;
        }
      }
    }
    return null;
  }

  // -- CPU --------------------------------------------------------------------

  int _pickColumn() {
    switch (aiLevel) {
      case 3:
        return bestColumnFor(cpu);
      case 2:
        return _immediateWinningColumn(cpu) ??
            _immediateWinningColumn(player) ??
            _centerBiasedRandom();
      default:
        return _centerBiasedRandom();
    }
  }

  /// Column where [who] would immediately complete four, centre-first.
  int? _immediateWinningColumn(int who) {
    for (final col in _centerOrder) {
      final idx = _place(col, who);
      if (idx >= 0) {
        final wins = winsAt(idx, who);
        _remove(idx);
        if (wins) return col;
      }
    }
    return null;
  }

  /// Random legal column weighted towards the centre (weights 1..mid+1).
  int _centerBiasedRandom() {
    final mid = cols ~/ 2;
    final pool = <int>[
      for (final col in _centerOrder)
        if (canDrop(col))
          for (var w = mid + 1 - (col - mid).abs(); w > 0; w--) col,
    ];
    if (pool.isEmpty) return _centerOrder.first;
    return pool[_random.nextInt(pool.length)];
  }

  // -- minimax ----------------------------------------------------------------

  int _place(int col, int who) {
    final r = landingRow(col);
    if (r < 0) return -1;
    final idx = r * cols + col;
    board[idx] = who;
    return idx;
  }

  void _remove(int idx) => board[idx] = 0;

  bool get _full => board.every((cell) => cell != 0);

  /// 4-ply search; [root] maximises, the opponent minimises. Terminal wins
  /// score `1000 - ply` so faster wins are preferred; leaves score 0.
  int _searchRoot(int depth, int root) {
    var best = -100000;
    var bestCol = -1;
    for (final col in _centerOrder) {
      final idx = _place(col, root);
      if (idx < 0) continue;
      var score = 0;
      if (winsAt(idx, root)) {
        score = 1000;
      } else if (depth > 1 && !_full) {
        score = _search(depth - 1, 1, root == player ? cpu : player, root);
      }
      _remove(idx);
      if (score > best) {
        best = score;
        bestCol = col;
      }
    }
    return bestCol;
  }

  int _search(int depth, int ply, int turn, int root) {
    var best = turn == root ? -100000 : 100000;
    var anyLegal = false;
    for (final col in _centerOrder) {
      final idx = _place(col, turn);
      if (idx < 0) continue;
      anyLegal = true;
      var score = 0;
      if (winsAt(idx, turn)) {
        score = turn == root ? 1000 - ply : -(1000 - ply);
      } else if (depth > 1 && !_full) {
        score = _search(depth - 1, ply + 1, turn == player ? cpu : player, root);
      }
      _remove(idx);
      if (turn == root ? score > best : score < best) best = score;
    }
    return anyLegal ? best : 0;
  }
}

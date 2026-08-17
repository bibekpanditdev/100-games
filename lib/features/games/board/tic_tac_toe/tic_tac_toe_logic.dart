/// Pure tic-tac-toe rules: win detection over the eight lines and a
/// three-tier CPU — level 3 is a perfect minimax player that never loses.
///
/// Deterministic given a seeded [Random] (levels 1 and 2 roll dice; level 3
/// is fully deterministic). No Flutter imports, so it can be unit-tested
/// without pumping widgets.
library;

import 'dart:math';

/// The two players. The human always plays [TicTacToeLogic.player] (X) and
/// moves first; the CPU answers with [TicTacToeLogic.cpu] (O).
class TicTacToeLogic {
  TicTacToeLogic({required this.aiLevel, required Random random})
      : assert(aiLevel >= 1 && aiLevel <= 3, 'aiLevel must be 1..3'),
        _random = random;

  /// 1 easy (random with a spark of smartness), 2 medium (win / block),
  /// 3 perfect minimax.
  final int aiLevel;
  final Random _random;

  static const int player = 1;
  static const int cpu = 2;

  /// Row-major 3x3 grid: 0 empty, [player] X, [cpu] O.
  final List<int> board = List<int>.filled(9, 0);

  /// 1 or 2 once a line is complete, else null.
  int? winner;

  /// All eight winning index triples.
  static const List<List<int>> lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  bool get isDraw => winner == null && board.every((cell) => cell != 0);
  bool get isGameOver => winner != null || isDraw;

  /// Returns the owner of the first completed line in [b], else null.
  static int? winnerOf(List<int> b) {
    for (final line in lines) {
      final v = b[line[0]];
      if (v != 0 && v == b[line[1]] && v == b[line[2]]) return v;
    }
    return null;
  }

  /// The winning line indices, for highlighting the victory.
  List<int>? winningLine() {
    for (final line in lines) {
      final v = board[line[0]];
      if (v != 0 && v == board[line[1]] && v == board[line[2]]) {
        return List<int>.of(line);
      }
    }
    return null;
  }

  /// Places the player's mark. Returns false when the move is illegal.
  bool play(int index) {
    if (isGameOver || index < 0 || index > 8 || board[index] != 0) return false;
    board[index] = player;
    winner = winnerOf(board);
    return true;
  }

  /// Computes and applies the CPU's answer, returning the chosen index.
  int? cpuMove() {
    if (isGameOver) return null;
    final move = switch (aiLevel) {
      3 => _bestMove(cpu),
      2 => _mediumMove(),
      _ => _easyMove(),
    };
    board[move] = cpu;
    winner = winnerOf(board);
    return move;
  }

  /// Best move for the player (used by hints): minimax from X's side.
  int bestMoveForPlayer() {
    final empties = _emptyCells();
    if (empties.isEmpty) return -1;
    return _bestMove(player);
  }

  List<int> _emptyCells() =>
      [for (var i = 0; i < 9; i++) if (board[i] == 0) i];

  /// Easy: 30% perfect, otherwise a random empty cell.
  int _easyMove() {
    if (_random.nextInt(100) < 30) return _bestMove(cpu);
    return _randomChoice();
  }

  /// Medium: win if possible, block if needed, else random.
  int _mediumMove() => _winningSpot(cpu) ?? _winningSpot(player) ?? _randomChoice();

  int _randomChoice() => _emptyCells()[_random.nextInt(_emptyCells().length)];

  /// Index that would immediately complete a line for [who], else null.
  int? _winningSpot(int who) {
    for (var i = 0; i < 9; i++) {
      if (board[i] != 0) continue;
      board[i] = who;
      final wins = winnerOf(board) == who;
      board[i] = 0;
      if (wins) return i;
    }
    return null;
  }

  /// Minimax root for [who]: picks the move with the best guaranteed score.
  /// Ties resolve to the lowest index, which keeps level 3 deterministic.
  int _bestMove(int who) {
    var bestScore = -1000;
    var best = -1;
    for (var i = 0; i < 9; i++) {
      if (board[i] != 0) continue;
      board[i] = who;
      final score = _minimax(board, who == player ? cpu : player, 0);
      board[i] = 0;
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    return best;
  }

  /// Classic minimax scored from the PLAYER's perspective: a player win is
  /// positive (faster wins score higher), a CPU win negative, draws zero.
  int _minimax(List<int> b, int turn, int depth) {
    final w = winnerOf(b);
    if (w == player) return 10 - depth;
    if (w == cpu) return depth - 10;
    if (b.every((cell) => cell != 0)) return 0;
    final maximizing = turn == player;
    var best = maximizing ? -1000 : 1000;
    for (var i = 0; i < 9; i++) {
      if (b[i] != 0) continue;
      b[i] = turn;
      final score = _minimax(b, maximizing ? cpu : player, depth + 1);
      b[i] = 0;
      best = maximizing ? max(best, score) : min(best, score);
    }
    return best;
  }
}

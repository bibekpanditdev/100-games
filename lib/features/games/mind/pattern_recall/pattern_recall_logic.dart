/// Pure logic for pattern recall — distinct flash-set generation that grows
/// every three rounds (capped), order-irrelevant recall judging, per-round
/// scoring with a speed bonus and the 60% win threshold.
///
/// NO Flutter imports: plain Dart, testable with a seeded Random.
library;

import 'dart:math';

/// Result of tapping a cell during the recall phase.
enum PatternTapResult {
  /// Correct cell; more cells remain.
  correct,

  /// Correct cell; every flashed cell was recalled.
  roundComplete,

  /// Wrong cell — the round ends immediately (a fail).
  wrong,

  /// Tap outside an active recall phase or on an already-recalled cell.
  ignored,
}

class PatternRecallLogic {
  PatternRecallLogic({
    required this.grid,
    required this.baseCells,
    required this.totalRounds,
    required Random random,
  })  : _random = random,
        assert(grid >= 3 && grid <= 6, 'grid must be 3..6');

  /// Restores a run saved with [toMap]; null when [map] is invalid.
  static PatternRecallLogic? tryFromMap(Map<String, dynamic>? map,
      {required Random random}) {
    if (map == null) return null;
    final grid = map['grid'];
    final cells = map['cells'];
    final rounds = map['rounds'];
    final played = map['played'];
    final completed = map['completed'];
    final flash = map['flash'];
    final recalled = map['recalled'];
    final active = map['active'];
    if (grid is! int ||
        cells is! int ||
        rounds is! int ||
        played is! int ||
        completed is! int ||
        flash is! List ||
        recalled is! List ||
        active is! bool) {
      return null;
    }
    if (grid < 3 || grid > 6 || rounds < 1 || played < 0 || completed < 0) {
      return null;
    }
    final logic = PatternRecallLogic(
      grid: grid,
      baseCells: cells.clamp(1, grid * grid ~/ 2).toInt(),
      totalRounds: rounds,
      random: random,
    );
    logic._roundsPlayed = played;
    logic._roundsCompleted = completed;
    for (final c in flash) {
      if (c is int && c >= 0 && c < grid * grid) logic._flash.add(c);
    }
    for (final c in recalled) {
      if (c is int && c >= 0 && c < grid * grid) logic._recalled.add(c);
    }
    logic._roundActive = active && logic._flash.isNotEmpty;
    return logic;
  }

  final int grid;
  final int baseCells;
  final int totalRounds;
  final Random _random;

  final Set<int> _flash = <int>{};
  final Set<int> _recalled = <int>{};
  int _roundsPlayed = 0;
  int _roundsCompleted = 0;
  bool _roundActive = false;

  /// Cells flashing in the current round (empty between rounds).
  Set<int> get flashCells => Set.unmodifiable(_flash);

  /// Cells the player already recalled this round.
  Set<int> get recalledCells => Set.unmodifiable(_recalled);

  /// Rounds started (each round ends by completing, a wrong tap or timeout).
  int get roundsPlayed => _roundsPlayed;

  /// Rounds fully recalled.
  int get roundsCompleted => _roundsCompleted;

  bool get isRoundActive => _roundActive;

  bool get isDone => _roundsPlayed >= totalRounds;

  /// Cells the current (or next) round flashes.
  int get cellCount => cellCountForRound(_roundsPlayed == 0 ? 1 : _roundsPlayed);

  /// Flash count grows by one every three rounds, capped at half the grid.
  int cellCountForRound(int roundNumber) =>
      min(baseCells + (roundNumber - 1) ~/ 3, grid * grid ~/ 2);

  /// 60% of rounds must be completed to win (rounded up).
  int get winThreshold => (totalRounds * 0.6).ceil();

  bool get won => _roundsCompleted >= winThreshold;

  /// Starts the next round: [cellCountForRound] distinct random cells.
  Set<int> startRound() {
    final wanted = cellCountForRound(_roundsPlayed + 1);
    _flash.clear();
    while (_flash.length < wanted) {
      _flash.add(_random.nextInt(grid * grid));
    }
    _recalled.clear();
    _roundActive = true;
    _roundsPlayed += 1;
    return flashCells;
  }

  /// Judges a recall tap. Order is irrelevant; duplicates are ignored.
  PatternTapResult tap(int cell) {
    if (!_roundActive || cell < 0 || cell >= grid * grid) {
      return PatternTapResult.ignored;
    }
    if (_recalled.contains(cell)) return PatternTapResult.ignored;
    if (!_flash.contains(cell)) {
      _roundActive = false;
      return PatternTapResult.wrong;
    }
    _recalled.add(cell);
    if (_recalled.length == _flash.length) {
      _roundActive = false;
      _roundsCompleted += 1;
      return PatternTapResult.roundComplete;
    }
    return PatternTapResult.correct;
  }

  /// The recall window expired — the round counts as failed.
  void timeoutRound() => _roundActive = false;

  /// +100 for a completed round plus a speed bonus: 1 point per full 100 ms
  /// left on the recall clock, never negative.
  int roundScore({required int elapsedMs, required int windowMs}) =>
      100 + max(0, windowMs - elapsedMs) ~/ 100;

  /// Serialization for [GameSessionController.saveState] / resume.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'grid': grid,
        'cells': baseCells,
        'rounds': totalRounds,
        'played': _roundsPlayed,
        'completed': _roundsCompleted,
        'flash': _flash.toList(),
        'recalled': _recalled.toList(),
        'active': _roundActive,
      };
}

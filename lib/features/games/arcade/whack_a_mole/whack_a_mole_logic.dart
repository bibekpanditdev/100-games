/// Pure whack-a-mole rules: mole pop scheduling, hit/miss scoring and the
/// countdown win threshold.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// Whether a mole is currently up or the board rests between pops.
enum MolePhase { up, gap }

/// One whack-a-mole round: moles pop from [holes] for [spawnMs] at a time
/// while the [durationSec] countdown runs.
class WhackAMoleLogic {
  WhackAMoleLogic({
    required this.holes,
    required this.spawnMs,
    required this.durationSec,
    required Random random,
  }) : _random = random;

  /// Total hole count (9 or 12 in the catalog).
  final int holes;

  /// How long each mole stays up, in milliseconds.
  final int spawnMs;

  /// Round length in seconds.
  final int durationSec;

  static const int hitPoints = 15;
  static const int missPenalty = 5;
  static const int winPointsPerSec = 8;

  final Random _random;

  int score = 0;
  int hits = 0;
  int misses = 0;

  /// Hole index of the mole currently up, or -1 when the board is bare.
  int activeHole = -1;

  /// Total elapsed round time in milliseconds.
  int elapsedMs = 0;

  MolePhase _phase = MolePhase.gap;
  int _phaseMs = 0;
  int _lastHole = -1;

  /// Rest time between pops: two thirds of the up-window.
  int get gapMs => spawnMs * 2 ~/ 3;

  int get totalMs => durationSec * 1000;

  int get remainingSec => max(0, (totalMs - elapsedMs + 999) ~/ 1000);

  bool get isTimeUp => elapsedMs >= totalMs;

  /// Points needed to win the round.
  int get winThreshold => durationSec * winPointsPerSec;

  bool get won => score >= winThreshold;

  /// Advances the mole state machine and the countdown by [dtMs].
  void advance(int dtMs) {
    if (isTimeUp) return;
    elapsedMs = min(totalMs, elapsedMs + dtMs);
    _phaseMs += dtMs;
    if (isTimeUp) {
      activeHole = -1;
      _phase = MolePhase.gap;
      return;
    }
    if (_phase == MolePhase.up) {
      if (_phaseMs >= spawnMs) _retract();
    } else if (_phaseMs >= gapMs) {
      _pop();
    }
  }

  /// Whacks [hole]: +15 and an immediate retract on a hit, -5 (floored at
  /// zero) for smacking an empty hole. Returns whether the mole was hit.
  bool whack(int hole) {
    if (isTimeUp) return false;
    if (activeHole != -1 && hole == activeHole) {
      score += hitPoints;
      hits += 1;
      _retract();
      return true;
    }
    score = max(0, score - missPenalty);
    misses += 1;
    return false;
  }

  void _pop() {
    var hole = _random.nextInt(holes);
    var guard = 0;
    // Consecutive moles never reuse the same hole.
    while (hole == _lastHole && holes > 1 && guard < 8) {
      hole = _random.nextInt(holes);
      guard += 1;
    }
    _lastHole = hole;
    activeHole = hole;
    _phase = MolePhase.up;
    _phaseMs = 0;
  }

  void _retract() {
    activeHole = -1;
    _phase = MolePhase.gap;
    _phaseMs = 0;
  }
}

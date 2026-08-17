/// Pure tap-reflex rules: per-round target windows, speed-bonus scoring,
/// lives and average reaction stats.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// Where the round state machine currently sits.
enum TapReflexPhase { starting, targetUp, betweenRounds, over }

/// Reaction-time game: [rounds] targets appear one at a time for
/// [windowMs] each. Tapping in time scores 100 plus a speed bonus; every
/// miss costs one of three lives.
class TapReflexLogic {
  TapReflexLogic({
    required this.rounds,
    required this.windowMs,
    required Random random,
  }) : _random = random;

  /// Total targets per session (10 / 12 / 15 in the catalog).
  final int rounds;

  /// How long each target stays on screen, in milliseconds.
  final int windowMs;

  static const int basePoints = 100;
  static const int maxBonus = 50;
  static const int startLives = 3;
  static const int startDelayMs = 400;
  static const int gapMs = 450;

  final Random _random;

  int lives = startLives;
  int score = 0;

  /// Rounds fully played (hit or missed).
  int roundsPlayed = 0;

  TapReflexPhase phase = TapReflexPhase.starting;

  /// Current target position, normalised 0..1 inside the play area.
  double targetX = 0.5;
  double targetY = 0.5;

  /// Successful reaction times in milliseconds.
  final List<int> reactionMs = <int>[];

  int _phaseMs = 0;

  /// Speed bonus for reacting in [reactionMs] out of [windowMs]: the full
  /// [maxBonus] instantly, zero at the deadline, clamped in between.
  static int bonusFor(int reactionMs, int windowMs) {
    if (windowMs <= 0) return 0;
    final bonus = (maxBonus * (1 - reactionMs / windowMs)).round();
    return bonus < 0 ? 0 : (bonus > maxBonus ? maxBonus : bonus);
  }

  /// Total points for a reaction: base plus the speed bonus.
  static int pointsFor(int reactionMs, int windowMs) =>
      basePoints + bonusFor(reactionMs, windowMs);

  int get avgReactionMs => reactionMs.isEmpty
      ? 0
      : (reactionMs.reduce((a, b) => a + b) / reactionMs.length).round();

  /// Milliseconds the current target has been up (for HUD display).
  int get elapsedInWindowMs => _phaseMs;

  bool get isOver => phase == TapReflexPhase.over;

  /// Won when every round was played and at least one life remains.
  bool get won => isOver && lives > 0 && roundsPlayed >= rounds;

  /// Advances the state machine by [dtMs]: starts rounds, expires targets.
  void advance(int dtMs) {
    if (isOver) return;
    _phaseMs += dtMs;
    switch (phase) {
      case TapReflexPhase.starting:
        if (_phaseMs >= startDelayMs) _beginRound();
      case TapReflexPhase.targetUp:
        if (_phaseMs >= windowMs) _onTimeout();
      case TapReflexPhase.betweenRounds:
        if (_phaseMs >= gapMs) _beginRound();
      case TapReflexPhase.over:
        break;
    }
  }

  /// Registers a tap on the target. Returns the reaction time in
  /// milliseconds, or -1 when no target was up.
  int tapTarget() {
    if (phase != TapReflexPhase.targetUp) return -1;
    final reaction = _phaseMs;
    reactionMs.add(reaction);
    score += pointsFor(reaction, windowMs);
    _completeRound();
    return reaction;
  }

  void _onTimeout() {
    lives -= 1;
    _completeRound();
  }

  void _completeRound() {
    roundsPlayed += 1;
    if (lives <= 0 || roundsPlayed >= rounds) {
      phase = TapReflexPhase.over;
      return;
    }
    phase = TapReflexPhase.betweenRounds;
    _phaseMs = 0;
  }

  void _beginRound() {
    targetX = 0.15 + _random.nextDouble() * 0.7;
    targetY = 0.15 + _random.nextDouble() * 0.7;
    phase = TapReflexPhase.targetUp;
    _phaseMs = 0;
  }
}

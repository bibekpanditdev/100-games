import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/arcade/tap_reflex/tap_reflex_logic.dart';

TapReflexLogic makeLogic({
  int rounds = 10,
  int windowMs = 1000,
  int seed = 1,
}) =>
    TapReflexLogic(
      rounds: rounds,
      windowMs: windowMs,
      random: Random(seed),
    );

/// Advances in 50 ms steps until a target is up.
void bringTargetUp(TapReflexLogic logic) {
  var guard = 0;
  while (logic.phase != TapReflexPhase.targetUp && guard < 100) {
    logic.advance(50);
    guard += 1;
  }
  expect(logic.phase, TapReflexPhase.targetUp);
}

void main() {
  group('scoring math', () {
    test('an instant reaction earns the full bonus', () {
      expect(TapReflexLogic.pointsFor(0, 1000),
          TapReflexLogic.basePoints + TapReflexLogic.maxBonus);
    });

    test('a deadline reaction earns no bonus', () {
      expect(TapReflexLogic.pointsFor(1000, 1000), TapReflexLogic.basePoints);
    });

    test('the bonus scales linearly with the remaining fraction', () {
      expect(TapReflexLogic.pointsFor(250, 1000),
          TapReflexLogic.basePoints + 38); // 50 * 0.75 rounds to 38
      expect(TapReflexLogic.pointsFor(500, 1000),
          TapReflexLogic.basePoints + 25);
      expect(TapReflexLogic.pointsFor(750, 1000),
          TapReflexLogic.basePoints + 13); // 50 * 0.25 rounds 12.5 -> 13
    });

    test('the bonus is clamped to 0..50', () {
      expect(TapReflexLogic.bonusFor(1500, 1000), 0);
      expect(TapReflexLogic.bonusFor(-100, 1000), 50);
      expect(TapReflexLogic.bonusFor(500, 0), 0); // degenerate window
    });
  });

  group('rounds', () {
    test('the target appears after the start delay within the board', () {
      final logic = makeLogic();
      logic.advance(TapReflexLogic.startDelayMs - 1);
      expect(logic.phase, TapReflexPhase.starting);
      logic.advance(1);
      expect(logic.phase, TapReflexPhase.targetUp);
      expect(logic.targetX, inInclusiveRange(0.15, 0.85));
      expect(logic.targetY, inInclusiveRange(0.15, 0.85));
    });

    test('tapping in time scores and advances the round', () {
      final logic = makeLogic();
      bringTargetUp(logic);
      logic.advance(250); // react after 250 ms
      final reaction = logic.tapTarget();
      expect(reaction, 250);
      expect(logic.score, TapReflexLogic.pointsFor(250, 1000));
      expect(logic.roundsPlayed, 1);
      expect(logic.phase, TapReflexPhase.betweenRounds);
      expect(logic.lives, TapReflexLogic.startLives);
    });

    test('taps outside the target window are ignored', () {
      final logic = makeLogic();
      expect(logic.tapTarget(), -1);
      expect(logic.score, 0);
      expect(logic.roundsPlayed, 0);
    });

    test('a timeout costs a life but keeps the round moving', () {
      final logic = makeLogic();
      bringTargetUp(logic);
      logic.advance(999);
      expect(logic.phase, TapReflexPhase.targetUp); // not yet
      logic.advance(1);
      expect(logic.phase, TapReflexPhase.betweenRounds);
      expect(logic.lives, TapReflexLogic.startLives - 1);
      expect(logic.roundsPlayed, 1);
      expect(logic.reactionMs, isEmpty);
    });

    test('the next target appears after the between-rounds gap', () {
      final logic = makeLogic();
      bringTargetUp(logic);
      logic.tapTarget();
      expect(logic.phase, TapReflexPhase.betweenRounds);
      logic.advance(TapReflexLogic.gapMs - 1);
      expect(logic.phase, TapReflexPhase.betweenRounds);
      logic.advance(1);
      expect(logic.phase, TapReflexPhase.targetUp);
    });

    test('finishing every round wins while a life remains', () {
      final logic = makeLogic(rounds: 3);
      for (var i = 0; i < 3; i++) {
        bringTargetUp(logic);
        logic.advance(200);
        logic.tapTarget();
      }
      expect(logic.isOver, isTrue);
      expect(logic.won, isTrue);
      expect(logic.roundsPlayed, 3);
    });

    test('losing all lives ends the game early as a defeat', () {
      final logic = makeLogic(rounds: 10);
      for (var i = 0; i < 3; i++) {
        bringTargetUp(logic);
        logic.advance(1200); // let every target time out
      }
      expect(logic.isOver, isTrue);
      expect(logic.won, isFalse);
      expect(logic.lives, 0);
      expect(logic.roundsPlayed, 3);
    });
  });

  group('stats', () {
    test('average reaction covers only successful taps', () {
      final logic = makeLogic(rounds: 4);
      bringTargetUp(logic);
      logic.tapTarget(); // reaction 0 ms
      bringTargetUp(logic);
      logic.advance(400);
      logic.tapTarget(); // reaction 400 ms
      bringTargetUp(logic);
      logic.advance(1200); // miss
      expect(logic.isOver, isFalse); // one round + lives left
      bringTargetUp(logic);
      logic.advance(200);
      logic.tapTarget(); // reaction 200 ms
      final sum = logic.reactionMs.reduce((a, b) => a + b);
      expect(logic.avgReactionMs, (sum / logic.reactionMs.length).round());
      expect(logic.avgReactionMs, 200);
      expect(logic.reactionMs.length, 3);
    });

    test('target positions vary across rounds', () {
      final logic = makeLogic(rounds: 6);
      final xs = <double>[];
      for (var i = 0; i < 6; i++) {
        bringTargetUp(logic);
        xs.add(logic.targetX);
        logic.tapTarget();
      }
      expect(xs.toSet().length, greaterThan(1));
      for (final x in xs) {
        expect(x, inInclusiveRange(0.15, 0.85));
      }
    });

    test('is deterministic for a fixed seed', () {
      List<double> trace(int seed) {
        final logic = makeLogic(rounds: 4, seed: seed);
        final xs = <double>[];
        for (var i = 0; i < 4; i++) {
          bringTargetUp(logic);
          xs.add(logic.targetX);
          logic.tapTarget();
        }
        return xs;
      }

      expect(trace(5), trace(5));
    });
  });
}

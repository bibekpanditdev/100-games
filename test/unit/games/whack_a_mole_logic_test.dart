import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/arcade/whack_a_mole/whack_a_mole_logic.dart';

WhackAMoleLogic makeLogic({
  int holes = 9,
  int spawnMs = 900,
  int durationSec = 45,
  int seed = 1,
}) =>
    WhackAMoleLogic(
      holes: holes,
      spawnMs: spawnMs,
      durationSec: durationSec,
      random: Random(seed),
    );

/// Brings the logic to a state where a mole is up (or fails the test).
void bringMoleUp(WhackAMoleLogic logic) {
  var guard = 0;
  while (logic.activeHole == -1 && guard < 100) {
    logic.advance(50);
    guard += 1;
  }
  expect(logic.activeHole, isNot(-1));
}

void main() {
  group('spawn scheduling', () {
    test('first mole pops after the gap and stays up for the window', () {
      final logic = makeLogic(); // gap = 900 * 2 / 3 = 600 ms
      expect(logic.activeHole, -1);
      logic.advance(logic.gapMs - 1);
      expect(logic.activeHole, -1);
      logic.advance(1);
      expect(logic.activeHole, inInclusiveRange(0, logic.holes - 1));
      final hole = logic.activeHole;
      logic.advance(logic.spawnMs - 1);
      expect(logic.activeHole, hole); // still up
      logic.advance(1);
      expect(logic.activeHole, -1); // retracted
    });

    test('the next mole pops after another gap', () {
      final logic = makeLogic();
      bringMoleUp(logic);
      logic.advance(logic.spawnMs); // retract
      expect(logic.activeHole, -1);
      logic.advance(logic.gapMs - 1);
      expect(logic.activeHole, -1);
      logic.advance(1);
      expect(logic.activeHole, inInclusiveRange(0, logic.holes - 1));
    });

    test('consecutive moles never reuse the same hole', () {
      final logic = makeLogic(spawnMs: 500, durationSec: 60);
      var last = -1;
      var pops = 0;
      while (!logic.isTimeUp && pops < 40) {
        logic.advance(50);
        if (logic.activeHole != -1 && logic.activeHole != last) {
          if (last != -1) {
            expect(logic.activeHole, isNot(last));
          }
          last = logic.activeHole;
          pops += 1;
          logic.advance(logic.spawnMs); // force the retract
        }
      }
      expect(pops, greaterThan(3));
    });

    test('is deterministic for a fixed seed', () {
      int trace(int seed) {
        final logic = makeLogic(spawnMs: 700, durationSec: 10, seed: seed);
        var sum = 0;
        for (var i = 0; i < 300; i++) {
          logic.advance(50);
          sum += logic.activeHole;
        }
        return sum;
      }

      expect(trace(7), trace(7));
      expect(trace(7), isNot(trace(8)));
    });
  });

  group('scoring', () {
    test('hitting the mole scores 15, retracts and counts a hit', () {
      final logic = makeLogic();
      bringMoleUp(logic);
      final hole = logic.activeHole;
      expect(logic.whack(hole), isTrue);
      expect(logic.score, WhackAMoleLogic.hitPoints);
      expect(logic.hits, 1);
      expect(logic.activeHole, -1);
    });

    test('tapping an empty hole costs 5 but floors at zero', () {
      final logic = makeLogic();
      bringMoleUp(logic);
      final moleHole = logic.activeHole;
      final emptyHole = (moleHole + 1) % logic.holes;
      expect(logic.whack(emptyHole), isFalse);
      expect(logic.score, 0); // floored, not negative
      expect(logic.misses, 1);
      // Hit twice, then miss twice: 30 - 10 = 20.
      bringMoleUp(logic);
      logic.whack(logic.activeHole);
      bringMoleUp(logic);
      logic.whack(logic.activeHole);
      logic.whack(emptyHole);
      logic.whack(emptyHole);
      expect(logic.score, 2 * WhackAMoleLogic.hitPoints - 2 * 5);
      expect(logic.misses, 3);
    });

    test('the win threshold is 8 points per second of duration', () {
      final logic = makeLogic(durationSec: 45);
      expect(logic.winThreshold, 45 * 8);
      logic.score = logic.winThreshold - 1;
      expect(logic.won, isFalse);
      logic.score = logic.winThreshold;
      expect(logic.won, isTrue);
    });
  });

  group('countdown', () {
    test('remaining seconds count down and clamp at zero', () {
      final logic = makeLogic(spawnMs: 700, durationSec: 10);
      expect(logic.remainingSec, 10);
      logic.advance(1000);
      expect(logic.remainingSec, 9);
      logic.advance(8999);
      expect(logic.remainingSec, 1);
      logic.advance(1);
      expect(logic.isTimeUp, isTrue);
      expect(logic.remainingSec, 0);
    });

    test('time up retracts the mole and freezes the board', () {
      final logic = makeLogic(spawnMs: 900, durationSec: 2);
      bringMoleUp(logic);
      // Burn the remaining time.
      var guard = 0;
      while (!logic.isTimeUp && guard < 200) {
        logic.advance(50);
        guard += 1;
      }
      expect(logic.isTimeUp, isTrue);
      expect(logic.activeHole, -1);
      final score = logic.score;
      final hits = logic.hits;
      logic.advance(500);
      expect(logic.score, score);
      expect(logic.hits, hits);
      expect(logic.whack(0), isFalse); // no penalty after the buzzer
      expect(logic.score, score);
    });
  });
}

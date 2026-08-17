/// Unit tests for the odd-one-out pure-logic class — odd-tile generation
/// (exactly one tile, differing by shape AND colour), round timing math,
/// scoring floored at zero and the 60% win threshold.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/mind/odd_one_out/odd_one_out_logic.dart';

OddOneOutLogic newLogic({
  int items = 6,
  int rounds = 8,
  int seed = 1,
}) =>
    OddOneOutLogic(items: items, totalRounds: rounds, random: Random(seed));

void main() {
  group('odd-one generation', () {
    test('exactly one tile differs — in shape AND colour, never colour-only',
        () {
      for (var seed = 1; seed <= 60; seed++) {
        final logic = newLogic(items: 9, seed: seed);
        final tiles = logic.startRound();
        expect(tiles.length, 9);

        // The group majority is every tile except one.
        final counts = <OddTile, int>{};
        for (final tile in tiles) {
          counts[tile] = (counts[tile] ?? 0) + 1;
        }
        expect(counts.length, 2, reason: 'seed $seed: need exactly 2 tile kinds');
        final sorted = counts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final group = sorted.first.key;
        final odd = sorted.last.key;
        expect(sorted.first.value, 8, reason: 'seed $seed: eight group tiles');
        expect(sorted.last.value, 1, reason: 'seed $seed: one odd tile');

        // Shape must differ — colour alone is never enough.
        expect(odd.shape, isNot(group.shape),
            reason: 'seed $seed: odd tile must differ in shape');
        expect(odd.color, isNot(group.color),
            reason: 'seed $seed: odd tile also differs in colour');

        expect(tiles[logic.oddIndex], odd, reason: 'oddIndex points at it');
        expect(logic.isRoundActive, isTrue);
      }
    });

    test('indices and shape/colour ids stay in range', () {
      for (var seed = 1; seed <= 40; seed++) {
        final logic = newLogic(items: 12, rounds: 12, seed: seed);
        final tiles = logic.startRound();
        expect(logic.oddIndex, inInclusiveRange(0, 11));
        for (final tile in tiles) {
          expect(tile.shape, inInclusiveRange(0, OddOneOutLogic.shapeCount - 1));
          expect(tile.color, inInclusiveRange(0, OddOneOutLogic.colorCount - 1));
        }
      }
    });

    test('consecutive rounds re-shuffle the odd tile position', () {
      final logic = newLogic(seed: 77);
      final positions = <int>{};
      for (var i = 0; i < 15; i++) {
        logic.startRound();
        positions.add(logic.oddIndex);
      }
      expect(positions.length, greaterThan(1),
          reason: 'the odd tile must move between rounds');
      expect(logic.round, 15);
    });
  });

  group('round timing math', () {
    test('window shrinks 100 ms per round, floored at 700 ms', () {
      expect(OddOneOutLogic.windowMsForRound(1), 1300);
      expect(OddOneOutLogic.windowMsForRound(2), 1200);
      expect(OddOneOutLogic.windowMsForRound(3), 1100);
      expect(OddOneOutLogic.windowMsForRound(6), 800);
      expect(OddOneOutLogic.windowMsForRound(7), 700);
      expect(OddOneOutLogic.windowMsForRound(8), 700);
      expect(OddOneOutLogic.windowMsForRound(20), 700);
    });

    test('the window is monotonically non-increasing', () {
      var previous = OddOneOutLogic.windowMsForRound(1);
      for (var r = 2; r <= 30; r++) {
        final current = OddOneOutLogic.windowMsForRound(r);
        expect(current, lessThanOrEqualTo(previous));
        previous = current;
      }
    });
  });

  group('tap judging', () {
    test('tapping the odd tile finds it and ends the round', () {
      final logic = newLogic(seed: 2);
      logic.startRound();
      expect(logic.tap(logic.oddIndex), OddTapResult.found);
      expect(logic.found, 1);
      expect(logic.isRoundActive, isFalse);
      expect(logic.tap(logic.oddIndex), OddTapResult.ignored);
    });

    test('wrong taps penalize but the round continues', () {
      final logic = newLogic(seed: 4);
      logic.startRound();
      final wrong = (logic.oddIndex + 1) % logic.items;
      expect(logic.tap(wrong), OddTapResult.wrong);
      expect(logic.isRoundActive, isTrue);
      expect(logic.found, 0);
      expect(logic.tap(logic.oddIndex), OddTapResult.found);
    });

    test('out-of-range taps and taps between rounds are ignored', () {
      final logic = newLogic(seed: 6);
      expect(logic.tap(0), OddTapResult.ignored);
      logic.startRound();
      expect(logic.tap(-1), OddTapResult.ignored);
      expect(logic.tap(99), OddTapResult.ignored);
    });

    test('timeout misses the round', () {
      final logic = newLogic(seed: 8);
      logic.startRound();
      logic.timeoutRound();
      expect(logic.isRoundActive, isFalse);
      expect(logic.found, 0);
      expect(logic.round, 1);
    });
  });

  group('scoring with floor at 0', () {
    test('+80 per find, -20 per wrong tap, never below zero', () {
      expect(OddOneOutLogic.scoreAfter(score: 0, found: true), 80);
      expect(OddOneOutLogic.scoreAfter(score: 100, found: true), 180);
      expect(OddOneOutLogic.scoreAfter(score: 100, found: false), 80);
      expect(OddOneOutLogic.scoreAfter(score: 20, found: false), 0);
      expect(OddOneOutLogic.scoreAfter(score: 0, found: false), 0,
          reason: 'floor at zero');
    });

    test('a full session of wrong taps never goes negative', () {
      var score = 0;
      for (var i = 0; i < 50; i++) {
        score = OddOneOutLogic.scoreAfter(score: score, found: i.isEven);
      }
      expect(score, greaterThanOrEqualTo(0));
      expect(score, 80 * 25 - 20 * 25); // 25 finds at 80, 25 misses capped at 0
    });
  });

  group('win threshold (60% of rounds, rounded up)', () {
    test('threshold math', () {
      expect(newLogic(rounds: 8).winThreshold, 5); // ceil(4.8)
      expect(newLogic(rounds: 10).winThreshold, 6);
      expect(newLogic(rounds: 12).winThreshold, 8); // ceil(7.2)
    });

    test('finding 6 of 10 wins; 5 loses', () {
      OddOneOutLogic play(int finds, int misses, int seed) {
        final logic = newLogic(rounds: 10, seed: seed);
        while (!logic.isDone) {
          logic.startRound();
          if (logic.found < finds) {
            logic.tap(logic.oddIndex);
          } else if (misses > 0) {
            logic.tap((logic.oddIndex + 1) % logic.items);
            logic.timeoutRound();
            misses--;
          } else {
            logic.timeoutRound();
          }
        }
        return logic;
      }

      final won = play(6, 0, 11);
      expect(won.round, 10);
      expect(won.found, 6);
      expect(won.won, isTrue);

      final lost = play(5, 3, 13);
      expect(lost.found, 5);
      expect(lost.won, isFalse);
      expect(lost.isDone, isTrue);
    });
  });

  group('serialization snapshot', () {
    test('toMap captures progress', () {
      final logic = newLogic(items: 9, rounds: 12, seed: 19);
      logic.startRound();
      logic.tap(logic.oddIndex);
      logic.startRound();
      final map = logic.toMap();
      expect(map['items'], 9);
      expect(map['rounds'], 12);
      expect(map['round'], 2);
      expect(map['found'], 1);
    });
  });
}

/// Unit tests for the pattern-recall pure-logic class — flash-set
/// generation, growth every three rounds (capped), recall judging, round
/// scoring and the 60% win threshold.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/mind/pattern_recall/pattern_recall_logic.dart';

PatternRecallLogic newLogic({
  int grid = 4,
  int cells = 4,
  int rounds = 10,
  int seed = 1,
}) =>
    PatternRecallLogic(
      grid: grid,
      baseCells: cells,
      totalRounds: rounds,
      random: Random(seed),
    );

/// Finds a cell that is NOT part of the current flash set.
int nonFlashCell(PatternRecallLogic logic) {
  for (var c = 0; c < logic.grid * logic.grid; c++) {
    if (!logic.flashCells.contains(c)) return c;
  }
  throw StateError('no non-flash cell — flash covers the grid');
}

void main() {
  group('flash set generation', () {
    test('flashes exactly the round\'s cell count of distinct cells', () {
      for (var seed = 1; seed <= 40; seed++) {
        final logic = newLogic(grid: 5, cells: 6, rounds: 12, seed: seed);
        for (var round = 1; round <= 12; round++) {
          final flash = logic.startRound();
          expect(flash.length, logic.cellCountForRound(round),
              reason: 'round $round, seed $seed');
          expect(flash.toSet().length, flash.length,
              reason: 'cells must be distinct');
          for (final cell in flash) {
            expect(cell, inInclusiveRange(0, 24));
          }
        }
      }
    });

    test('cell count grows by one every three rounds', () {
      final logic = newLogic(grid: 6, cells: 4, rounds: 12);
      expect(logic.cellCountForRound(1), 4);
      expect(logic.cellCountForRound(3), 4);
      expect(logic.cellCountForRound(4), 5);
      expect(logic.cellCountForRound(6), 5);
      expect(logic.cellCountForRound(7), 6);
      expect(logic.cellCountForRound(9), 6);
      expect(logic.cellCountForRound(10), 7);
      expect(logic.cellCountForRound(12), 7);
      expect(logic.cellCountForRound(13), 8);
    });

    test('growth is capped at half the grid', () {
      final logic = newLogic(grid: 4, cells: 4, rounds: 20);
      expect(logic.cellCountForRound(13), 8); // grid*grid/2
      expect(logic.cellCountForRound(50), 8, reason: 'never exceeds the cap');
      final dense = newLogic(grid: 4, cells: 9, rounds: 10);
      expect(dense.cellCountForRound(1), 8,
          reason: 'base cells are clamped by the cap too');
    });

    test('same seed replays the same flash sets', () {
      final a = newLogic(seed: 31);
      final b = newLogic(seed: 31);
      a.startRound();
      b.startRound();
      expect(a.flashCells, b.flashCells);
    });
  });

  group('recall judging', () {
    test('tapping every flashed cell completes the round (order-free)', () {
      final logic = newLogic(seed: 3);
      final flash = logic.startRound();
      final order = flash.toList().reversed.toList();
      for (var i = 0; i < order.length - 1; i++) {
        expect(logic.tap(order[i]), PatternTapResult.correct);
      }
      expect(logic.tap(order.last), PatternTapResult.roundComplete);
      expect(logic.tap(flash.first), PatternTapResult.ignored,
          reason: 'the round already completed');
      expect(logic.roundsCompleted, 1);
    });

    test('any wrong tap fails the round immediately', () {
      final logic = newLogic(seed: 5);
      logic.startRound();
      final flash = logic.flashCells;
      logic.tap(flash.first);
      expect(logic.tap(nonFlashCell(logic)), PatternTapResult.wrong);
      expect(logic.isRoundActive, isFalse);
      expect(logic.roundsCompleted, 0);
      expect(logic.roundsPlayed, 1);
      // No further taps count.
      expect(logic.tap(flash.last), PatternTapResult.ignored);
    });

    test('duplicate taps and out-of-range taps are ignored', () {
      final logic = newLogic(seed: 8);
      logic.startRound();
      final cell = logic.flashCells.first;
      expect(logic.tap(cell), PatternTapResult.correct);
      expect(logic.tap(cell), PatternTapResult.ignored);
      expect(logic.tap(-1), PatternTapResult.ignored);
      expect(logic.tap(99), PatternTapResult.ignored);
      expect(logic.roundsCompleted, 0, reason: 'round still in progress');
    });

    test('timeout fails the round without completing it', () {
      final logic = newLogic(seed: 12);
      logic.startRound();
      logic.timeoutRound();
      expect(logic.isRoundActive, isFalse);
      expect(logic.roundsCompleted, 0);
      expect(logic.roundsPlayed, 1);
      expect(logic.isDone, isFalse);
    });
  });

  group('round scoring', () {
    test('+100 plus one point per full 100 ms left on the clock', () {
      final logic = newLogic();
      expect(logic.roundScore(elapsedMs: 0, windowMs: 8000), 180);
      expect(logic.roundScore(elapsedMs: 1200, windowMs: 8000), 168);
      expect(logic.roundScore(elapsedMs: 7999, windowMs: 8000), 100);
      expect(logic.roundScore(elapsedMs: 8000, windowMs: 8000), 100);
      expect(logic.roundScore(elapsedMs: 9000, windowMs: 8000), 100,
          reason: 'speed bonus must never go negative');
    });
  });

  group('win threshold (60% of rounds, rounded up)', () {
    test('threshold math', () {
      expect(newLogic(rounds: 8).winThreshold, 5); // ceil(4.8)
      expect(newLogic(rounds: 10).winThreshold, 6); // ceil(6.0)
      expect(newLogic(rounds: 12).winThreshold, 8); // ceil(7.2)
    });

    test('completing 6 of 10 rounds wins; 5 loses', () {
      final won = newLogic(rounds: 10, seed: 2);
      var completed = 0;
      while (!won.isDone) {
        won.startRound();
        if (completed < 6) {
          for (final cell in won.flashCells) {
            won.tap(cell);
          }
          completed++;
        } else {
          won.tap(nonFlashCell(won));
        }
      }
      expect(won.roundsPlayed, 10);
      expect(won.roundsCompleted, 6);
      expect(won.won, isTrue);

      final lost = newLogic(rounds: 10, seed: 4);
      var done = 0;
      while (!lost.isDone) {
        lost.startRound();
        if (done < 5) {
          for (final cell in lost.flashCells) {
            lost.tap(cell);
          }
          done++;
        } else {
          lost.timeoutRound();
        }
      }
      expect(lost.roundsCompleted, 5);
      expect(lost.won, isFalse);
    });

    test('wrong taps and timeouts both count as played, not completed', () {
      final logic = newLogic(rounds: 5, seed: 6);
      logic.startRound();
      logic.tap(nonFlashCell(logic)); // fail 1
      logic.startRound();
      logic.timeoutRound(); // miss 2
      logic.startRound();
      for (final cell in logic.flashCells) {
        logic.tap(cell);
      } // win 3
      expect(logic.roundsPlayed, 3);
      expect(logic.roundsCompleted, 1);
      expect(logic.isDone, isFalse);
    });
  });

  group('serialization round-trip', () {
    test('toMap -> tryFromMap restores a mid-recall round', () {
      final logic = newLogic(grid: 5, cells: 6, rounds: 12, seed: 15);
      logic.startRound();
      final flash = logic.flashCells;
      logic.tap(flash.first);
      final restored = PatternRecallLogic.tryFromMap(
        logic.toMap(),
        random: Random(999),
      );
      expect(restored, isNotNull);
      expect(restored!.grid, 5);
      expect(restored.baseCells, 6);
      expect(restored.totalRounds, 12);
      expect(restored.roundsPlayed, 1);
      expect(restored.roundsCompleted, 0);
      expect(restored.flashCells, flash);
      expect(restored.recalledCells, {flash.first});
      expect(restored.isRoundActive, isTrue);
      // Judging continues seamlessly after the restore.
      expect(restored.tap(flash.last), PatternTapResult.correct);
      expect(
        restored.tap(flash.elementAt(1)),
        PatternTapResult.correct,
      );
    });

    test('corrupt maps restore null', () {
      expect(PatternRecallLogic.tryFromMap(null, random: Random(1)), isNull);
      expect(
        PatternRecallLogic.tryFromMap(<String, dynamic>{}, random: Random(1)),
        isNull,
      );
      expect(
        PatternRecallLogic.tryFromMap(<String, dynamic>{
          'grid': 9, // out of range
          'cells': 4,
          'rounds': 8,
          'played': 0,
          'completed': 0,
          'flash': <int>[],
          'recalled': <int>[],
          'active': false,
        }, random: Random(1)),
        isNull,
      );
    });
  });
}

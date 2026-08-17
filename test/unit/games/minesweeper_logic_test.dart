/// Minesweeper logic tests — procedural, offline, first-tap-safe.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/games/mind/minesweeper/minesweeper_logic.dart';

void main() {
  test('first tap (and its neighborhood) is always safe', () {
    for (final seed in [1, 2, 3, 4, 5]) {
      final logic = MinesweeperLogic(size: 10, mineCount: 15, random: Random(seed));
      logic.reveal(4, 4);
      expect(logic.hitMine, isFalse, reason: 'seed $seed first tap hit a mine');
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          expect(logic.isMine(4 + dx, 4 + dy), isFalse,
              reason: 'seed $seed neighbor was mined');
        }
      }
      // Exactly mineCount mines placed after the first reveal.
      expect(logic.minePositions().length, 15);
    }
  });

  test('adjacency counts are correct', () {
    final logic = MinesweeperLogic(size: 8, mineCount: 10, random: Random(7));
    logic.reveal(0, 0);
    final mines = logic.minePositions();
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        var expected = 0;
        for (final (mx, my) in mines) {
          if ((mx - x).abs() <= 1 && (my - y).abs() <= 1) expected++;
        }
        expect(logic.adjacentMines(x, y), expected,
            reason: 'adjacency mismatch at ($x,$y)');
      }
    }
  });

  test('revealing a zero cell flood-fills its region', () {
    final logic = MinesweeperLogic(size: 9, mineCount: 10, random: Random(3));
    final revealed = logic.reveal(4, 4);
    expect(revealed, greaterThan(1), reason: 'a zero-adjacent tap opens a region');
    expect(logic.revealedCount, revealed);
  });

  test('flags toggle and block re-reveal', () {
    final logic = MinesweeperLogic(size: 8, mineCount: 10, random: Random(12));
    expect(logic.toggleFlag(2, 2), isTrue);
    expect(logic.stateOf(2, 2), MsCellState.flagged);
    expect(logic.flaggedCount, 1);
    expect(logic.reveal(2, 2), 0, reason: 'flagged cells are not revealed');
    expect(logic.toggleFlag(2, 2), isTrue);
    expect(logic.stateOf(2, 2), MsCellState.hidden);
    expect(logic.flaggedCount, 0);
  });

  test('win by revealing every non-mine cell', () {
    final logic = MinesweeperLogic(size: 6, mineCount: 5, random: Random(21));
    logic.reveal(0, 0);
    final mines = logic.minePositions().toSet();
    var guard = 500;
    while (!logic.won && !logic.lost && guard-- > 0) {
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          if (!mines.contains((x, y)) && logic.stateOf(x, y) == MsCellState.hidden) {
            logic.reveal(x, y);
          }
        }
      }
    }
    expect(logic.lost, isFalse, reason: 'never touched a mine');
    expect(logic.won, isTrue);
    expect(logic.revealedCount, 36 - 5);
  });

  test('hitting a mine loses immediately', () {
    final logic = MinesweeperLogic(size: 8, mineCount: 10, random: Random(4));
    logic.reveal(4, 4);
    final mine = logic.minePositions().first;
    logic.reveal(mine.$1, mine.$2);
    expect(logic.hitMine, isTrue);
    expect(logic.lost, isTrue);
    expect(logic.won, isFalse);
    // Further reveals are no-ops after a loss.
    expect(logic.reveal(0, 0), 0);
  });
}

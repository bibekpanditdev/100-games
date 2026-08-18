import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/puzzle/block_fall/block_fall_logic.dart';

/// Fills the given rows completely except the given gap columns.
void stackRows(BlockFallLogic logic, int firstRow, int lastRow, List<int> gaps) {
  for (var r = firstRow; r <= lastRow; r++) {
    for (var c = 0; c < logic.cols; c++) {
      if (!gaps.contains(c)) logic.grid[r][c] = 5;
    }
  }
}

void main() {
  group('gravity and collision', () {
    test('gravity advances the active piece one row per step', () {
      final logic = BlockFallLogic(cols: 9, random: Random(1));
      final type = logic.activeType!;
      final row = logic.activeRow;
      expect(logic.stepDown(), isTrue);
      expect(logic.activeRow, row + 1);
      expect(logic.viewGrid()[row + 1].contains(type), isTrue);
    });

    test('pieces stop at the floor, lock and spawn the next piece', () {
      final logic = BlockFallLogic(cols: 8, random: Random(2));
      var locks = 0;
      while (locks < 1) {
        if (!logic.stepDown()) locks += 1;
      }
      expect(logic.grid.last.any((v) => v != -1), isTrue);
      expect(logic.hasActive, isTrue); // fresh piece already spawned
    });

    test('pieces cannot move into the side walls', () {
      final logic = BlockFallLogic(cols: 8, random: Random(3));
      logic.spawn(1); // O piece, spawns over columns 3..4
      expect(logic.pieceCol, 3);
      while (logic.move(0, -1)) {}
      expect(logic.move(0, -1), isFalse);
      expect(logic.pieceCol, 0);
      while (logic.move(0, 1)) {}
      expect(logic.move(0, 1), isFalse);
      expect(logic.pieceCol, logic.cols - 2);
    });

    test('pieces cannot move down into a stack', () {
      final logic = BlockFallLogic(cols: 8, random: Random(4));
      // A one-high stack everywhere except column 0.
      stackRows(logic, logic.rows - 1, logic.rows - 1, [0]);
      logic.spawn(1); // O over columns 3..4 — blocked one row above stack
      while (logic.move(1, 0)) {}
      expect(logic.activeRow, logic.rows - 3); // rests exactly on the stack
      expect(logic.move(1, 0), isFalse);
    });
  });

  group('rotation', () {
    test('rotates freely mid-board', () {
      final logic = BlockFallLogic(cols: 8, random: Random(5));
      logic.spawn(2); // T piece
      expect(logic.rotation, 0);
      expect(logic.rotate(), isTrue);
      expect(logic.rotation, 1);
      expect(logic.rotate(), isTrue);
      expect(logic.rotation, 2);
    });

    test('rotation is blocked when the stack leaves no room', () {
      final logic = BlockFallLogic(cols: 8, random: Random(6));
      logic.spawn(0); // I piece over columns 2..5 at row 1
      // Stack blocking every rotated target, including +/-1 wall kicks:
      // the vertical I occupies column 4 (origin col 2 + offset 2).
      stackRows(logic, 0, 3, const [0, 1, 2, 6, 7]);
      expect(logic.rotate(), isFalse);
      expect(logic.rotation, 0);
    });
  });

  group('line clears and scoring', () {
    test('single line scores 100', () {
      final logic = BlockFallLogic(cols: 8, random: Random(7));
      stackRows(logic, 17, 17, [4]);
      logic.spawn(0);
      logic.rotate(); // vertical I over column 4
      logic.hardDrop();
      expect(logic.lines, 1);
      expect(logic.score, 100);
      expect(logic.grid[17].every((v) => v == -1), isTrue);
    });

    test('double line scores 300', () {
      final logic = BlockFallLogic(cols: 8, random: Random(8));
      stackRows(logic, 16, 17, [3, 4]);
      logic.spawn(1); // O fills columns 3..4
      logic.hardDrop();
      expect(logic.lines, 2);
      expect(logic.score, 300);
    });

    test('tetris (4 lines) scores the 800 bonus', () {
      final logic = BlockFallLogic(cols: 8, random: Random(9));
      stackRows(logic, 14, 17, [4]);
      logic.spawn(0);
      logic.rotate();
      logic.hardDrop();
      expect(logic.lines, 4);
      expect(logic.score, 800);
      for (var r = 14; r <= 17; r++) {
        expect(logic.grid[r].every((v) => v == -1), isTrue, reason: 'row $r');
      }
    });

    test('clears are multiplied by the level', () {
      final logic = BlockFallLogic(cols: 8, random: Random(10));
      logic.lines = 9; // one line short of level 2
      stackRows(logic, 17, 17, [4]);
      logic.spawn(0);
      logic.rotate();
      logic.hardDrop();
      expect(logic.lines, 10);
      expect(logic.level, 2);
      expect(logic.score, 200); // 100 x level 2
    });
  });

  group('top-out and continue', () {
    test('spawn on a full board tops out', () {
      final logic = BlockFallLogic(cols: 8, random: Random(11));
      for (final row in logic.grid) {
        for (var c = 0; c < logic.cols; c++) {
          row[c] = 5;
        }
      }
      expect(logic.spawnNext(), isFalse);
      expect(logic.gameOver, isTrue);
      expect(logic.hasActive, isFalse);
    });

    test('top-out also triggers after a lock buries the spawn area', () {
      final logic = BlockFallLogic(cols: 8, random: Random(12));
      // Solid stack from row 3 down; row 2 has a gap at column 0 so the
      // last piece completes no line; rows 0..1 are free for one spawn.
      for (var r = 3; r < logic.rows; r++) {
        for (var c = 0; c < logic.cols; c++) {
          logic.grid[r][c] = 5;
        }
      }
      for (var c = 1; c < logic.cols; c++) {
        logic.grid[2][c] = 5;
      }
      logic.spawn(1); // O rests on the stack at rows 1..2, no clear
      logic.hardDrop();
      expect(logic.lines, 0);
      // Whatever comes next cannot spawn: every tetromino needs row 1
      // cells that the locked O (columns 3..4) now occupies.
      expect(logic.hasActive, isFalse);
      expect(logic.gameOver, isTrue);
    });

    test('clearTopRows revives the board for an extra life', () {
      final logic = BlockFallLogic(cols: 8, random: Random(13));
      for (final row in logic.grid) {
        for (var c = 0; c < logic.cols; c++) {
          row[c] = 5;
        }
      }
      logic.spawnNext();
      expect(logic.gameOver, isTrue);
      logic.clearTopRows(6);
      expect(logic.gameOver, isFalse);
      for (var r = 0; r < 6; r++) {
        expect(logic.grid[r].every((v) => v == -1), isTrue, reason: 'row $r');
      }
      expect(logic.spawnNext(), isTrue);
      expect(logic.hasActive, isTrue);
    });
  });

  group('determinism', () {
    test('same seed plays the same piece queue', () {
      BlockFallLogic build() => BlockFallLogic(cols: 8, random: Random(42));
      final a = build();
      final b = build();
      expect(a.activeType, b.activeType);
      expect(a.nextType, b.nextType);
      for (var i = 0; i < 10; i++) {
        a.spawnNext();
        b.spawnNext();
        expect(a.nextType, b.nextType);
      }
    });
  });
}

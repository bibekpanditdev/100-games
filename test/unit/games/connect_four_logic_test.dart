import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/board/connect_four/connect_four_logic.dart';

const _cols = 7;
const _rows = 6;

/// Empty 7x6 grid.
List<int> emptyGrid() => List<int>.filled(_cols * _rows, 0);

void set(List<int> grid, int r, int c, int v) => grid[r * _cols + c] = v;

ConnectFourLogic fromGrid(List<int> grid, {int aiLevel = 3, int seed = 1}) =>
    ConnectFourLogic.fromGrid(grid: grid, aiLevel: aiLevel, random: Random(seed));

void main() {
  group('win detection', () {
    test('horizontal four, including the left board edge', () {
      final grid = emptyGrid();
      for (var c = 0; c < 4; c++) {
        set(grid, 5, c, ConnectFourLogic.player);
      }
      expect(ConnectFourLogic.boardWinner(grid), ConnectFourLogic.player);
    });

    test('vertical four, including the bottom board edge', () {
      final grid = emptyGrid();
      for (var r = 2; r < 6; r++) {
        set(grid, r, 6, ConnectFourLogic.cpu);
      }
      expect(ConnectFourLogic.boardWinner(grid), ConnectFourLogic.cpu);
    });

    test('diagonal down-right four', () {
      final grid = emptyGrid();
      for (var i = 0; i < 4; i++) {
        set(grid, 2 + i, i, ConnectFourLogic.player);
      }
      expect(ConnectFourLogic.boardWinner(grid), ConnectFourLogic.player);
    });

    test('diagonal down-left four at the right board edge', () {
      final grid = emptyGrid();
      for (var i = 0; i < 4; i++) {
        set(grid, 2 + i, 6 - i, ConnectFourLogic.player);
      }
      expect(ConnectFourLogic.boardWinner(grid), ConnectFourLogic.player);
    });

    test('three in a row is not a win', () {
      final grid = emptyGrid();
      for (var c = 0; c < 3; c++) {
        set(grid, 5, c, ConnectFourLogic.player);
      }
      expect(ConnectFourLogic.boardWinner(grid), isNull);
    });

    test('dropping the winning disc sets the winner', () {
      final grid = emptyGrid();
      for (var c = 0; c < 3; c++) {
        set(grid, 5, c, ConnectFourLogic.player);
      }
      set(grid, 5, 4, ConnectFourLogic.cpu); // anchor col 4
      final logic = fromGrid(grid);
      final idx = logic.drop(3, ConnectFourLogic.player);
      expect(idx, 5 * _cols + 3);
      expect(logic.winner, ConnectFourLogic.player);
      expect(logic.isGameOver, isTrue);
      // No drops after the game is over.
      expect(logic.drop(0, ConnectFourLogic.cpu), -1);
    });
  });

  group('gravity and full columns', () {
    test('discs stack from the bottom up', () {
      final logic = ConnectFourLogic(aiLevel: 1, random: Random(1));
      expect(logic.drop(2, ConnectFourLogic.player), 5 * _cols + 2);
      expect(logic.drop(2, ConnectFourLogic.cpu), 4 * _cols + 2);
      expect(logic.drop(2, ConnectFourLogic.player), 3 * _cols + 2);
      expect(logic.board[5 * _cols + 2], ConnectFourLogic.player);
      expect(logic.board[4 * _cols + 2], ConnectFourLogic.cpu);
    });

    test('full columns reject drops', () {
      final grid = emptyGrid();
      for (var r = 0; r < _rows; r++) {
        set(grid, r, 3, r.isEven
            ? ConnectFourLogic.player
            : ConnectFourLogic.cpu);
      }
      final logic = fromGrid(grid);
      expect(logic.landingRow(3), -1);
      expect(logic.canDrop(3), isFalse);
      expect(logic.drop(3, ConnectFourLogic.player), -1);
      expect(logic.play(3), isFalse);
      expect(logic.canDrop(-1), isFalse);
      expect(logic.canDrop(7), isFalse);
    });

    test('a completely filled board with no four is a draw', () {
      final grid = emptyGrid();
      for (var r = 0; r < _rows; r++) {
        for (var c = 0; c < _cols; c++) {
          final who = ((c ~/ 2) + r) % 2 + 1;
          set(grid, r, c, who);
        }
      }
      expect(ConnectFourLogic.boardWinner(grid), isNull);
      final logic = fromGrid(grid);
      expect(logic.isDraw, isTrue);
      expect(logic.isGameOver, isTrue);
      expect(logic.drop(0, ConnectFourLogic.player), -1);
    });
  });

  group('CPU', () {
    test('takes an immediate vertical win over blocking (levels 2 and 3)',
        () {
      for (final level in [2, 3]) {
        final grid = emptyGrid();
        // Player threatens 0-1-2-3 along the bottom row.
        for (var c = 0; c < 3; c++) {
          set(grid, 5, c, ConnectFourLogic.player);
        }
        // CPU already has three stacked in column 6 (row 5 open).
        for (var r = 2; r < 5; r++) {
          set(grid, r, 6, ConnectFourLogic.cpu);
        }
        final logic = fromGrid(grid, aiLevel: level);
        final col = logic.cpuMove();
        expect(col, 6, reason: 'level $level must take the win');
        expect(logic.winner, ConnectFourLogic.cpu);
      }
    });

    test('blocks the player\u2019s immediate win (levels 2 and 3)', () {
      for (final level in [2, 3]) {
        final grid = emptyGrid();
        for (var c = 0; c < 3; c++) {
          set(grid, 5, c, ConnectFourLogic.player);
        }
        set(grid, 5, 6, ConnectFourLogic.cpu); // one distant anchor
        final logic = fromGrid(grid, aiLevel: level);
        final col = logic.cpuMove();
        expect(col, 3, reason: 'level $level must block the bottom row');
        expect(logic.winner, isNull);
        expect(logic.board[5 * _cols + 3], ConnectFourLogic.cpu);
      }
    });

    test('level 3 prefers the centre column on an empty board', () {
      final logic = ConnectFourLogic(aiLevel: 3, random: Random(1));
      expect(logic.cpuMove(), 3);
    });

    test('hint column finishes the player\u2019s own four', () {
      final grid = emptyGrid();
      for (var c = 2; c < 5; c++) {
        set(grid, 5, c, ConnectFourLogic.player);
      }
      set(grid, 5, 6, ConnectFourLogic.cpu);
      final logic = fromGrid(grid);
      final hint = logic.bestColumnFor(ConnectFourLogic.player);
      expect(hint, anyOf(1, 5), reason: 'either open end completes the four');
    });
  });
}

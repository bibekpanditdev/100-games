import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/puzzle/match3/match3_logic.dart';

/// Board with a horizontal match in row 0 and nothing else.
const List<List<int>> kHorizontalGrid = [
  [0, 0, 0, 1],
  [1, 2, 1, 2],
  [2, 1, 2, 1],
];

/// Board with a vertical match in column 0 and nothing else.
const List<List<int>> kVerticalGrid = [
  [0, 1, 2],
  [0, 2, 1],
  [0, 1, 2],
];

/// Board with a T shape (horizontal run + vertical run sharing a cell).
const List<List<int>> kTShapeGrid = [
  [0, 0, 0, 3],
  [1, 0, 1, 4],
  [2, 0, 2, 5],
];

/// Board with an L shape (row 0 run + column 0 run).
const List<List<int>> kLShapeGrid = [
  [1, 1, 1, 2],
  [0, 3, 4, 7],
  [0, 5, 6, 8],
];

/// Diagonal stripes of 4 kinds: no matches and no legal swap exists.
List<List<int>> stripeGrid(int rows, int cols) => [
      for (var r = 0; r < rows; r++)
        [for (var c = 0; c < cols; c++) (r + c) % 4],
    ];

Match3Board boardOf(List<List<int>> grid, [int seed = 1]) =>
    Match3Board.fromGrid(grid: grid, random: Random(seed));

void main() {
  group('match detection', () {
    test('detects a horizontal run of three', () {
      final board = boardOf(kHorizontalGrid);
      expect(board.detectMatchedCells(), {0, 1, 2});
    });

    test('detects a vertical run of three', () {
      final board = boardOf(kVerticalGrid);
      expect(board.detectMatchedCells(), {0, 3, 6});
    });

    test('detects a T shape as the union of both runs', () {
      final board = boardOf(kTShapeGrid);
      // Row 0 run (0,1,2) union column 1 run (1, 5, 9).
      expect(board.detectMatchedCells(), {0, 1, 2, 5, 9});
    });

    test('detects an L shape as the union of both runs', () {
      final board = boardOf(kLShapeGrid);
      expect(board.detectMatchedCells(), {0, 1, 2, 4, 8});
    });

    test('reports no matches on a clean board', () {
      final board = boardOf(stripeGrid(4, 4));
      expect(board.detectMatchedCells(), isEmpty);
    });
  });

  group('swap validation', () {
    test('rejects non-adjacent swaps', () {
      final board = boardOf(kHorizontalGrid);
      expect(board.isAdjacent(0, 2), isFalse);
      expect(board.isAdjacent(0, 5), isFalse);
      expect(board.isValidSwap(0, 2), isFalse);
      expect(board.isValidSwap(0, 5), isFalse);
    });

    test('rejects adjacent swaps that create no match', () {
      final board = boardOf(stripeGrid(4, 4));
      expect(board.isValidSwap(0, 1), isFalse);
      expect(board.isValidSwap(5, 6), isFalse);
    });

    test('accepts an adjacent swap that creates a match', () {
      // Swapping (0,1) and (1,1) completes row 0: 0,0,0.
      final board = boardOf(const [
        [0, 1, 0],
        [1, 0, 1],
        [0, 1, 0],
      ]);
      expect(board.isValidSwap(1, 4), isTrue);
    });
  });

  group('valid moves and hints', () {
    test('finds a valid move and reports it as a legal swap', () {
      final board = boardOf(const [
        [0, 1, 0],
        [1, 0, 1],
        [0, 1, 0],
      ]);
      final move = board.findValidMove();
      expect(move, isNotNull);
      expect(board.isValidSwap(move!.a, move.b), isTrue);
    });

    test('stripe boards have no moves; shuffle fixes them', () {
      final board = boardOf(stripeGrid(4, 4), 3);
      expect(board.hasValidMove(), isFalse);
      expect(board.findValidMove(), isNull);
      board.shuffle();
      expect(board.hasValidMove(), isTrue);
      expect(board.detectMatchedCells(), isEmpty);
    });
  });

  group('cascade resolution', () {
    test('clears matches, refills and reports wave counts', () {
      final board = boardOf(kHorizontalGrid, 7);
      final firstWave = board.detectMatchedCells().length;
      expect(firstWave, 3);
      final result = board.resolveMatches();
      expect(result.cascades, greaterThanOrEqualTo(1));
      expect(result.cleared, greaterThanOrEqualTo(firstWave));
      expect(result.scoreGained, greaterThanOrEqualTo(60 * firstWave));
      // Each extra wave clears at least 3 more tiles.
      if (result.cleared > firstWave) {
        expect(result.cascades, greaterThanOrEqualTo(2));
        expect(result.scoreGained,
            greaterThanOrEqualTo(60 * firstWave + 120 * (result.cleared - firstWave)));
      }
      // Board settles with every cell a regular piece.
      expect(board.detectMatchedCells(), isEmpty);
      for (var i = 0; i < board.cellCount; i++) {
        expect(board.pieceAtFlat(i), inInclusiveRange(0, 5));
      }
    });

    test('is deterministic for a fixed seed', () {
      List<int> resolveOnce() {
        final board = boardOf(kHorizontalGrid, 11);
        board.resolveMatches();
        return [for (var i = 0; i < board.cellCount; i++) board.pieceAtFlat(i)];
      }

      expect(resolveOnce(), resolveOnce());
    });
  });

  group('board generation', () {
    test('fresh boards have no initial matches and a valid move', () {
      for (var seed = 0; seed < 30; seed++) {
        final board = Match3Board(rows: 7, cols: 7, random: Random(seed));
        expect(board.detectMatchedCells(), isEmpty, reason: 'seed $seed');
        expect(board.hasValidMove(), isTrue, reason: 'seed $seed');
      }
    });

    test('supports non-square grids', () {
      for (var seed = 0; seed < 10; seed++) {
        final board = Match3Board(rows: 9, cols: 7, random: Random(100 + seed));
        expect(board.detectMatchedCells(), isEmpty);
        expect(board.hasValidMove(), isTrue);
      }
    });
  });
}

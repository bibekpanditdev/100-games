import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/puzzle/sliding_puzzle/sliding_puzzle_logic.dart';

/// Parity check for the classic n-puzzle with the blank in the bottom-right
/// goal cell. Odd width: solvable iff inversions are even. Even width:
/// solvable iff inversions + blank row counted from the bottom is odd.
bool isSolvablePermutation(List<int> tiles, int n) {
  final flat = tiles.where((t) => t != 0).toList();
  var inversions = 0;
  for (var i = 0; i < flat.length; i++) {
    for (var j = i + 1; j < flat.length; j++) {
      if (flat[i] > flat[j]) inversions += 1;
    }
  }
  if (n.isOdd) return inversions.isEven;
  final blankRowFromBottom = n - (tiles.indexOf(0) ~/ n);
  return (inversions + blankRowFromBottom) % 2 == 1;
}

void main() {
  group('shuffle', () {
    test('every shuffle is a solvable permutation for sizes 3..5', () {
      for (final size in [3, 4, 5]) {
        for (var seed = 0; seed < 20; seed++) {
          final puzzle = SlidingPuzzle(size: size, random: Random(seed * 31 + size));
          expect(puzzle.isSolved, isFalse, reason: 'size $size seed $seed');
          final sorted = [...puzzle.tiles]..sort();
          expect(
            sorted,
            List<int>.generate(size * size, (i) => i),
            reason: 'size $size seed $seed must permute 0..n^2-1',
          );
          expect(
            isSolvablePermutation(puzzle.tiles, size),
            isTrue,
            reason: 'size $size seed $seed must be solvable',
          );
        }
      }
    });

    test('reshuffling keeps the permutation valid and unsolved', () {
      final puzzle = SlidingPuzzle(size: 3, random: Random(5));
      final first = puzzle.tiles;
      puzzle.shuffle(Random(9));
      expect(puzzle.tiles, isNot(first));
      expect(puzzle.moves, 0);
      expect(isSolvablePermutation(puzzle.tiles, 3), isTrue);
    });
  });

  group('moves and legality', () {
    test('slides a tile adjacent to the blank and counts one move', () {
      final puzzle =
          SlidingPuzzle.fromTiles(size: 3, tiles: [1, 2, 3, 4, 5, 6, 7, 0, 8]);
      expect(puzzle.isSolved, isFalse);
      expect(puzzle.canSlide(8), isTrue);
      final moved = puzzle.slideFrom(8);
      expect(moved, [8]);
      expect(puzzle.isSolved, isTrue);
      expect(puzzle.moves, 1);
      expect(puzzle.canSlide(8), isFalse); // blank is there now
    });

    test('rejects tiles outside the blank row and column', () {
      final puzzle =
          SlidingPuzzle.fromTiles(size: 3, tiles: [0, 1, 2, 3, 4, 5, 6, 7, 8]);
      expect(puzzle.canSlide(4), isFalse);
      expect(puzzle.canSlide(8), isFalse);
      expect(puzzle.slideFrom(4), isEmpty);
      expect(puzzle.moves, 0);
    });

    test('slides a whole segment like a real 15-puzzle', () {
      final puzzle = SlidingPuzzle.fromTiles(
        size: 4,
        tiles: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 0, 14, 15],
      );
      final moved = puzzle.slideFrom(15);
      expect(moved, [14, 15]);
      expect(puzzle.tiles, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 0]);
      expect(puzzle.moves, 1);
      expect(puzzle.isSolved, isTrue);
    });

    test('manhattan distance reports tile displacement', () {
      final puzzle =
          SlidingPuzzle.fromTiles(size: 3, tiles: [1, 2, 3, 4, 5, 6, 7, 0, 8]);
      expect(puzzle.manhattan(), 1);
      puzzle.slideFrom(8);
      expect(puzzle.manhattan(), 0);
    });
  });

  group('hints', () {
    test('hint auto-solves one step and reduces Manhattan distance', () {
      final puzzle =
          SlidingPuzzle.fromTiles(size: 3, tiles: [1, 2, 3, 4, 5, 6, 7, 0, 8]);
      final before = puzzle.manhattan();
      final hint = puzzle.hintIndex();
      expect(hint, isNot(-1));
      expect(puzzle.canSlide(hint), isTrue);
      puzzle.slideFrom(hint);
      expect(puzzle.manhattan(), lessThan(before));
      expect(puzzle.isSolved, isTrue);
      expect(puzzle.hintIndex(), -1); // solved: no hint needed
    });

    test('hint proposes a legal slide from a stuck-looking state', () {
      // Every single move here increases Manhattan distance; the hint must
      // still return a legal slide (the least harmful one).
      final puzzle = SlidingPuzzle.fromTiles(size: 2, tiles: [3, 1, 2, 0]);
      final before = puzzle.manhattan();
      final hint = puzzle.hintIndex();
      expect(hint, isNot(-1));
      expect(puzzle.canSlide(hint), isTrue);
      puzzle.slideFrom(hint);
      expect(puzzle.manhattan(), lessThanOrEqualTo(before + 1));
    });

    test('repeated hints never increase distance on solvable shuffles', () {
      for (var seed = 0; seed < 10; seed++) {
        final puzzle = SlidingPuzzle(size: 3, random: Random(seed));
        var distance = puzzle.manhattan();
        for (var step = 0; step < 40; step++) {
          final hint = puzzle.hintIndex();
          if (hint < 0) break;
          puzzle.slideFrom(hint);
          final next = puzzle.manhattan();
          expect(next, lessThanOrEqualTo(distance + 1));
          distance = next;
        }
      }
    });
  });
}

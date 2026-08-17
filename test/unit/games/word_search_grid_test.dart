import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/puzzle/word_search/word_search_logic.dart';

const List<String> kWords = [
  'CAT', 'DOG', 'ELEPHANT', 'FALCON', 'OWL', 'PENGUIN',
];

const List<List<int>> kDirections = [
  [0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [1, -1], [-1, 1], [-1, -1],
];

/// Brute-force search: does the grid spell [word] along any of the 8
/// directions from any start cell?
bool gridContainsWord(WordSearchGrid grid, String word) {
  for (var r = 0; r < grid.size; r++) {
    for (var c = 0; c < grid.size; c++) {
      for (final dir in kDirections) {
        var ok = true;
        for (var i = 0; i < word.length && ok; i++) {
          final rr = r + dir[0] * i;
          final cc = c + dir[1] * i;
          if (rr < 0 || rr >= grid.size || cc < 0 || cc >= grid.size) {
            ok = false;
          } else if (grid.letterAt(rr, cc) != word[i]) {
            ok = false;
          }
        }
        if (ok) return true;
      }
    }
  }
  return false;
}

void main() {
  group('placement', () {
    test('every requested word is placed, in bounds and findable', () {
      for (var seed = 0; seed < 15; seed++) {
        final grid = WordSearchGrid(size: 9, words: kWords, random: Random(seed));
        expect(grid.placedWords.length, kWords.length, reason: 'seed $seed');
        for (final placement in grid.placements) {
          final endRow =
              placement.row + placement.dr * (placement.word.length - 1);
          final endCol =
              placement.col + placement.dc * (placement.word.length - 1);
          expect(
            endRow >= 0 && endRow < grid.size && endCol >= 0 && endCol < grid.size,
            isTrue,
            reason: '${placement.word} out of bounds, seed $seed',
          );
          expect(
            gridContainsWord(grid, placement.word),
            isTrue,
            reason: '${placement.word} not findable, seed $seed',
          );
        }
      }
    });

    test('overlaps never conflict: every placed letter matches its word',
        () {
      final grid = WordSearchGrid(size: 11, words: kWords, random: Random(21));
      for (final placement in grid.placements) {
        for (var i = 0; i < placement.word.length; i++) {
          expect(
            grid.letterAt(
              placement.row + placement.dr * i,
              placement.col + placement.dc * i,
            ),
            placement.word[i],
            reason: '${placement.word} letter $i mismatched by an overlap',
          );
        }
      }
    });

    test('words longer than the grid are skipped', () {
      final grid = WordSearchGrid(size: 5, words: kWords, random: Random(1));
      expect(grid.placedWords, isNot(contains('ELEPHANT'))); // 8 letters
      expect(grid.placedWords, isNot(contains('PENGUIN'))); // 7 letters
      expect(grid.placedWords, containsAll(['CAT', 'DOG', 'OWL']));
    });
  });

  group('fill and determinism', () {
    test('every cell ends up an uppercase letter', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(2));
      expect(grid.rows.length, 9);
      for (final row in grid.rows) {
        expect(RegExp(r'^[A-Z]{9}$').hasMatch(row), isTrue, reason: row);
      }
    });

    test('same seed produces the identical grid', () {
      WordSearchGrid build() =>
          WordSearchGrid(size: 9, words: kWords, random: Random(42));
      final a = build();
      final b = build();
      expect(a.rows, b.rows);
      expect(a.placedWords, b.placedWords);
      expect(a.placements.first.row, b.placements.first.row);
    });

    test('different seeds (almost surely) produce different fills', () {
      final a = WordSearchGrid(size: 12, words: kWords, random: Random(1));
      final b = WordSearchGrid(size: 12, words: kWords, random: Random(2));
      expect(a.rows, isNot(b.rows));
    });
  });

  group('selection', () {
    test('selecting a placement line marks the word found', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(3));
      final placement = grid.placements.first;
      final endRow =
          placement.row + placement.dr * (placement.word.length - 1);
      final endCol =
          placement.col + placement.dc * (placement.word.length - 1);
      expect(
        grid.selectLine(placement.row, placement.col, endRow, endCol),
        isTrue,
      );
      expect(grid.found, contains(placement.word));

      // Re-selecting the same word is a no-op (already found).
      expect(grid.selectLine(endRow, endCol, placement.row, placement.col),
          isFalse);

      // Selecting any other placement still works.
      final other = grid.placements
          .firstWhere((p) => !grid.found.contains(p.word));
      expect(
        grid.selectLine(
          other.row,
          other.col,
          other.row + other.dr * (other.word.length - 1),
          other.col + other.dc * (other.word.length - 1),
        ),
        isTrue,
      );
      expect(grid.allFound, isFalse); // 2 of 6 found
    });

    test('crooked or unknown lines are rejected', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(4));
      expect(grid.selectLine(0, 0, 2, 1), isFalse); // not straight
      expect(grid.selectLine(3, 3, 3, 3), isFalse); // single cell
      expect(grid.found, isEmpty);
    });

    test('firstUnfound points at a real unfound word for hints', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(5));
      final hint = grid.firstUnfound();
      expect(hint, isNotNull);
      expect(grid.found.contains(hint!.word), isFalse);
      expect(grid.letterAt(hint.row, hint.col), hint.word[0]);
    });
  });

  group('line snapping', () {
    test('snapLine keeps straight lines straight', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(6));
      expect(grid.snapLine(0, 0, 0, 5), [0, 1, 2, 3, 4, 5]);
      expect(grid.snapLine(2, 3, 5, 3), [2 * 9 + 3, 3 * 9 + 3, 4 * 9 + 3, 5 * 9 + 3]);
      expect(grid.snapLine(0, 0, 3, 3), [0, 10, 20, 30]);
    });

    test('snapLine clamps to the board and snaps near misses', () {
      final grid = WordSearchGrid(size: 9, words: kWords, random: Random(7));
      // Mostly horizontal drag one row off: snaps to a straight row line.
      expect(grid.snapLine(4, 2, 5, 7), [4 * 9 + 2, 4 * 9 + 3, 4 * 9 + 4, 4 * 9 + 5, 4 * 9 + 6, 4 * 9 + 7]);
      // Drag past the edge stays in bounds.
      final line = grid.snapLine(8, 8, 20, 20);
      expect(line.last, 8 * 9 + 8);
    });
  });
}

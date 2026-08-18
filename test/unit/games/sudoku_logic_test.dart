/// Sudoku generator + rules tests (procedural, offline).
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:game/features/games/mind/sudoku/sudoku_logic.dart';

void main() {
  test('random solved grid is a valid Sudoku', () {
    final grid = SudokuGenerator.randomSolvedGrid(Random(7));
    expect(SudokuLogic.isValidSolution(grid), isTrue);
  });

  test('generated puzzles are uniquely solvable', () {
    for (final (seed, clues) in [(1, 50), (2, 40), (3, 30)]) {
      final puzzle = SudokuGenerator.generate(clues: clues, random: Random(seed));
      expect(SudokuLogic.countSolutions(puzzle.cells), 1,
          reason: 'puzzle with $clues clues (seed $seed) must be unique');
      // The stored solution actually solves the puzzle.
      expect(SudokuLogic.isValidSolution(puzzle.solution), isTrue);
      for (var i = 0; i < 81; i++) {
        if (puzzle.given[i]) {
          expect(puzzle.cells[i], puzzle.solution[i]);
        }
      }
    }
  });

  test('solver solves any valid puzzle', () {
    final puzzle = SudokuGenerator.generate(clues: 40, random: Random(11));
    final grid = List<int>.of(puzzle.cells);
    expect(SudokuLogic.solve(grid), isTrue);
    expect(SudokuLogic.isValidSolution(grid), isTrue);
  });

  test('fits() rejects row/column/box conflicts', () {
    // Row 0 = 1..9 solved row; digit 5 must not fit anywhere in row 0.
    final grid = List<int>.filled(81, 0);
    for (var c = 0; c < 9; c++) {
      grid[c] = c + 1;
    }
    expect(SudokuLogic.fits(grid, 5, 5), isFalse, reason: 'same row');
    expect(SudokuLogic.fits(grid, 9 + 5, 5), isFalse, reason: 'same column');
    expect(SudokuLogic.fits(grid, 10, 5), isFalse, reason: 'same box');
    expect(SudokuLogic.fits(grid, 30, 5), isTrue, reason: 'elsewhere is fine');
  });

  test('place/erase/notes/mistake/hint behaviour', () {
    final logic = SudokuLogic(clues: 50, random: Random(5));
    final firstEmpty = List.generate(81, (i) => i).firstWhere((i) => !logic.isGiven(i));

    // Wrong entry is flagged as a mistake; correct entry is not.
    final correct = logic.solution[firstEmpty];
    final wrong = correct == 1 ? 2 : 1;
    expect(logic.place(firstEmpty, wrong), isFalse);
    expect(logic.isMistake(firstEmpty), isTrue);
    logic.erase(firstEmpty);
    expect(logic.valueAt(firstEmpty), 0);

    expect(logic.place(firstEmpty, correct), isTrue);
    expect(logic.isMistake(firstEmpty), isFalse);

    // Given cells are immutable.
    final given = List.generate(81, (i) => i).firstWhere(logic.isGiven);
    expect(logic.place(given, 1), isFalse);

    // Notes toggle on empty non-given cells only.
    logic.erase(firstEmpty);
    logic.toggleNote(firstEmpty, 7);
    expect(logic.notes[firstEmpty].contains(7), isTrue);
    logic.toggleNote(firstEmpty, 7);
    expect(logic.notes[firstEmpty].contains(7), isFalse);

    // Hint fills the first wrong/empty cell with the solution digit.
    final hinted = logic.applyHint();
    expect(hinted, isNotNull);
    expect(logic.valueAt(hinted!), logic.solution[hinted]);
  });

  test('isSolved after applying every hint', () {
    final logic = SudokuLogic(clues: 45, random: Random(9));
    while (logic.applyHint() != null) {}
    expect(logic.isSolved, isTrue);
    expect(logic.applyHint(), isNull, reason: 'nothing left to hint');
  });

  test('deterministic for the same seed', () {
    final a = SudokuLogic(clues: 40, random: Random(42));
    final b = SudokuLogic(clues: 40, random: Random(42));
    expect(a.cells, b.cells);
    expect(a.solution, b.solution);
  });
}

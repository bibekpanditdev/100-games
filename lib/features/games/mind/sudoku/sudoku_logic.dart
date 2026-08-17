/// Pure Sudoku rules: seeded on-device generation (randomized backtracking
/// fill + uniqueness-preserving carving with put-back), a capped solver,
/// hints, mistake checking and candidate notes.
///
/// No Flutter imports — deterministic given a seeded [Random] and fully
/// unit-testable standalone.
library;

import 'dart:math';

/// A puzzle, its stored solution and the given-cell mask.
class SudokuPuzzle {
  const SudokuPuzzle({
    required this.cells,
    required this.solution,
    required this.given,
  });

  /// 81 row-major values, `0` = empty.
  final List<int> cells;

  /// The complete 81-value solution the puzzle was carved from.
  final List<int> solution;

  /// `true` where the cell was a pre-filled given.
  final List<bool> given;
}

/// Generates uniquely-solvable Sudoku puzzles on-device.
abstract final class SudokuGenerator {
  /// Sensible clue-count bounds for the 50 / 40 / 30 difficulty tiers.
  static const int minClues = 24;
  static const int maxClues = 60;

  /// Max generation attempts before accepting the closest result.
  static const int _maxAttempts = 10;

  /// Generates a puzzle with exactly [clues] givens (when reachable —
  /// retries and falls back to the closest achievable count).
  static SudokuPuzzle generate({required int clues, required Random random}) {
    final target = clues < minClues
        ? minClues
        : clues > maxClues
            ? maxClues
            : clues;
    SudokuPuzzle? best;
    var bestGap = 81;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final solution = randomSolvedGrid(random);
      final puzzle = _carve(
        solution: solution,
        clues: target,
        random: random,
      );
      final gap = (_givenCountOf(puzzle.given) - target).abs();
      if (gap < bestGap) {
        bestGap = gap;
        best = puzzle;
      }
      if (gap == 0) break;
    }
    return best!;
  }

  /// Fills an empty grid with a random valid solved Sudoku.
  static List<int> randomSolvedGrid(Random random) {
    final grid = List<int>.filled(81, 0);
    _fillCell(grid, 0, random);
    return grid;
  }

  static bool _fillCell(List<int> grid, int index, Random random) {
    if (index == 81) return true;
    final digits = <int>[
      for (var d = 1; d <= 9; d++) d,
    ]..shuffle(random);
    for (final d in digits) {
      if (!SudokuLogic.fits(grid, index, d)) continue;
      grid[index] = d;
      if (_fillCell(grid, index + 1, random)) return true;
      grid[index] = 0;
    }
    return false;
  }

  /// Removes cells (symmetric pairs first, then singles) down to [clues]
  /// remaining givens. A removal that would create a second solution is
  /// put back, so every intermediate and final puzzle stays unique.
  static SudokuPuzzle _carve({
    required List<int> solution,
    required int clues,
    required Random random,
  }) {
    final cells = List<int>.of(solution);
    final given = List<bool>.filled(81, true);
    var remaining = 81;
    final order = List<int>.generate(81, (i) => i)..shuffle(random);
    for (final index in order) {
      if (remaining <= clues) break;
      if (!given[index]) continue;
      final partner = 80 - index;
      final canPair = partner != index &&
          given[partner] &&
          remaining - 2 >= clues;
      if (canPair) {
        final a = cells[index];
        final b = cells[partner];
        cells[index] = 0;
        cells[partner] = 0;
        if (SudokuLogic.countSolutions(cells, cap: 2) == 1) {
          given[index] = false;
          given[partner] = false;
          remaining -= 2;
        } else {
          cells[index] = a;
          cells[partner] = b;
        }
      } else if (remaining - 1 >= clues) {
        final a = cells[index];
        cells[index] = 0;
        if (SudokuLogic.countSolutions(cells, cap: 2) == 1) {
          given[index] = false;
          remaining -= 1;
        } else {
          cells[index] = a;
        }
      }
    }
    return SudokuPuzzle(cells: cells, solution: solution, given: given);
  }

  static int _givenCountOf(List<bool> given) =>
      given.where((g) => g).length;
}

/// Stateful Sudoku board for one session: placements, candidate notes,
/// mistake checks, hints and solved detection.
class SudokuLogic {
  /// Generates a fresh puzzle with [clues] givens.
  SudokuLogic({required int clues, required Random random})
      : this.fromPuzzle(
          puzzle: SudokuGenerator.generate(clues: clues, random: random),
        );

  SudokuLogic.fromPuzzle({required SudokuPuzzle puzzle})
    : cells = List<int>.of(puzzle.cells),
      solution = List<int>.of(puzzle.solution),
      given = List<bool>.of(puzzle.given),
      notes = List<Set<int>>.generate(81, (_) => <int>{});

  /// Current board values (0 = empty); mutated by [place]/[erase].
  final List<int> cells;

  /// The stored full solution (used for hints + mistake checking).
  final List<int> solution;

  final List<bool> given;

  /// Candidate note digits per cell (only meaningful on empty cells).
  final List<Set<int>> notes;

  int valueAt(int index) => cells[index];

  bool isGiven(int index) => given[index];

  bool get isSolved {
    for (var i = 0; i < 81; i++) {
      if (cells[i] != solution[i]) return false;
    }
    return true;
  }

  int get givenCount => SudokuGenerator._givenCountOf(given);

  int get emptyCount => cells.where((v) => v == 0).length;

  /// Places [digit] (1–9) into a non-given cell, overwriting any previous
  /// entry and clearing that cell's notes. Returns whether the entry
  /// matches the stored solution.
  bool place(int index, int digit) {
    if (given[index] || digit < 1 || digit > 9) return false;
    cells[index] = digit;
    notes[index].clear();
    return cells[index] == solution[index];
  }

  /// Removes a non-given entry and its notes.
  void erase(int index) {
    if (given[index]) return;
    cells[index] = 0;
    notes[index].clear();
  }

  /// True when the cell holds a value contradicting the solution.
  bool isMistake(int index) =>
      cells[index] != 0 && cells[index] != solution[index];

  /// Toggles a candidate note on an empty, non-given cell.
  void toggleNote(int index, int digit) {
    if (given[index] || cells[index] != 0) return;
    if (!notes[index].add(digit)) notes[index].remove(digit);
  }

  /// Digits still allowed at [index] given the current row/column/box.
  Set<int> candidates(int index) {
    final blocked = <int>{};
    final row = index ~/ 9;
    final col = index % 9;
    for (var k = 0; k < 9; k++) {
      blocked.add(cells[row * 9 + k]);
      blocked.add(cells[k * 9 + col]);
    }
    final r0 = row - row % 3;
    final c0 = col - col % 3;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        blocked.add(cells[(r0 + r) * 9 + c0 + c]);
      }
    }
    blocked.remove(0);
    return <int>{
      for (var d = 1; d <= 9; d++) d,
    }.difference(blocked);
  }

  /// Fills the first empty-or-wrong cell with its solution digit.
  /// Returns the cell index, or null when the board is already solved.
  int? applyHint() {
    for (var i = 0; i < 81; i++) {
      if (cells[i] != solution[i]) {
        cells[i] = solution[i];
        notes[i].clear();
        return i;
      }
    }
    return null;
  }

  // ---- Solver -----------------------------------------------------------

  /// Whether [digit] fits at [index] of an in-progress grid (the cell at
  /// [index] itself must be empty or different from [digit]).
  static bool fits(List<int> grid, int index, int digit) {
    if (grid[index] == digit) return false;
    final row = index ~/ 9;
    final col = index % 9;
    for (var k = 0; k < 9; k++) {
      if (grid[row * 9 + k] == digit) return false;
      if (grid[k * 9 + col] == digit) return false;
    }
    final r0 = row - row % 3;
    final c0 = col - col % 3;
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        if (grid[(r0 + r) * 9 + c0 + c] == digit) return false;
      }
    }
    return true;
  }

  /// Solves [grid] in place (finds the first solution). True when
  /// solvable. The list is restored to its input on failure.
  static bool solve(List<int> grid) => _solveFrom(grid);

  static bool _solveFrom(List<int> grid) {
    final index = _firstEmpty(grid);
    if (index == null) return true;
    for (var d = 1; d <= 9; d++) {
      if (!fits(grid, index, d)) continue;
      grid[index] = d;
      if (_solveFrom(grid)) return true;
      grid[index] = 0;
    }
    return false;
  }

  static int? _firstEmpty(List<int> grid) {
    for (var i = 0; i < 81; i++) {
      if (grid[i] == 0) return i;
    }
    return null;
  }

  /// Counts the solutions of [grid] up to [cap]; returns [cap] as soon as
  /// that many exist. Used for uniqueness checking during generation.
  static int countSolutions(List<int> grid, {int cap = 2}) {
    final work = List<int>.of(grid);
    return _countFrom(work, cap, 0);
  }

  static int _countFrom(List<int> grid, int cap, int found) {
    final index = _firstEmpty(grid);
    if (index == null) return found + 1;
    for (var d = 1; d <= 9; d++) {
      if (!fits(grid, index, d)) continue;
      grid[index] = d;
      found = _countFrom(grid, cap, found);
      grid[index] = 0;
      if (found >= cap) return found;
    }
    return found;
  }

  /// Whether a completed 81-value grid is a valid Sudoku solution
  /// (rows, columns and 3×3 boxes each hold 1–9 exactly once).
  static bool isValidSolution(List<int> grid) {
    if (grid.length != 81) return false;
    for (var i = 0; i < 81; i++) {
      if (grid[i] < 1 || grid[i] > 9) return false;
    }
    for (var k = 0; k < 9; k++) {
      final row = <int>{
        for (var c = 0; c < 9; c++) grid[k * 9 + c],
      };
      final col = <int>{
        for (var r = 0; r < 9; r++) grid[r * 9 + k],
      };
      final r0 = (k ~/ 3) * 3;
      final c0 = (k % 3) * 3;
      final box = <int>{
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) grid[(r0 + r) * 9 + c0 + c],
      };
      if (row.length != 9 || col.length != 9 || box.length != 9) {
        return false;
      }
    }
    return true;
  }
}

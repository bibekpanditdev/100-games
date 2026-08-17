/// Pure word-search grid rules: seeded placement in 8 directions,
/// conflict-free overlaps, random fill and line selection.
library;

import 'dart:math';

/// A successfully placed word: start cell plus unit direction.
class WordPlacement {
  const WordPlacement({
    required this.word,
    required this.row,
    required this.col,
    required this.dr,
    required this.dc,
  });

  final String word;
  final int row;
  final int col;
  final int dr;
  final int dc;

  /// Flat indices of this word's cells.
  Iterable<int> cells(int size) sync* {
    for (var i = 0; i < word.length; i++) {
      yield (row + dr * i) * size + (col + dc * i);
    }
  }
}

/// A square letter grid hiding a set of words.
class WordSearchGrid {
  /// Builds a grid of [size] x [size] cells hiding as many of [words] as
  /// fit. Words of 3..[size] letters (A-Z only) are placed horizontally,
  /// vertically or diagonally; overlaps on the same letter are allowed.
  WordSearchGrid({
    required this.size,
    required List<String> words,
    required Random random,
  }) : assert(size >= 4, 'Grid too small for word search') {
    _place(words, random);
    _fill(random);
  }

  static const List<List<int>> _directions = [
    [0, 1],
    [0, -1],
    [1, 0],
    [-1, 0],
    [1, 1],
    [1, -1],
    [-1, 1],
    [-1, -1],
  ];

  final int size;
  List<String> _cells = <String>[];

  /// Successfully placed words, longest first.
  final List<WordPlacement> placements = <WordPlacement>[];

  /// Words the player has already found.
  final Set<String> found = <String>{};

  List<String> get placedWords => [for (final p in placements) p.word];

  bool get allFound => found.length == placements.length;

  String letterAt(int r, int c) => _cells[r * size + c];

  /// The grid rows as joined strings (handy for tests and diffing).
  List<String> get rows => [
        for (var r = 0; r < size; r++)
          _cells.sublist(r * size, (r + 1) * size).join(),
      ];

  /// First placement not found yet, for hints.
  WordPlacement? firstUnfound() {
    for (final p in placements) {
      if (!found.contains(p.word)) return p;
    }
    return null;
  }

  /// Tries the straight line between two cells as a selection. Succeeds
  /// when it spells an unfound placed word (either direction).
  bool selectLine(int r1, int c1, int r2, int c2) {
    final line = lineBetween(r1, c1, r2, c2);
    if (line == null) return false;
    final word = [for (final i in line) _cells[i]].join();
    final reversed = String.fromCharCodes(word.codeUnits.reversed);
    for (final p in placements) {
      if (found.contains(p.word)) continue;
      if (p.word == word || p.word == reversed) {
        found.add(p.word);
        return true;
      }
    }
    return false;
  }

  /// Flat indices along the exact straight line between two cells, or
  /// null when they share neither row, column nor diagonal.
  List<int>? lineBetween(int r1, int c1, int r2, int c2) {
    final dir = _directionOf(r2 - r1, c2 - c1, exact: true);
    if (dir == null) return null;
    final (dr, dc, steps) = dir;
    return [
      for (var i = 0; i <= steps; i++) (r1 + dr * i) * size + (c1 + dc * i),
    ];
  }

  /// Flat indices of the straight line the player "meant" between two
  /// cells, snapping near-misses to the dominant row/column/diagonal and
  /// clamping to the grid. Never returns null.
  List<int> snapLine(int r1, int c1, int r2, int c2) {
    final dr = r2 - r1;
    final dc = c2 - c1;
    if (dr == 0 && dc == 0) return [r1 * size + c1];
    var stepR = 0;
    var stepC = 0;
    var steps = 0;
    if (dr == 0 || dc == 0) {
      final dir = _directionOf(dr, dc, exact: true)!;
      (stepR, stepC, steps) = dir;
    } else if (dr.abs() > 2 * dc.abs()) {
      stepR = dr.sign;
      steps = dr.abs();
    } else if (dc.abs() > 2 * dr.abs()) {
      stepC = dc.sign;
      steps = dc.abs();
    } else {
      stepR = dr.sign;
      stepC = dc.sign;
      steps = dr.abs() < dc.abs() ? dr.abs() : dc.abs();
    }
    final cells = <int>[r1 * size + c1];
    var r = r1;
    var c = c1;
    while (steps > 0) {
      final nr = r + stepR;
      final nc = c + stepC;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) break;
      r = nr;
      c = nc;
      cells.add(r * size + c);
      steps -= 1;
    }
    return cells;
  }

  (int, int, int)? _directionOf(int dr, int dc, {required bool exact}) {
    if (dr == 0 && dc == 0) return (0, 0, 0);
    if (dr == 0) return (0, dc.sign, dc.abs());
    if (dc == 0) return (dr.sign, 0, dr.abs());
    if (!exact || dr.abs() == dc.abs()) {
      return (dr.sign, dc.sign, dr.abs() < dc.abs() ? dr.abs() : dc.abs());
    }
    return null;
  }

  void _place(List<String> words, Random random) {
    _cells = List<String>.filled(size * size, '');
    final unique = <String>{};
    for (final w in words) {
      final up = w.toUpperCase();
      if (up.length >= 3 && up.length <= size && RegExp(r'^[A-Z]+$').hasMatch(up)) {
        unique.add(up);
      }
    }
    // Longest first improves packing.
    final ordered = unique.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final word in ordered) {
      _tryPlaceWord(word, random);
    }
  }

  bool _tryPlaceWord(String word, Random random) {
    for (var attempt = 0; attempt < 250; attempt++) {
      final dir = _directions[random.nextInt(_directions.length)];
      final r = random.nextInt(size);
      final c = random.nextInt(size);
      if (_fitsAt(word, r, c, dir[0], dir[1])) {
        _stamp(word, r, c, dir[0], dir[1]);
        return true;
      }
    }
    // Deterministic fallback: sweep every start cell and direction.
    for (final dir in _directions) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (_fitsAt(word, r, c, dir[0], dir[1])) {
            _stamp(word, r, c, dir[0], dir[1]);
            return true;
          }
        }
      }
    }
    return false;
  }

  bool _fitsAt(String word, int r, int c, int dr, int dc) {
    final endR = r + dr * (word.length - 1);
    final endC = c + dc * (word.length - 1);
    if (endR < 0 || endR >= size || endC < 0 || endC >= size) return false;
    for (var i = 0; i < word.length; i++) {
      final cell = _cells[(r + dr * i) * size + (c + dc * i)];
      if (cell.isNotEmpty && cell != word[i]) return false;
    }
    return true;
  }

  void _stamp(String word, int r, int c, int dr, int dc) {
    for (var i = 0; i < word.length; i++) {
      _cells[(r + dr * i) * size + (c + dc * i)] = word[i];
    }
    placements.add(WordPlacement(word: word, row: r, col: c, dr: dr, dc: dc));
  }

  void _fill(Random random) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i].isEmpty) {
        _cells[i] = alphabet[random.nextInt(alphabet.length)];
      }
    }
  }
}

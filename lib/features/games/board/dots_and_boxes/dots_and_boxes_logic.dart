/// Pure dots-and-boxes rules: edge claiming, box completion (which grants
/// another turn), scoring and a three-tier CPU — level 3 takes free boxes
/// and never gifts a 3rd edge when a safe alternative exists.
///
/// Deterministic given a seeded [Random]. No Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// One drawable line. Horizontal edges run between dots `(row, col)` and
/// `(row, col + 1)`; vertical edges between `(row, col)` and `(row + 1, col)`.
typedef DotsEdge = ({bool horizontal, int row, int col});

/// Classic dots-and-boxes grid of `size x size` boxes.
class DotsAndBoxesLogic {
  DotsAndBoxesLogic({
    required this.size,
    required this.aiLevel,
    required Random random,
  })  : assert(size >= 2 && size <= 8, 'size must be 2..8'),
        assert(aiLevel >= 1 && aiLevel <= 3, 'aiLevel must be 1..3'),
        _random = random,
        boxOwner = List<int>.filled(size * size, 0);

  /// Boxes per side.
  final int size;

  /// 1 easy (random), 2 medium (avoids obvious giveaways), 3 hard (takes
  /// free boxes + avoids giving away 3rd edges).
  final int aiLevel;
  final Random _random;

  static const int player = 1;
  static const int cpu = 2;

  /// Every drawn line this game.
  final Set<DotsEdge> drawnEdges = <DotsEdge>{};

  /// Who drew each drawn line ([player] / [cpu]) — paint colours.
  final Map<DotsEdge, int> edgeOwner = <DotsEdge, int>{};

  /// Owner per box (row-major): 0 none, [player], [cpu].
  final List<int> boxOwner;

  /// Whose move it is.
  int turn = player;

  int playerBoxes = 0;
  int cpuBoxes = 0;

  int get totalBoxes => size * size;
  int get claimedBoxes => playerBoxes + cpuBoxes;
  bool get isGameOver => claimedBoxes == totalBoxes;

  /// True when [edge] lies inside the grid.
  bool isValidEdge(DotsEdge edge) => edge.horizontal
      ? edge.row >= 0 && edge.row < size && edge.col >= 0 && edge.col <= size
      : edge.row >= 0 && edge.row <= size && edge.col >= 0 && edge.col < size;

  bool isDrawn(DotsEdge edge) => drawnEdges.contains(edge);

  /// Every not-yet-drawn edge.
  List<DotsEdge> get availableEdges => [
        for (final edge in _allEdges())
          if (!drawnEdges.contains(edge)) edge,
      ];

  Iterable<DotsEdge> _allEdges() sync* {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c <= size; c++) {
        yield (horizontal: true, row: r, col: c);
      }
    }
    for (var r = 0; r <= size; r++) {
      for (var c = 0; c < size; c++) {
        yield (horizontal: false, row: r, col: c);
      }
    }
  }

  /// The four edges bounding box `(br, bc)`.
  List<DotsEdge> edgesOfBox(int br, int bc) => [
        (horizontal: true, row: br, col: bc),
        (horizontal: true, row: br + 1, col: bc),
        (horizontal: false, row: br, col: bc),
        (horizontal: false, row: br, col: bc + 1),
      ];

  /// How many of the box's four edges are drawn (0..4); -1 out of range.
  int edgesDrawnAround(int br, int bc) {
    if (br < 0 || br >= size || bc < 0 || bc >= size) return -1;
    return edgesOfBox(br, bc).where(drawnEdges.contains).length;
  }

  /// The up-to-two boxes that share [edge].
  List<int> adjacentBoxes(DotsEdge edge) {
    final boxes = <int>[];
    if (edge.horizontal) {
      // Top edge of box (row, col), bottom edge of box (row - 1, col).
      for (final br in [edge.row, edge.row - 1]) {
        final bc = edge.col;
        if (br >= 0 && br < size && bc >= 0 && bc < size) boxes.add(br * size + bc);
      }
    } else {
      // Left edge of box (row, col), right edge of box (row, col - 1).
      for (final bc in [edge.col, edge.col - 1]) {
        final br = edge.row;
        if (br >= 0 && br < size && bc >= 0 && bc < size) boxes.add(br * size + bc);
      }
    }
    return boxes;
  }

  /// Draws [edge] for [who] and claims every box it completes. Returns the
  /// number of boxes completed (0, 1 or 2) — the caller keeps the turn
  /// when it is positive.
  int drawEdge(DotsEdge edge, int who) {
    assert(isValidEdge(edge), 'edge outside the grid');
    if (!isValidEdge(edge) || drawnEdges.contains(edge)) return 0;
    drawnEdges.add(edge);
    edgeOwner[edge] = who;
    var completed = 0;
    for (final flat in adjacentBoxes(edge)) {
      if (boxOwner[flat] != 0) continue;
      final br = flat ~/ size;
      final bc = flat % size;
      if (edgesDrawnAround(br, bc) == 4) {
        boxOwner[flat] = who;
        completed += 1;
        if (who == player) {
          playerBoxes += 1;
        } else {
          cpuBoxes += 1;
        }
      }
    }
    return completed;
  }

  /// Player move. Returns true when applied; the player keeps the turn
  /// after completing a box.
  bool playEdge(DotsEdge edge) {
    if (isGameOver || turn != player) return false;
    if (!isValidEdge(edge) || drawnEdges.contains(edge)) return false;
    final completed = drawEdge(edge, player);
    if (completed == 0) turn = cpu;
    return true;
  }

  /// Computes and applies the CPU move, returning the chosen edge.
  DotsEdge? cpuMove() {
    if (isGameOver || turn != cpu) return null;
    final edge = _cpuPick();
    if (edge == null) return null;
    final completed = drawEdge(edge, cpu);
    if (completed == 0) turn = player;
    return edge;
  }

  /// How many boxes drawing [edge] would complete right now (0, 1 or 2).
  int boxesCompletedBy(DotsEdge edge) {
    if (!isValidEdge(edge) || drawnEdges.contains(edge)) return 0;
    var count = 0;
    for (final flat in adjacentBoxes(edge)) {
      if (boxOwner[flat] != 0) continue;
      final edges = edgesOfBox(flat ~/ size, flat % size);
      final drawn = edges
          .where((e) => e == edge || drawnEdges.contains(e))
          .length;
      if (drawn == 4) count += 1;
    }
    return count;
  }

  /// True when drawing [edge] would complete at least one box right now.
  bool completesBox(DotsEdge edge) => boxesCompletedBy(edge) > 0;

  /// True when drawing [edge] would leave some adjacent unclaimed box with
  /// exactly three edges — a free box for the opponent.
  bool givesAwayBox(DotsEdge edge) {
    if (!isValidEdge(edge) || drawnEdges.contains(edge)) return false;
    for (final flat in adjacentBoxes(edge)) {
      if (boxOwner[flat] != 0) continue;
      final edges = edgesOfBox(flat ~/ size, flat % size);
      final drawn = edges
          .where((e) => e == edge || drawnEdges.contains(e))
          .length;
      if (drawn == 3) return true;
    }
    return false;
  }

  // -- CPU --------------------------------------------------------------------

  DotsEdge? _cpuPick() {
    final avail = availableEdges;
    if (avail.isEmpty) return null;
    switch (aiLevel) {
      case 3:
        // Take a free box first, preferring a double completion.
        var best = <DotsEdge>[];
        var bestCount = 0;
        for (final edge in avail) {
          final count = boxesCompletedBy(edge);
          if (count > bestCount) {
            bestCount = count;
            best = [edge];
          } else if (count == bestCount && count > 0) {
            best.add(edge);
          }
        }
        if (bestCount > 0) return _pickRandom(best);
        final safe = avail.where((e) => !givesAwayBox(e)).toList();
        if (safe.isNotEmpty) return _pickRandom(safe);
        return _pickRandom(avail);
      case 2:
        final safe = avail.where((e) => !givesAwayBox(e)).toList();
        if (safe.isNotEmpty) return _pickRandom(safe);
        return _pickRandom(avail);
      default:
        return _pickRandom(avail);
    }
  }

  DotsEdge _pickRandom(List<DotsEdge> list) =>
      list[_random.nextInt(list.length)];
}

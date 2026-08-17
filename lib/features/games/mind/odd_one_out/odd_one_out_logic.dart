/// Pure logic for odd-one-out — boards where every tile shares one shape
/// and colour except a single tile differing in BOTH (never colour-only),
/// round timing that accelerates, and scoring floored at zero.
///
/// NO Flutter imports: plain Dart, testable with a seeded Random.
library;

import 'dart:math';

/// Result of tapping a tile.
enum OddTapResult {
  /// The odd tile was found (+80).
  found,

  /// A group tile (-20, round continues).
  wrong,

  /// Tap outside an active round or out of range.
  ignored,
}

/// One board tile: a [shape] index and a [color] index. The engine maps
/// these to painters and `kPieceColors`; the logic stays palette-free.
class OddTile {
  const OddTile({required this.shape, required this.color});

  final int shape;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is OddTile && other.shape == shape && other.color == color;

  @override
  int get hashCode => Object.hash(shape, color);
}

class OddOneOutLogic {
  OddOneOutLogic({
    required this.items,
    required this.totalRounds,
    required Random random,
  })  : _random = random,
        assert(items >= 4 && items <= 16, 'items must be 4..16');

  /// Number of distinct shapes available (circle, square, triangle,
  /// diamond, star, hexagon).
  static const int shapeCount = 6;

  /// Number of distinct piece colours available (kPieceColors length).
  static const int colorCount = 8;

  /// Find window shrinks 100 ms per round, floored at 700 ms
  /// (round numbers are 1-based: round 1 = 1300 ms, round 7+ = 700 ms).
  static int windowMsForRound(int roundNumber) =>
      max(1400 - roundNumber * 100, 700);

  final int items;
  final int totalRounds;
  final Random _random;

  final List<OddTile> _tiles = <OddTile>[];
  int _round = 0;
  int _oddIndex = -1;
  int _found = 0;
  bool _roundActive = false;

  /// The current board (empty before the first round).
  List<OddTile> get tiles => List.unmodifiable(_tiles);

  /// 1-based round number; 0 before the first round starts.
  int get round => _round;

  /// Odd tiles found so far.
  int get found => _found;

  /// Index of the odd tile in [tiles], or -1 between rounds.
  int get oddIndex => _oddIndex;

  bool get isRoundActive => _roundActive;

  bool get isDone => _round >= totalRounds;

  /// 60% of rounds must be found to win (rounded up).
  int get winThreshold => (totalRounds * 0.6).ceil();

  bool get won => _found >= winThreshold;

  /// Generates the next board: [items] identical tiles plus one odd tile
  /// whose shape AND colour both differ from the group.
  List<OddTile> startRound() {
    final baseShape = _random.nextInt(shapeCount);
    final baseColor = _random.nextInt(colorCount);
    final oddShape = _differentFrom(baseShape, shapeCount);
    final oddColor = _differentFrom(baseColor, colorCount);
    final odd = OddTile(shape: oddShape, color: oddColor);
    final base = OddTile(shape: baseShape, color: baseColor);
    _oddIndex = _random.nextInt(items);
    _tiles
      ..clear()
      ..addAll([for (var i = 0; i < items; i++) i == _oddIndex ? odd : base]);
    _round += 1;
    _roundActive = true;
    return tiles;
  }

  /// Picks a value in 0..count-1 different from [value].
  int _differentFrom(int value, int count) =>
      (value + 1 + _random.nextInt(count - 1)) % count;

  /// Judges a tile tap. See [OddTapResult].
  OddTapResult tap(int index) {
    if (!_roundActive || index < 0 || index >= _tiles.length) {
      return OddTapResult.ignored;
    }
    if (index == _oddIndex) {
      _roundActive = false;
      _found += 1;
      return OddTapResult.found;
    }
    return OddTapResult.wrong;
  }

  /// The find window expired — the round counts as missed.
  void timeoutRound() => _roundActive = false;

  /// +80 per find, -20 per wrong tap, never below zero.
  static int scoreAfter({required int score, required bool found}) =>
      found ? score + 80 : max(0, score - 20);

  /// Serialization snapshot (pause / save).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'items': items,
        'rounds': totalRounds,
        'round': _round,
        'found': _found,
      };
}

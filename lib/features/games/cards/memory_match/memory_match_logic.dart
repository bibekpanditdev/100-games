/// Pure memory-match rules: deck construction, the two-flip state machine
/// (flip -> flip -> match / mismatch timeout) and win detection.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// Face-up state of one grid cell.
enum MemoryCardState { faceDown, faceUp, matched }

/// Outcome of attempting to flip one card.
enum MemoryFlipResult {
  /// The tap was ignored (already up, matched, or board locked).
  ignored,

  /// First card of a pair was revealed; awaiting the second flip.
  firstCard,

  /// Second card matched: both cells are now matched.
  matched,

  /// Second card mismatched: the pair stays face-up until the caller
  /// resolves it via [MemoryLogic.resolveMismatch].
  mismatched,
}

/// One playing card. Cards carry a rank and a suit so identical faces are
/// distinguished by more than colour (rank text + suit shape).
class MemoryCard {
  const MemoryCard({required this.rank, required this.suit});

  /// 1..13 — ace..king.
  final int rank;

  /// 0 hearts, 1 diamonds, 2 spades, 3 clubs.
  final int suit;

  @override
  bool operator ==(Object other) =>
      other is MemoryCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}

/// Grid of face-down card pairs with the classic flip state machine.
class MemoryLogic {
  /// Creates a shuffled grid of [pairs] matching card pairs.
  MemoryLogic({required int pairs, required Random random})
      : assert(pairs >= 2 && pairs <= 26, 'pairs must be 2..26') {
    final stock = <MemoryCard>[
      for (var suit = 0; suit < 4; suit++)
        for (var rank = 1; rank <= 13; rank++) MemoryCard(rank: rank, suit: suit),
    ]..shuffle(random);
    final picked = stock.take(pairs).toList();
    deck = [...picked, ...picked]..shuffle(random);
    states = List<MemoryCardState>.filled(deck.length, MemoryCardState.faceDown);
  }

  /// Row-major deck of `2 * pairs` cards, shuffled.
  late final List<MemoryCard> deck;

  /// Flip state per cell, parallel to [deck].
  late final List<MemoryCardState> states;

  /// Index of the first revealed card awaiting its partner, if any.
  int? firstFlipped;

  /// The two mismatched indices shown while the caller runs the reveal
  /// timeout. While set the board is locked.
  List<int>? pendingMismatch;

  /// Completed flip pairs (both successful and failed attempts count).
  int moves = 0;

  int get cardCount => deck.length;
  int get pairCount => deck.length ~/ 2;

  int get matchedPairs => states.where((s) => s == MemoryCardState.matched).length ~/ 2;

  bool get isWon => matchedPairs == pairCount;

  MemoryCard cardAt(int index) => deck[index];

  MemoryCardState stateAt(int index) => states[index];

  /// True while a mismatch pair is showing and no flip is allowed.
  bool get isLocked => pendingMismatch != null;

  /// Attempts to flip the cell at [index].
  MemoryFlipResult flip(int index) {
    if (index < 0 || index >= deck.length) return MemoryFlipResult.ignored;
    if (isLocked || isWon) return MemoryFlipResult.ignored;
    if (states[index] != MemoryCardState.faceDown) return MemoryFlipResult.ignored;

    final first = firstFlipped;
    if (first == null) {
      states[index] = MemoryCardState.faceUp;
      firstFlipped = index;
      return MemoryFlipResult.firstCard;
    }

    states[index] = MemoryCardState.faceUp;
    moves += 1;
    if (deck[first] == deck[index]) {
      states[first] = MemoryCardState.matched;
      states[index] = MemoryCardState.matched;
      firstFlipped = null;
      return MemoryFlipResult.matched;
    }
    pendingMismatch = <int>[first, index];
    firstFlipped = null;
    return MemoryFlipResult.mismatched;
  }

  /// Turns the showing mismatch pair back face-down and unlocks the board.
  /// Call after the reveal timeout.
  void resolveMismatch() {
    final pair = pendingMismatch;
    if (pair == null) return;
    for (final index in pair) {
      if (states[index] == MemoryCardState.faceUp) {
        states[index] = MemoryCardState.faceDown;
      }
    }
    pendingMismatch = null;
  }

  /// Index of an unmatched card that still has a hidden partner, for hints.
  int? anyUnmatchedFaceDown() {
    for (var i = 0; i < deck.length; i++) {
      if (states[i] == MemoryCardState.faceDown) return i;
    }
    return null;
  }
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/cards/memory_match/memory_match_logic.dart';

void main() {
  group('deck construction', () {
    test('deals exactly two copies of each of `pairs` cards', () {
      final logic = MemoryLogic(pairs: 10, random: Random(7));
      expect(logic.cardCount, 20);
      expect(logic.pairCount, 10);
      final counts = <MemoryCard, int>{};
      for (var i = 0; i < logic.cardCount; i++) {
        final card = logic.cardAt(i);
        counts[card] = (counts[card] ?? 0) + 1;
      }
      expect(counts.length, 10);
      expect(counts.values.every((n) => n == 2), isTrue);
    });

    test('same seed deals the same shuffled deck', () {
      final a = MemoryLogic(pairs: 8, random: Random(42));
      final b = MemoryLogic(pairs: 8, random: Random(42));
      for (var i = 0; i < a.cardCount; i++) {
        expect(a.cardAt(i), b.cardAt(i));
      }
    });

    test('different seeds usually shuffle differently', () {
      final a = MemoryLogic(pairs: 12, random: Random(1));
      final b = MemoryLogic(pairs: 12, random: Random(2));
      var sameOrder = true;
      for (var i = 0; i < a.cardCount; i++) {
        if (a.cardAt(i) != b.cardAt(i)) sameOrder = false;
      }
      expect(sameOrder, isFalse);
    });
  });

  group('flip state machine', () {
    test('first flip reveals, identical second flip matches', () {
      final logic = MemoryLogic(pairs: 8, random: Random(3));
      // Find two cells holding the same card.
      var first = -1;
      var second = -1;
      outer:
      for (var i = 0; i < logic.cardCount; i++) {
        for (var j = i + 1; j < logic.cardCount; j++) {
          if (logic.cardAt(i) == logic.cardAt(j)) {
            first = i;
            second = j;
            break outer;
          }
        }
      }
      expect(logic.flip(first), MemoryFlipResult.firstCard);
      expect(logic.stateAt(first), MemoryCardState.faceUp);
      expect(logic.moves, 0);

      expect(logic.flip(second), MemoryFlipResult.matched);
      expect(logic.stateAt(first), MemoryCardState.matched);
      expect(logic.stateAt(second), MemoryCardState.matched);
      expect(logic.moves, 1);
      expect(logic.matchedPairs, 1);

      // Matched cells can no longer be flipped.
      expect(logic.flip(first), MemoryFlipResult.ignored);
      // The same cell can never be flipped twice in a row.
      final other = _firstCellNot(logic, {first, second});
      expect(logic.flip(other), MemoryFlipResult.firstCard);
      expect(logic.flip(other), MemoryFlipResult.ignored);
    });

    test('mismatch shows the pair, locks the board, then resolves', () {
      final logic = MemoryLogic(pairs: 8, random: Random(5));
      final pair = _mismatchedPair(logic);
      expect(logic.flip(pair.$1), MemoryFlipResult.firstCard);
      expect(logic.flip(pair.$2), MemoryFlipResult.mismatched);
      expect(logic.moves, 1);
      expect(logic.isLocked, isTrue);
      expect(logic.pendingMismatch, unorderedEquals(<int>[pair.$1, pair.$2]));
      expect(logic.stateAt(pair.$1), MemoryCardState.faceUp);

      // Locked board ignores further flips.
      final other = _firstCellNot(logic, {pair.$1, pair.$2});
      expect(logic.flip(other), MemoryFlipResult.ignored);

      logic.resolveMismatch();
      expect(logic.isLocked, isFalse);
      expect(logic.pendingMismatch, isNull);
      expect(logic.stateAt(pair.$1), MemoryCardState.faceDown);
      expect(logic.stateAt(pair.$2), MemoryCardState.faceDown);
      expect(logic.moves, 1, reason: 'resolving does not count as a move');
    });
  });

  group('win detection and move counting', () {
    test('matching every pair wins and counts every attempt as a move', () {
      final logic = MemoryLogic(pairs: 6, random: Random(11));
      var moves = 0;
      // Match every pair without mismatches.
      final taken = <int>{};
      while (!logic.isWon) {
        var first = -1;
        var second = -1;
        outer:
        for (var i = 0; i < logic.cardCount; i++) {
          if (taken.contains(i)) continue;
          for (var j = i + 1; j < logic.cardCount; j++) {
            if (taken.contains(j)) continue;
            if (logic.cardAt(i) == logic.cardAt(j)) {
              first = i;
              second = j;
              break outer;
            }
          }
        }
        expect(logic.flip(first), MemoryFlipResult.firstCard);
        expect(logic.flip(second), MemoryFlipResult.matched);
        taken
          ..add(first)
          ..add(second);
        moves += 1;
      }
      expect(logic.matchedPairs, 6);
      expect(logic.moves, moves);
      expect(logic.isWon, isTrue);
    });

    test('mismatched attempts count towards moves too', () {
      final logic = MemoryLogic(pairs: 4, random: Random(13));
      final pair = _mismatchedPair(logic);
      logic.flip(pair.$1);
      logic.flip(pair.$2);
      expect(logic.moves, 1);
      logic.resolveMismatch();
      logic.flip(pair.$1);
      logic.flip(pair.$2);
      expect(logic.moves, 2);
      expect(logic.matchedPairs, 0);
    });
  });
}

/// First cell index outside [exclude].
int _firstCellNot(MemoryLogic logic, Set<int> exclude) {
  for (var i = 0; i < logic.cardCount; i++) {
    if (!exclude.contains(i)) return i;
  }
  fail('no cell left');
}

/// Two cells holding different cards, for mismatch tests.
(int, int) _mismatchedPair(MemoryLogic logic) {
  for (var i = 0; i < logic.cardCount; i++) {
    for (var j = i + 1; j < logic.cardCount; j++) {
      if (logic.cardAt(i) != logic.cardAt(j)) return (i, j);
    }
  }
  fail('no mismatching pair found');
}

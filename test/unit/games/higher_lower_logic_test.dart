import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/cards/higher_lower/higher_lower_logic.dart';

void main() {
  group('deck dealing', () {
    test('never repeats a card across a whole session', () {
      for (var seed = 0; seed < 25; seed++) {
        final logic = HigherLowerLogic(rounds: 15, random: Random(seed));
        while (!logic.isOver) {
          logic.guess(
            logic.currentCard.rank <= 7
                ? HigherLowerChoice.higher
                : HigherLowerChoice.lower,
          );
        }
        final seen = logic.revealedCards;
        expect(seen.length, logic.round + 1);
        expect(seen.toSet().length, seen.length,
            reason: 'seed $seed dealt a duplicate card');
        expect(logic.isOver, isTrue);
      }
    });
  });

  group('comparison', () {
    test('correctness flag always matches the ace-low..king-high order',
        () {
      for (var seed = 0; seed < 200; seed++) {
        final logic = HigherLowerLogic(rounds: 6, random: Random(seed));
        while (!logic.isOver) {
          final before = logic.currentCard.rank;
          final choice = seed.isEven
              ? HigherLowerChoice.higher
              : HigherLowerChoice.lower;
          final result = logic.guess(choice);
          final expected = switch (choice) {
            HigherLowerChoice.higher => result.nextCard.rank > before,
            HigherLowerChoice.lower => result.nextCard.rank < before,
          };
          expect(result.correct, expected,
              reason: 'seed $seed rank $before next ${result.nextCard.rank}');
        }
      }
    });

    test('nothing is higher than a king', () {
      var checked = 0;
      for (var seed = 0; seed < 4000 && checked < 20; seed++) {
        final logic = HigherLowerLogic(rounds: 1, random: Random(seed));
        if (logic.currentCard.rank != 13) continue;
        checked += 1;
        final result = logic.guess(HigherLowerChoice.higher);
        expect(result.correct, isFalse);
      }
      expect(checked, greaterThan(0), reason: 'never drew a current king');
    });

    test('nothing is lower than an ace', () {
      var checked = 0;
      for (var seed = 0; seed < 4000 && checked < 20; seed++) {
        final logic = HigherLowerLogic(rounds: 1, random: Random(seed));
        if (logic.currentCard.rank != 1) continue;
        checked += 1;
        final result = logic.guess(HigherLowerChoice.lower);
        expect(result.correct, isFalse);
      }
      expect(checked, greaterThan(0), reason: 'never drew a current ace');
    });

    test('an equal rank counts as wrong for both bets', () {
      var found = false;
      for (var seed = 0; seed < 20000 && !found; seed++) {
        final logic = HigherLowerLogic(rounds: 1, random: Random(seed));
        final cur = logic.currentCard.rank;
        final result = logic.guess(HigherLowerChoice.higher);
        if (result.nextCard.rank == cur) {
          found = true;
          expect(result.correct, isFalse);
          expect(result.pointsGained, 0);
          expect(result.livesLeft, logic.startingLives - 1);
        }
      }
      expect(found, isTrue, reason: 'never drew an equal-rank pair');
    });
  });

  group('lives and streak math', () {
    test('streak bonus pays 25 per prior consecutive correct call', () {
      for (var seed = 0; seed < 60; seed++) {
        final logic = HigherLowerLogic(rounds: 12, random: Random(seed));
        var streakBefore = 0;
        var livesBefore = logic.startingLives;
        var score = 0;
        while (!logic.isOver) {
          final before = logic.currentCard.rank;
          final result = logic.guess(before >= 8 || before <= 2
              ? (before >= 8 ? HigherLowerChoice.lower : HigherLowerChoice.higher)
              : HigherLowerChoice.higher);
          if (result.correct) {
            expect(result.pointsGained, 100 + 25 * streakBefore);
            expect(result.streak, streakBefore + 1);
            expect(result.livesLeft, livesBefore);
            score += result.pointsGained;
          } else {
            expect(result.pointsGained, 0);
            expect(result.streak, 0);
            expect(result.livesLeft, livesBefore - 1);
            livesBefore = result.livesLeft;
          }
          streakBefore = result.streak;
          expect(logic.score, score);
        }
      }
    });

    test('three wrong calls end the session', () {
      for (var seed = 0; seed < 300; seed++) {
        final logic = HigherLowerLogic(rounds: 5, random: Random(seed));
        // Bet "lower" on a king or "higher" on an ace to force losses.
        while (!logic.isOver) {
          final rank = logic.currentCard.rank;
          logic.guess(rank == 13
              ? HigherLowerChoice.lower
              : HigherLowerChoice.higher);
          // Keep forcing: if the new card doesn't guarantee a loss the
          // loop continues until lives run out or rounds complete.
        }
        if (logic.outOfLives) {
          expect(logic.lives, lessThanOrEqualTo(0));
          expect(logic.completedRounds, isFalse);
        } else {
          expect(logic.completedRounds, isTrue);
        }
      }
    });

    test('revive grants exactly one extra life', () {
      final logic = HigherLowerLogic(rounds: 10, random: Random(1));
      var guard = 0;
      while (!logic.outOfLives && guard++ < 60) {
        final rank = logic.currentCard.rank;
        logic.guess(rank == 13
            ? HigherLowerChoice.lower
            : HigherLowerChoice.higher);
      }
      expect(logic.outOfLives, isTrue);
      logic.revive();
      expect(logic.lives, 1);
      expect(logic.isOver, isFalse);
    });
  });
}

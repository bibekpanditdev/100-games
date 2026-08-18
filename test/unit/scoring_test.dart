/// Scoring economy tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:game/features/catalog/domain/game_definition.dart';
import 'package:game/features/gamification/scoring.dart';

void main() {
  group('coinsFor', () {
    test('every finish pays at least 5 coins', () {
      expect(
        Scoring.coinsFor(score: 0, won: false, difficulty: Difficulty.easy),
        greaterThanOrEqualTo(5),
      );
    });

    test('wins pay more than losses at the same score', () {
      final win = Scoring.coinsFor(score: 500, won: true, difficulty: Difficulty.medium);
      final loss = Scoring.coinsFor(score: 500, won: false, difficulty: Difficulty.medium);
      expect(win, greaterThan(loss));
    });

    test('harder difficulties pay more', () {
      final easy = Scoring.coinsFor(score: 500, won: true, difficulty: Difficulty.easy);
      final hard = Scoring.coinsFor(score: 500, won: true, difficulty: Difficulty.hard);
      expect(hard, greaterThan(easy));
    });

    test('capped at 200', () {
      expect(
        Scoring.coinsFor(score: 1000000, won: true, difficulty: Difficulty.hard),
        lessThanOrEqualTo(200),
      );
    });
  });

  group('starsFor', () {
    test('loss with score earns one star', () {
      expect(
        Scoring.starsFor(score: 300, won: false, difficulty: Difficulty.easy),
        1,
      );
    });

    test('total loss earns nothing', () {
      expect(Scoring.starsFor(score: 0, won: false, difficulty: Difficulty.easy), 0);
    });

    test('plain win is two stars', () {
      expect(
        Scoring.starsFor(score: 100, won: true, difficulty: Difficulty.easy, target: 100),
        2,
      );
    });

    test('beating target by 25%+ is three stars', () {
      expect(
        Scoring.starsFor(score: 1300, won: true, difficulty: Difficulty.medium, target: 1000),
        3,
      );
    });

    test('strong endless score without target is three stars', () {
      expect(
        Scoring.starsFor(score: 1200, won: true, difficulty: Difficulty.medium),
        3,
      );
    });
  });
}

/// Coins + daily streak + interstitial cap tests (Hive box backed).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/gamification/progress_controller.dart';

import '../helpers/test_env.dart';

void main() {
  setUpAll(setupTestEnv);

  group('coins', () {
    test('earn and spend', () async {
      final box = await openTestBox('coins');
      final c = ProgressController(box);

      c.earnCoins(500);
      expect(c.coins, 500);
      expect(c.coinsEarnedTotal, 500);

      expect(c.spendCoins(150), isTrue);
      expect(c.coins, 350);
      expect(c.spendCoins(10000), isFalse);
      expect(c.coins, 350);
    });

    test('hint/extra life affordability flags', () async {
      final box = await openTestBox('afford');
      final c = ProgressController(box);
      expect(c.canAffordHint, isFalse);
      c.earnCoins(ProgressController.hintCost);
      expect(c.canAffordHint, isTrue);
      expect(c.canAffordExtraLife, isFalse);
    });
  });

  group('daily streak', () {
    test('first play starts streak at 1', () async {
      final box = await openTestBox('streak1');
      final c = ProgressController(box);
      final now = DateTime(2026, 8, 17, 10);
      expect(c.touchDailyStreak(now: now), 1);
    });

    test('same-day replays do not extend the streak', () async {
      final box = await openTestBox('streak2');
      final c = ProgressController(box);
      final day = DateTime(2026, 8, 17, 10);
      c.touchDailyStreak(now: day);
      expect(c.touchDailyStreak(now: day.add(const Duration(hours: 6))), 1);
    });

    test('consecutive days increment', () async {
      final box = await openTestBox('streak3');
      final c = ProgressController(box);
      c.touchDailyStreak(now: DateTime(2026, 8, 15));
      expect(c.touchDailyStreak(now: DateTime(2026, 8, 16)), 2);
      expect(c.touchDailyStreak(now: DateTime(2026, 8, 17)), 3);
    });

    test('skipping a day resets to 1', () async {
      final box = await openTestBox('streak4');
      final c = ProgressController(box);
      c.touchDailyStreak(now: DateTime(2026, 8, 13));
      c.touchDailyStreak(now: DateTime(2026, 8, 14));
      expect(c.touchDailyStreak(now: DateTime(2026, 8, 17)), 1);
    });
  });

  group('interstitial frequency cap', () {
    test('shows only every 3rd exit and never right after showing', () async {
      final box = await openTestBox('interstitial');
      final c = ProgressController(box);

      c.noteGameExit();
      c.noteGameExit();
      expect(c.shouldShowInterstitial(), isFalse);
      c.noteGameExit();
      expect(c.shouldShowInterstitial(), isTrue);

      c.noteInterstitialShown();
      expect(c.shouldShowInterstitial(), isFalse);
    });
  });

  group('play history', () {
    test('records last played and counts', () async {
      final box = await openTestBox('history');
      final c = ProgressController(box);

      c.recordPlay('snake_neon_hard');
      c.recordPlay('snake_neon_hard');
      c.recordPlay('match3_ocean_easy');

      expect(c.playCountOf('snake_neon_hard'), 2);
      expect(c.playCountOf('match3_ocean_easy'), 1);
      expect(c.lastPlayed.containsKey('match3_ocean_easy'), isTrue);
    });
  });

  group('adaptive difficulty', () {
    test('no suggestion without enough history', () async {
      final c = ProgressController(await openTestBox('adaptive1'));
      expect(c.suggestedDifficulty('sudoku'), isNull);
      c.recordResultForAdaptive('sudoku', 3);
      c.recordResultForAdaptive('sudoku', 3);
      expect(c.suggestedDifficulty('sudoku'), isNull);
    });

    test('strong results suggest hard, weak suggest easy', () async {
      final c = ProgressController(await openTestBox('adaptive2'));
      for (var i = 0; i < 4; i++) {
        c.recordResultForAdaptive('sudoku', 3);
      }
      expect(c.suggestedDifficulty('sudoku'), 'hard');

      final c2 = ProgressController(await openTestBox('adaptive3'));
      for (var i = 0; i < 4; i++) {
        c2.recordResultForAdaptive('sudoku', 0);
      }
      expect(c2.suggestedDifficulty('sudoku'), 'easy');
    });

    test('templates tracked independently', () async {
      final c = ProgressController(await openTestBox('adaptive4'));
      for (var i = 0; i < 3; i++) {
        c.recordResultForAdaptive('simon', 2);
      }
      expect(c.suggestedDifficulty('simon'), 'medium');
      expect(c.suggestedDifficulty('maze'), isNull);
    });
  });
}

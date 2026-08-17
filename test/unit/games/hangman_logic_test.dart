/// Unit tests for the hangman pure-logic class.
///
/// Runs against inline fixtures only (no rootBundle); the shipped word-bank
/// asset itself is validated in `wordle_daily_logic_test.dart`.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/mind/hangman/hangman_logic.dart';

/// Mixed-case words of every length 4..9 to exercise bounds + normalization.
const List<String> kFixtureBank = [
  // 4
  'word', 'code', 'game', 'play',
  // 5
  'apple', 'bread',
  // 6
  'flower', 'garden',
  // 7
  'pattern', 'harvest',
  // 8
  'language', 'sequence',
  // 9
  'chocolate', 'adventure',
  // out of any usable range
  'pi', 'extraordinarily',
];

HangmanLogic start({
  required int minLen,
  required int maxLen,
  int lives = 7,
  int seed = 1,
}) =>
    HangmanLogic.start(
      bank: kFixtureBank,
      minLen: minLen,
      maxLen: maxLen,
      lives: lives,
      random: Random(seed),
    );

void main() {
  group('word selection', () {
    test('picks words within the configured length bounds', () {
      for (var seed = 1; seed <= 60; seed++) {
        final short = start(minLen: 4, maxLen: 5, seed: seed);
        expect(short.word.length, inInclusiveRange(4, 5),
            reason: 'seed $seed picked ${short.word}');
        final medium = start(minLen: 6, maxLen: 7, seed: seed);
        expect(medium.word.length, inInclusiveRange(6, 7),
            reason: 'seed $seed picked ${medium.word}');
        final long = start(minLen: 8, maxLen: 9, seed: seed);
        expect(long.word.length, inInclusiveRange(8, 9),
            reason: 'seed $seed picked ${long.word}');
      }
    });

    test('words are normalized to uppercase', () {
      for (var seed = 1; seed <= 20; seed++) {
        final logic = start(minLen: 4, maxLen: 9, seed: seed);
        expect(logic.word, equals(logic.word.toUpperCase()));
      }
    });

    test('same seed picks the same word', () {
      for (var seed = 1; seed <= 20; seed++) {
        expect(start(minLen: 6, maxLen: 7, seed: seed).word,
            start(minLen: 6, maxLen: 7, seed: seed).word);
      }
    });

    test('empty range falls back to the full bank instead of crashing', () {
      final logic = start(minLen: 12, maxLen: 14);
      expect(kFixtureBank.map((w) => w.toUpperCase()), contains(logic.word));
    });

    test('completely empty bank still produces a playable word', () {
      final logic = HangmanLogic.start(
        bank: const [],
        minLen: 4,
        maxLen: 9,
        lives: 6,
        random: Random(1),
      );
      expect(logic.word, isNotEmpty);
      expect(logic.isOver, isFalse);
    });
  });

  group('letter judging', () {
    test('hit reveals, miss costs a life, repeats are alreadyTried', () {
      final logic = HangmanLogic(word: 'banana', lives: 6);
      expect(logic.tryLetter('B'), HangmanGuessResult.hit);
      expect(logic.maskedWord, 'B_____');
      expect(logic.revealedCount, 1);
      expect(logic.tryLetter('b'), HangmanGuessResult.alreadyTried);
      expect(logic.lives, 6);
      expect(logic.tryLetter('Z'), HangmanGuessResult.miss);
      expect(logic.lives, 5);
      expect(logic.maskedWord, 'B_____');
      expect(logic.tryLetter('A'), HangmanGuessResult.hit);
      expect(logic.maskedWord, 'BA_A_A');
      expect(logic.revealedCount, 4);
    });

    test('maskedWord tracks every revealed position', () {
      final logic = HangmanLogic(word: 'CHOCOLATE', lives: 8);
      expect(logic.maskedWord, '_________');
      logic.tryLetter('O');
      expect(logic.maskedWord, '__O_O____');
      logic.tryLetter('C');
      expect(logic.maskedWord, 'C_OCO____');
    });

    test('vowels found counts distinct revealed vowels only', () {
      final logic = HangmanLogic(word: 'BANANA', lives: 6);
      expect(logic.vowelTotal, 1);
      expect(logic.vowelsFound, 0);
      logic.tryLetter('B');
      expect(logic.vowelsFound, 0);
      logic.tryLetter('A');
      expect(logic.vowelsFound, 1);
      logic.tryLetter('E'); // a vowel, but not in the word
      expect(logic.vowelsFound, 1);
    });

    test('non-letter and empty input is ignored', () {
      final logic = HangmanLogic(word: 'BANANA', lives: 6);
      expect(logic.tryLetter('1'), HangmanGuessResult.ignored);
      expect(logic.tryLetter(''), HangmanGuessResult.ignored);
      expect(logic.tryLetter('AB'), HangmanGuessResult.ignored);
      expect(logic.lives, 6);
      expect(logic.tried, isEmpty);
    });
  });

  group('win / lose', () {
    test('revealing every letter wins', () {
      final logic = HangmanLogic(word: 'GARDEN', lives: 7);
      for (final letter in ['G', 'A', 'R', 'D', 'E', 'N']) {
        expect(logic.isOver, isFalse);
        logic.tryLetter(letter);
      }
      expect(logic.isWon, isTrue);
      expect(logic.isLost, isFalse);
      expect(logic.tryLetter('Q'), HangmanGuessResult.ignored);
    });

    test('draining lives loses with partial reveals for the score', () {
      final logic = HangmanLogic(word: 'GARDEN', lives: 2);
      logic.tryLetter('G');
      expect(logic.revealedCount, 1);
      logic.tryLetter('Z');
      expect(logic.lives, 1);
      expect(logic.isLost, isFalse);
      logic.tryLetter('Q');
      expect(logic.isLost, isTrue);
      expect(logic.isWon, isFalse);
      // Losing score per spec: revealedCount * 20.
      expect(logic.revealedCount * 20, 20);
    });

    test('repeated wrong letters never double-charge a life', () {
      final logic = HangmanLogic(word: 'GARDEN', lives: 5);
      logic.tryLetter('Z');
      logic.tryLetter('Z');
      logic.tryLetter('Z');
      expect(logic.lives, 4);
    });
  });

  group('serialization round-trip (save/resume)', () {
    test('toMap -> tryFromMap restores word, lives and tried letters', () {
      final logic = HangmanLogic(word: 'flower', lives: 6);
      logic.tryLetter('F');
      logic.tryLetter('Z');
      logic.tryLetter('O');
      final restored = HangmanLogic.tryFromMap(logic.toMap());
      expect(restored, isNotNull);
      expect(restored!.word, 'FLOWER');
      expect(restored.maxLives, 6);
      expect(restored.lives, 5);
      expect(restored.tried, ['F', 'Z', 'O']);
      expect(restored.maskedWord, 'F_O___');
      expect(restored.isOver, isFalse);
    });

    test('finished runs restore their outcome', () {
      final won = HangmanLogic(word: 'CAKE', lives: 8);
      for (final l in ['C', 'A', 'K', 'E']) {
        won.tryLetter(l);
      }
      final restoredWon = HangmanLogic.tryFromMap(won.toMap());
      expect(restoredWon!.isWon, isTrue);

      final lost = HangmanLogic(word: 'CAKE', lives: 1);
      lost.tryLetter('Z');
      final restoredLost = HangmanLogic.tryFromMap(lost.toMap());
      expect(restoredLost!.isLost, isTrue);
    });

    test('corrupt maps restore null so the engine can start fresh', () {
      expect(HangmanLogic.tryFromMap(null), isNull);
      expect(HangmanLogic.tryFromMap(<String, dynamic>{}), isNull);
      expect(
        HangmanLogic.tryFromMap(<String, dynamic>{
          'word': 'NOT A WORD',
          'lives': 3,
          'maxLives': 6,
          'tried': <String>['A'],
        }),
        isNull,
      );
      expect(
        HangmanLogic.tryFromMap(<String, dynamic>{
          'word': 'CAKE',
          'lives': 9,
          'maxLives': 6,
          'tried': <String>[],
        }),
        isNull,
      );
      expect(
        HangmanLogic.tryFromMap(<String, dynamic>{
          'word': 'CAKE',
          'lives': 2,
          'maxLives': 6,
          'tried': 'ABC',
        }),
        isNull,
      );
    });
  });

  group('bank parsing', () {
    test('wordsFromBank flattens and normalizes the tiers', () {
      final words = HangmanLogic.wordsFromBank(<String, dynamic>{
        'hangman': {
          'short': ['x!?', 'cake', 'BREAD'],
          'medium': <String>['garden'],
          'long': <dynamic>['CHOCOLATE', 42, null],
        },
        'wordle_answers': <String>['SHOULD', 'IGNORED'],
      });
      expect(words, ['BREAD', 'CAKE', 'CHOCOLATE', 'GARDEN']);
    });

    test('wordsFromBank tolerates a missing hangman section', () {
      expect(HangmanLogic.wordsFromBank(<String, dynamic>{}), isEmpty);
    });
  });
}

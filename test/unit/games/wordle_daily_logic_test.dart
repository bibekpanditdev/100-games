/// Unit tests for the offline daily word-game pure-logic class.
///
/// Runs against inline fixtures (no rootBundle) AND validates the real
/// shipped word bank `assets/mind/words/word_bank.json` via dart:io.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/core/utils/formatters.dart';
import 'package:thousand_games/features/games/mind/wordle_daily/wordle_daily_logic.dart';

const List<String> kFixtureBank = [
  'apple', 'beach', 'chair', 'dream', 'eagle', 'flame', 'ghost', 'heart',
  'ideal', 'jewel', 'knife', 'lemon', 'maple', 'noble', 'ocean', 'piano',
  'quilt', 'river', 'stone', 'tiger', 'unity', 'vivid', 'wheat', 'yield',
  'zebra', 'brave', 'cloud', 'dance', 'earth', 'fruit',
];

WordleDailyLogic daily({
  String day = '2026-08-17',
  String id = 'wordle_daily_medium',
  int maxGuesses = 6,
}) =>
    WordleDailyLogic.daily(
      bank5: kFixtureBank,
      dayKey: day,
      definitionId: id,
      maxGuesses: maxGuesses,
    );

void main() {
  group('daily word selection', () {
    test('follows the stableHash(day|id) % bank formula exactly', () {
      final expected =
          kFixtureBank[stableHash('2026-08-17|wordle_daily_medium') % 30]
              .toUpperCase();
      expect(daily().answer, expected);
    });

    test('is deterministic per (day, id)', () {
      for (final id in ['wordle_daily_easy', 'wordle_daily_medium', 'x']) {
        for (final day in ['2026-08-17', '2025-01-01', '2024-02-29']) {
          expect(daily(day: day, id: id).answer,
              daily(day: day, id: id).answer);
        }
      }
    });

    test('different variants get their own word for the same day', () {
      final answers = <String>{
        for (final id in [
          'wordle_daily_easy',
          'wordle_daily_medium',
          'wordle_daily_hard',
          'variant_4',
          'variant_5',
        ])
          daily(id: id).answer,
      };
      expect(answers.length, greaterThan(1),
          reason: 'five variants should not all share one word');
    });

    test('the word changes across days', () {
      final answers = <String>{
        for (var offset = 0; offset < 12; offset++)
          daily(day: dayKey(DateTime(2026, 8, 1).add(Duration(days: offset))))
              .answer,
      };
      expect(answers.length, greaterThan(1),
          reason: '12 consecutive days must not all share one word');
      // ...and it is stable within the same day.
      final today = dayKey(DateTime(2026, 8, 17));
      expect(daily(day: today).answer, daily(day: today).answer);
    });

    test('always picks a real 5-letter word from the bank', () {
      final upper = kFixtureBank.map((w) => w.toUpperCase()).toSet();
      for (var i = 0; i < 60; i++) {
        expect(upper, contains(daily(day: '2026-0${1 + i ~/ 30}-$i').answer));
      }
    });

    test('dayKey produces zero-padded local calendar keys', () {
      expect(dayKey(DateTime(2026, 3, 9)), '2026-03-09');
    });
  });

  group('letter feedback (duplicate-aware)', () {
    test('exact matches come first', () {
      expect(
        WordleDailyLogic.feedbackFor('APPLE', 'APPLE'),
        everyElement(WordleMark.correct),
      );
    });

    test('no matches are all absent', () {
      expect(
        WordleDailyLogic.feedbackFor('BRICK', 'PLUMS'),
        everyElement(WordleMark.absent),
      );
    });

    test('SPEED vs GUESS: duplicates do not over-mark present', () {
      expect(
        WordleDailyLogic.feedbackFor('SPEED', 'GUESS'),
        [
          WordleMark.present, // S — answer has two S, none used by exact
          WordleMark.absent, // P
          WordleMark.correct, // E in place
          WordleMark.absent, // E — only one E in answer, already consumed
          WordleMark.absent, // D
        ],
      );
    });

    test('GUESS vs SPEED: the mirror case marks only one S present', () {
      expect(
        WordleDailyLogic.feedbackFor('GUESS', 'SPEED'),
        [
          WordleMark.absent, // G
          WordleMark.absent, // U
          WordleMark.correct, // E in place
          WordleMark.present, // first S
          WordleMark.absent, // second S — answer has only one left
        ],
      );
    });

    test('double letters in the answer can both be marked present', () {
      expect(
        WordleDailyLogic.feedbackFor('SASSY', 'GUESS'),
        [
          WordleMark.present, // S
          WordleMark.absent, // A
          WordleMark.absent, // S — the two exact S consumed both
          WordleMark.correct, // S in place
          WordleMark.absent, // Y
        ],
      );
    });

    test('wrong-position letters are present, not correct', () {
      expect(
        WordleDailyLogic.feedbackFor('LEMON', 'APPLE'),
        [
          WordleMark.present, // L
          WordleMark.present, // E
          WordleMark.absent, // M
          WordleMark.absent, // O
          WordleMark.absent, // N
        ],
      );
    });
  });

  group('guess validation', () {
    test('rejects wrong length, bad characters and unknown words', () {
      final logic = daily();
      expect(logic.checkGuess('CAT'), WordleReject.badLength);
      expect(logic.checkGuess('CATS!'), WordleReject.badLetters);
      expect(logic.checkGuess('ZZZZZ'), WordleReject.notInDictionary);
      expect(logic.checkGuess('apple'), isNull); // normalized on submit
    });

    test('any 5-letter word is accepted when no dictionary is supplied', () {
      final logic = WordleDailyLogic(answer: 'QUIET', maxGuesses: 6);
      expect(logic.checkGuess('ZZZZZ'), isNull);
    });

    test('submit consumes a guess and returns its marks', () {
      final logic = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      final guess = logic.submit('MAPLE');
      expect(guess, isNotNull);
      expect(guess!.word, 'MAPLE');
      expect(guess.marks[0], WordleMark.absent); // M
      expect(guess.marks[1], WordleMark.present); // A — right letter, wrong spot
      expect(guess.marks[2], WordleMark.correct); // P in place
      expect(logic.guessCount, 1);
      expect(logic.guessesLeft, 5);
      expect(logic.submit('NOPE'), isNull); // bad length — not consumed
      expect(logic.guessCount, 1);
    });
  });

  group('win / lose', () {
    test('guessing the answer wins, scoring faster guesses higher', () {
      final fast = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      fast.submit('PLUMB');
      fast.submit('APPLE');
      expect(fast.isWon, isTrue);
      expect(fast.isOver, isTrue);
      expect(300 + fast.guessesLeft * 100, 700); // 4 guesses left

      final perfect = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      perfect.submit('APPLE');
      expect(perfect.isWon, isTrue);
      expect(perfect.guessesLeft, 5);
    });

    test('running out of guesses loses and reveals nothing extra', () {
      final logic = WordleDailyLogic(answer: 'APPLE', maxGuesses: 4);
      for (final w in ['PLUMB', 'CHART', 'STONE', 'BREAD']) {
        expect(logic.submit(w), isNotNull);
      }
      expect(logic.isLost, isTrue);
      expect(logic.isOver, isTrue);
      expect(logic.submit('APPLE'), isNull);
      expect(logic.checkGuess('APPLE'), WordleReject.gameOver);
    });
  });

  group('keyboard state accumulation', () {
    test('keeps the best mark per letter across guesses', () {
      final logic = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      logic.submit('BEACH'); // A present, E present, B/C/H absent
      var state = logic.keyboardState;
      expect(state['A'], WordleMark.present);
      expect(state['E'], WordleMark.present);
      expect(state['B'], WordleMark.absent);
      logic.submit('APPLE');
      state = logic.keyboardState;
      expect(state['A'], WordleMark.correct); // correct beats present
      expect(state['P'], WordleMark.correct);
      expect(state['E'], WordleMark.correct);
      expect(state['B'], WordleMark.absent); // absent sticks
      expect(state.containsKey('Z'), isFalse, reason: 'untouched letters');
    });
  });

  group('serialization round-trip (save/resume)', () {
    test('toMap -> tryFromMap restores answer and every guess', () {
      final logic = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      logic.submit('PLUMB');
      logic.submit('PLEAD');
      final restored = WordleDailyLogic.tryFromMap(logic.toMap());
      expect(restored, isNotNull);
      expect(restored!.answer, 'APPLE');
      expect(restored.maxGuesses, 6);
      expect(
        restored.guesses.map((g) => g.word).toList(),
        ['PLUMB', 'PLEAD'],
      );
      expect(
        restored.guesses.last.marks,
        WordleDailyLogic.feedbackFor('PLEAD', 'APPLE'),
      );
      expect(restored.guessesLeft, 4);
    });

    test('a won run restores as won', () {
      final logic = WordleDailyLogic(answer: 'APPLE', maxGuesses: 6);
      logic.submit('APPLE');
      final restored = WordleDailyLogic.tryFromMap(logic.toMap());
      expect(restored!.isWon, isTrue);
    });

    test('corrupt maps restore null', () {
      expect(WordleDailyLogic.tryFromMap(null), isNull);
      expect(WordleDailyLogic.tryFromMap(<String, dynamic>{}), isNull);
      expect(
        WordleDailyLogic.tryFromMap(<String, dynamic>{
          'answer': 'TOOLONGWORD',
          'maxGuesses': 6,
          'guesses': <String>[],
        }),
        isNull,
      );
      expect(
        WordleDailyLogic.tryFromMap(<String, dynamic>{
          'answer': 'APPLE',
          'maxGuesses': 6,
          'guesses': <String>['BAD'], // not five letters
        }),
        isNull,
      );
      expect(
        WordleDailyLogic.tryFromMap(<String, dynamic>{
          'answer': 'APPLE',
          'maxGuesses': 6,
          'guesses': <String>['PLUMB', 'PLUMB'], // duplicate guess
        }),
        isNull,
      );
    });
  });

  group('real asset bank (assets/mind/words/word_bank.json)', () {
    late Map<String, dynamic> bank;
    final upperAz = RegExp(r'^[A-Z]+$');

    setUpAll(() {
      final file = File('assets/mind/words/word_bank.json');
      expect(file.existsSync(), isTrue,
          reason: 'run tests from the project root');
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      bank = decoded as Map<String, dynamic>;
    });

    List<String> stringList(String key) => [
          for (final w in bank[key]! as List<dynamic>)
            if (w is String) w,
        ];

    test('5-letter answer bank has >= 80 unique uppercase A-Z words', () {
      final answers = stringList('wordle_answers');
      expect(answers.length, greaterThanOrEqualTo(80));
      expect(answers.toSet().length, answers.length,
          reason: 'duplicate answer words');
      for (final word in answers) {
        expect(word.length, 5, reason: word);
        expect(word, matches(upperAz), reason: word);
      }
      final allowed = stringList('wordle_allowed');
      expect(answers.toSet().intersection(allowed.toSet()), isEmpty,
          reason: 'answers and allowed must stay disjoint');
    });

    test('hangman bank covers lengths 4..9 with >= 30 words each', () {
      final tiers = bank['hangman']! as Map<String, dynamic>;
      final words = <String>{
        for (final tier in tiers.values) ...[
          for (final w in tier! as List<dynamic>)
            if (w is String) w,
        ],
      };
      expect(words.length, greaterThanOrEqualTo(180));
      final byLength = <int, int>{};
      for (final word in words) {
        expect(word, matches(upperAz), reason: word);
        byLength[word.length] = (byLength[word.length] ?? 0) + 1;
      }
      for (var len = 4; len <= 9; len++) {
        expect(byLength[len] ?? 0, greaterThanOrEqualTo(30),
            reason: 'length $len needs at least 30 words');
      }
    });

    test('engine extraction helpers parse the real asset', () {
      final answers = WordleDailyLogic.answersFromBank(bank);
      expect(answers.length, greaterThanOrEqualTo(80));
      expect(answers.toSet().length, answers.length);
      final allowed = WordleDailyLogic.allowedFromBank(bank);
      expect(allowed, isNotEmpty);
      // Daily picks from the real asset are always valid answer words.
      for (var i = 0; i < 30; i++) {
        final pick = WordleDailyLogic.daily(
          bank5: answers,
          dayKey: dayKey(DateTime(2026, 1, 1).add(Duration(days: i))),
          definitionId: 'wordle_daily_test',
          maxGuesses: 6,
        );
        expect(answers, contains(pick.answer));
      }
    });
  });
}

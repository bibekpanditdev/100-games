/// Unit tests for the trivia pure-logic class.
///
/// Runs against an inline JSON fixture (no rootBundle) AND validates the
/// real shipped asset `assets/trivia/questions.json` via dart:io.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/catalog/domain/game_definition.dart';
import 'package:game/features/games/trivia/trivia_logic.dart';

/// Tiny hand-written bank used for parse-validation tests.
const String kInlineFixture = '''
{
  "categories": {
    "general": [
      {"q": "Color of the daytime sky", "a": ["Blue", "Red", "Green", "Yellow"], "correct": 0, "difficulty": "easy"},
      {"q": "Two plus two", "a": ["Three", "Four", "Five", "Six"], "correct": 1, "difficulty": "easy"}
    ]
  }
}
''';

/// Builds a synthetic bank. Every question's correct answer text ends with
/// `-answer`, so tests can always identify it after option shuffling.
String buildBank(Map<String, Map<String, int>> shape) {
  final categoryParts = <String>[];
  shape.forEach((category, counts) {
    final entries = <String>[];
    counts.forEach((difficulty, n) {
      for (var i = 0; i < n; i++) {
        final id = '$category-$difficulty-$i';
        entries.add(
          '{"q": "$id", "a": ["$id-answer", "$id-w1", "$id-w2", "$id-w3"], '
          '"correct": 0, "difficulty": "$difficulty"}',
        );
      }
    });
    categoryParts.add('"$category": [${entries.join(', ')}]');
  });
  return '{"categories": {${categoryParts.join(', ')}}}';
}

/// Standard fixture: two categories with deep easy/medium/hard pools.
String bigBank() => buildBank({
      'alpha': {'easy': 12, 'medium': 12, 'hard': 12},
      'beta': {'easy': 12, 'medium': 12, 'hard': 12},
    });

TriviaLogic startLogic(
  String bank, {
  String qset = 'alpha',
  int count = 10,
  Difficulty difficulty = Difficulty.easy,
  int timePerQ = 0,
  int seed = 1,
}) {
  final logic = TriviaLogic(bank, random: Random(seed));
  logic.startSession(
    qset: qset,
    count: count,
    difficulty: difficulty,
    timePerQ: timePerQ,
  );
  return logic;
}

/// Answers [correctCount] questions correctly, then the rest wrongly.
void answerAll(TriviaLogic logic, int correctCount) {
  var correct = 0;
  while (!logic.isFinished) {
    final current = logic.current;
    if (correct < correctCount) {
      logic.submitAnswer(current.correctIndex);
      correct++;
    } else {
      logic.submitAnswer((current.correctIndex + 1) % 4);
    }
    logic.advance();
  }
}

void main() {
  group('bank parsing (inline fixture)', () {
    test('loads categories and questions', () {
      final logic = TriviaLogic(kInlineFixture);
      expect(logic.loadedCategories, ['general']);
      expect(logic.questionCount('general'), 2);
      expect(logic.questionCount('missing'), 0);
    });

    test('rejects entries without exactly 4 options', () {
      const bad = '{"categories": {"x": ['
          '{"q": "Q", "a": ["A", "B", "C"], "correct": 0, "difficulty": "easy"}]}}';
      expect(() => TriviaLogic(bad), throwsFormatException);
    });

    test('rejects out-of-range correct index', () {
      const bad = '{"categories": {"x": ['
          '{"q": "Q", "a": ["A", "B", "C", "D"], "correct": 4, "difficulty": "easy"}]}}';
      expect(() => TriviaLogic(bad), throwsFormatException);
    });

    test('rejects invalid difficulty', () {
      const bad = '{"categories": {"x": ['
          '{"q": "Q", "a": ["A", "B", "C", "D"], "correct": 0, "difficulty": "brutal"}]}}';
      expect(() => TriviaLogic(bad), throwsFormatException);
    });

    test('rejects duplicate prompts within a category', () {
      const bad = '{"categories": {"x": ['
          '{"q": "Q", "a": ["A", "B", "C", "D"], "correct": 0, "difficulty": "easy"}, '
          '{"q": "Q", "a": ["A", "B", "C", "D"], "correct": 1, "difficulty": "hard"}]}}';
      expect(() => TriviaLogic(bad), throwsFormatException);
    });

    test('rejects invalid JSON', () {
      expect(() => TriviaLogic('not json at all'), throwsFormatException);
    });
  });

  group('real asset bank (assets/trivia/questions.json)', () {
    late Map<String, dynamic> categories;

    setUpAll(() {
      final file = File('assets/trivia/questions.json');
      expect(file.existsSync(), isTrue, reason: 'run tests from the project root');
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map<String, dynamic>>());
      categories = (decoded as Map<String, dynamic>)['categories']! as Map<String, dynamic>;
    });

    test('contains exactly the 7 supported categories', () {
      expect(categories.keys.toSet(), kTriviaCategories.toSet());
    });

    test('has at least 36 questions per category (252+ total)', () {
      var total = 0;
      for (final category in kTriviaCategories) {
        final list = categories[category]! as List<dynamic>;
        expect(list.length, greaterThanOrEqualTo(36), reason: category);
        total += list.length;
      }
      expect(total, greaterThanOrEqualTo(252));
    });

    test('every entry is structurally valid and unique within its category', () {
      for (final category in kTriviaCategories) {
        final list = categories[category]! as List<dynamic>;
        final prompts = <String>{};
        final perDifficulty = <String, int>{};
        for (final raw in list) {
          final entry = raw as Map<String, dynamic>;
          final q = entry['q'];
          expect(q is String && q.trim().isNotEmpty, isTrue, reason: '$category: bad q');
          final answers = entry['a'] as List<dynamic>;
          expect(answers.length, 4, reason: '$category: "$q" needs 4 options');
          for (final answer in answers) {
            expect(answer is String && answer.trim().isNotEmpty, isTrue,
                reason: '$category: "$q" empty option');
          }
          expect(answers.toSet().length, 4, reason: '$category: "$q" duplicate options');
          final correct = entry['correct'];
          expect(correct is int && correct >= 0 && correct < 4, isTrue,
              reason: '$category: "$q" bad correct index');
          final difficulty = entry['difficulty'];
          expect(difficulty is String && ['easy', 'medium', 'hard'].contains(difficulty), isTrue,
              reason: '$category: "$q" bad difficulty');
          perDifficulty[difficulty as String] = (perDifficulty[difficulty] ?? 0) + 1;
          expect(prompts.add(q as String), isTrue,
              reason: '$category: duplicate question "$q"');
        }
        for (final difficulty in ['easy', 'medium', 'hard']) {
          expect(perDifficulty[difficulty] ?? 0, greaterThanOrEqualTo(12),
              reason: '$category needs 12+ $difficulty questions');
        }
      }
    });
  });

  group('question selection', () {
    test('returns the requested count with no duplicate questions', () {
      for (var seed = 1; seed <= 20; seed++) {
        final logic = startLogic(bigBank(), count: 20, seed: seed);
        expect(logic.questionTotal, 20);
        final prompts = logic.questions.map((q) => q.prompt).toSet();
        expect(prompts.length, 20, reason: 'duplicates with seed $seed');
      }
    });

    test('easy sessions never pick hard questions while easier ones remain', () {
      // 12 easy + 12 medium = 24 >= count 20, so hard is never needed.
      for (var seed = 1; seed <= 100; seed++) {
        final logic = startLogic(bigBank(), count: 20, difficulty: Difficulty.easy, seed: seed);
        for (final question in logic.questions) {
          expect(question.difficulty, isNot('hard'),
              reason: 'easy session picked hard with seed $seed');
        }
      }
    });

    test('hard sessions never pick easy questions while harder ones remain', () {
      for (var seed = 1; seed <= 100; seed++) {
        final logic = startLogic(bigBank(), count: 20, difficulty: Difficulty.hard, seed: seed);
        for (final question in logic.questions) {
          expect(question.difficulty, isNot('easy'),
              reason: 'hard session picked easy with seed $seed');
        }
      }
    });

    test('distribution follows the weight table', () {
      var hardPicks = 0;
      var mediumPicksOnEasy = 0;
      for (var seed = 1; seed <= 50; seed++) {
        final hard = startLogic(bigBank(), count: 20, difficulty: Difficulty.hard, seed: seed);
        hardPicks += hard.questions.where((q) => q.difficulty == 'hard').length;
        final easy = startLogic(bigBank(), count: 20, difficulty: Difficulty.easy, seed: seed);
        mediumPicksOnEasy += easy.questions.where((q) => q.difficulty == 'medium').length;
      }
      // 1000 picks at 70% hard expected.
      expect(hardPicks, greaterThan(500));
      // 1000 picks at 30% medium expected on easy sessions.
      expect(mediumPicksOnEasy, greaterThan(50));
    });

    test('falls back only when easier pools are exhausted', () {
      final bank = buildBank({'gamma': {'easy': 3, 'medium': 3, 'hard': 8}});
      final logic = startLogic(bank, count: 8, difficulty: Difficulty.easy);
      expect(logic.questionTotal, 8);
      final nonHard = logic.questions.where((q) => q.difficulty != 'hard').length;
      expect(nonHard, 6, reason: 'all 6 easier questions must be used first');
      expect(logic.questions.where((q) => q.difficulty == 'hard').length, 2);
    });

    test('caps the session at the available pool size', () {
      final bank = buildBank({'tiny': {'easy': 3}});
      final logic = startLogic(bank, count: 5);
      expect(logic.questionTotal, 3);
    });

    test('mixed qset samples across all categories', () {
      final prefixes = <String>{};
      for (var seed = 1; seed <= 10; seed++) {
        final logic = startLogic(bigBank(), qset: 'mixed', count: 20, seed: seed);
        prefixes.addAll(logic.questions.map((q) => q.category));
      }
      expect(prefixes, containsAll(['alpha', 'beta']));
    });

    test('unknown qset falls back to mixed instead of an empty session', () {
      final logic = startLogic(bigBank(), qset: 'science', count: 10);
      expect(logic.questionTotal, 10);
    });

    test('same seed produces an identical session', () {
      final a = startLogic(bigBank(), count: 20, seed: 7);
      final b = startLogic(bigBank(), count: 20, seed: 7);
      expect(a.questions.map((q) => q.prompt).toList(), b.questions.map((q) => q.prompt).toList());
      expect(
        a.questions.map((q) => q.correctAnswer).toList(),
        b.questions.map((q) => q.correctAnswer).toList(),
      );
    });
  });

  group('option shuffle', () {
    test('keeps all 4 options and the correct answer findable', () {
      for (var seed = 0; seed < 10; seed++) {
        final logic = startLogic(bigBank(), qset: 'mixed', count: 20, seed: seed);
        for (final question in logic.questions) {
          expect(question.options.length, 4);
          expect(question.options.toSet().length, 4);
          final originals = [
            '${question.prompt}-answer',
            '${question.prompt}-w1',
            '${question.prompt}-w2',
            '${question.prompt}-w3',
          ];
          expect(question.options.toSet(), originals.toSet(),
              reason: 'options changed for "${question.prompt}"');
          expect(question.options[question.correctIndex], '${question.prompt}-answer',
              reason: 'correct answer lost after shuffle');
        }
      }
    });
  });

  group('scoring', () {
    test('correct answer on an untimed question is worth exactly 100', () {
      final logic = startLogic(bigBank(), count: 5, timePerQ: 0);
      final result = logic.submitAnswer(logic.current.correctIndex);
      expect(result.correct, isTrue);
      expect(result.basePoints, 100);
      expect(result.timeBonus, 0);
      expect(result.total, 100);
      expect(logic.score, 100);
    });

    test('time bonus is (timePerQ - secondsTaken) * 5, floored at zero', () {
      final logic = startLogic(bigBank(), count: 5, timePerQ: 20);
      final fast = logic.submitAnswer(logic.current.correctIndex, secondsTaken: 7);
      expect(fast.timeBonus, (20 - 7) * 5);
      expect(fast.total, 165);
      logic.advance();

      final exact = logic.submitAnswer(logic.current.correctIndex, secondsTaken: 20);
      expect(exact.timeBonus, 0);
      expect(exact.total, 100);
      logic.advance();

      final overtime = logic.submitAnswer(logic.current.correctIndex, secondsTaken: 25);
      expect(overtime.timeBonus, 0, reason: 'bonus must never go negative');
      expect(overtime.total, 100);
      expect(logic.score, 100 + 165 + 100);
    });

    test('wrong answers and timeouts score nothing', () {
      final logic = startLogic(bigBank(), count: 5, timePerQ: 20);
      final wrong = logic.submitAnswer((logic.current.correctIndex + 1) % 4, secondsTaken: 3);
      expect(wrong.correct, isFalse);
      expect(wrong.total, 0);
      logic.advance();

      final timedOut = logic.timeUp();
      expect(timedOut.correct, isFalse);
      expect(timedOut.total, 0);
      expect(logic.pickedIndex, -1);
      expect(logic.score, 0);
    });

    test('double submissions after answering are ignored', () {
      final logic = startLogic(bigBank(), count: 5);
      final first = logic.submitAnswer(logic.current.correctIndex);
      final second = logic.submitAnswer((logic.current.correctIndex + 1) % 4);
      expect(first.total, 100);
      expect(second.total, 0);
      expect(logic.score, 100);
    });

    test('advance is a no-op until the question is answered', () {
      final logic = startLogic(bigBank(), count: 5);
      logic.advance();
      expect(logic.currentIndex, 0);
      logic.submitAnswer(logic.current.correctIndex);
      logic.advance();
      logic.advance();
      expect(logic.currentIndex, 1);
    });

    test('tracks streaks, correct count and the perfect flag', () {
      final logic = startLogic(bigBank(), count: 5);
      logic.submitAnswer(logic.current.correctIndex);
      logic.advance();
      logic.submitAnswer(logic.current.correctIndex);
      logic.advance();
      expect(logic.currentStreak, 2);
      logic.submitAnswer((logic.current.correctIndex + 1) % 4);
      logic.advance();
      expect(logic.currentStreak, 0);
      expect(logic.bestStreak, 2);
      logic.submitAnswer(logic.current.correctIndex);
      logic.advance();
      logic.submitAnswer(logic.current.correctIndex);
      logic.advance();
      expect(logic.correctCount, 4);
      expect(logic.isFinished, isTrue);
      expect(logic.perfect, isFalse);
      expect(logic.bestStreak, 2);
    });

    test('perfect flag is set when everything is answered correctly', () {
      final logic = startLogic(bigBank(), count: 5);
      answerAll(logic, 5);
      expect(logic.perfect, isTrue);
      expect(logic.correctCount, 5);
      expect(logic.bestStreak, 5);
      expect(logic.stats, {'correct': 5, 'total': 5, 'perfect': 1});
    });
  });

  group('win threshold (60% of count)', () {
    test('6/10 wins, 5/10 loses', () {
      final won = startLogic(bigBank(), count: 10);
      answerAll(won, 6);
      expect(won.won, isTrue);

      final lost = startLogic(bigBank(), count: 10);
      answerAll(lost, 5);
      expect(lost.won, isFalse);
    });

    test('12/20 wins, 11/20 loses', () {
      final won = startLogic(bigBank(), count: 20);
      answerAll(won, 12);
      expect(won.won, isTrue);

      final lost = startLogic(bigBank(), count: 20);
      answerAll(lost, 11);
      expect(lost.won, isFalse);
    });
  });

  group('50/50 hint', () {
    test('removes exactly two wrong options and keeps the correct one', () {
      final logic = startLogic(bigBank(), count: 5);
      final removed = logic.fiftyFifty();
      expect(removed.length, 2, reason: 'two options must be removed');
      expect(removed.toSet().length, 2);
      for (final index in removed) {
        expect(index, isNot(logic.current.correctIndex));
        expect(logic.isRemoved(index), isTrue);
      }
      final visible = [0, 1, 2, 3].where((i) => !logic.isRemoved(i)).toList();
      expect(visible, contains(logic.current.correctIndex));
      expect(visible.length, 2);
    });

    test('is limited to one hint per question', () {
      final logic = startLogic(bigBank(), count: 5);
      expect(logic.fiftyFifty().length, 2);
      expect(logic.hintAvailable, isFalse);
      expect(logic.fiftyFifty(), isEmpty);
    });

    test('is unavailable after answering and resets on the next question', () {
      final logic = startLogic(bigBank(), count: 5);
      logic.submitAnswer(logic.current.correctIndex);
      expect(logic.hintAvailable, isFalse);
      expect(logic.fiftyFifty(), isEmpty);
      logic.advance();
      expect(logic.hintAvailable, isTrue);
      expect(logic.isRemoved(0), isFalse);
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/mind/math_sprint/math_sprint_logic.dart';

void main() {
  group('question generation', () {
    for (final maxOperand in [12, 25, 99]) {
      test('respects bounds and divides exactly (maxOperand $maxOperand)', () {
        final logic = MathSprintLogic(maxOperand: maxOperand, random: Random(7));
        var sawAdd = false;
        var sawSubtract = false;
        var sawMultiply = false;
        var sawDivide = false;
        for (var i = 0; i < 500; i++) {
          final q = logic.next();
          switch (q.op) {
            case MathOp.add:
              sawAdd = true;
              expect(q.a, inInclusiveRange(1, maxOperand));
              expect(q.b, inInclusiveRange(1, maxOperand));
              expect(q.answer, q.a + q.b);
            case MathOp.subtract:
              sawSubtract = true;
              expect(q.a, inInclusiveRange(1, maxOperand));
              expect(q.b, inInclusiveRange(1, maxOperand));
              expect(q.answer, q.a - q.b);
              expect(q.answer, greaterThanOrEqualTo(0));
            case MathOp.multiply:
              sawMultiply = true;
              final cap = min(12, maxOperand);
              expect(q.a, inInclusiveRange(1, cap));
              expect(q.b, inInclusiveRange(1, cap));
              expect(q.answer, q.a * q.b);
            case MathOp.divide:
              sawDivide = true;
              final cap = min(12, maxOperand);
              expect(q.b, inInclusiveRange(2, cap));
              expect(q.a % q.b, 0, reason: 'division must be exact');
              expect(q.answer, q.a ~/ q.b);
              expect(q.answer, inInclusiveRange(1, cap));
          }
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4, reason: 'options must be unique');
          expect(q.options, contains(q.answer));
          for (final o in q.options) {
            expect(o, greaterThanOrEqualTo(0));
          }
        }
        // With weighted generation over 500 draws every operation shows up.
        expect(sawAdd, isTrue);
        expect(sawSubtract, isTrue);
        expect(sawMultiply, isTrue);
        expect(sawDivide, isTrue);
      });
    }

    test('options never collide with the answer slot', () {
      final logic = MathSprintLogic(maxOperand: 25, random: Random(99));
      for (var i = 0; i < 200; i++) {
        final q = logic.next();
        expect(q.options.where((o) => o == q.answer).length, 1);
      }
    });

    test('deterministic per seed', () {
      final a = MathSprintLogic(random: Random(42));
      final b = MathSprintLogic(random: Random(42));
      for (var i = 0; i < 50; i++) {
        final qa = a.next();
        final qb = b.next();
        expect(qa.prompt, qb.prompt);
        expect(qa.answer, qb.answer);
        expect(qa.options, qb.options);
      }
    });
  });

  group('streak scoring', () {
    test('multiplier caps at x3 and scores 10 × multiplier per hit', () {
      final logic = MathSprintLogic(random: Random(1));
      var expected = 0;
      for (var i = 1; i <= 6; i++) {
        logic.next();
        expect(logic.submit(logic.current.answer), isTrue);
        expected += 10 * (i < 3 ? i : 3);
        expect(logic.score, expected);
        expect(logic.streak, i);
      }
      expect(logic.multiplier, 3);
      expect(logic.bestStreak, 6);
    });

    test('a wrong answer resets the streak and scores nothing', () {
      final logic = MathSprintLogic(random: Random(2));
      logic.next();
      expect(logic.submit(logic.current.answer), isTrue); // x1 → 10
      logic.next();
      expect(logic.submit(logic.current.answer), isTrue); // x2 → 20
      expect(logic.score, 30);
      logic.next();
      expect(logic.submit(logic.current.answer + 1), isFalse);
      expect(logic.streak, 0);
      expect(logic.multiplier, 1);
      expect(logic.score, 30);
      logic.next();
      expect(logic.submit(logic.current.answer), isTrue);
      expect(logic.score, 40); // back to the ×1 tier
      expect(logic.bestStreak, 2);
    });
  });

  group('accuracy and win threshold', () {
    test('accuracy percentage over ten answers', () {
      final logic = MathSprintLogic(random: Random(3));
      expect(logic.accuracyPct, 100);
      for (var i = 0; i < 10; i++) {
        logic.next();
        logic.submit(
          i < 8 ? logic.current.answer : logic.current.answer + 1,
        );
      }
      expect(logic.answered, 10);
      expect(logic.correct, 8);
      expect(logic.accuracyPct, 80);
    });

    test('win threshold is a quarter of the sprint duration', () {
      expect(MathSprintLogic.meetsWinThreshold(0, 90), isFalse);
      expect(MathSprintLogic.meetsWinThreshold(22, 90), isFalse);
      expect(MathSprintLogic.meetsWinThreshold(23, 90), isTrue);
      expect(MathSprintLogic.meetsWinThreshold(15, 60), isTrue);
      expect(MathSprintLogic.meetsWinThreshold(14, 60), isFalse);
    });
  });
}

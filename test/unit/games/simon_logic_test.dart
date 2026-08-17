/// Unit tests for the Simon pure-logic class — sequence growth, input
/// judging (including the length guard), the revive-after-continue state
/// and the round cap.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/mind/simon/simon_logic.dart';

SimonLogic newLogic({int startLength = 3, int roundCap = 15, int seed = 1}) =>
    SimonLogic(startLength: startLength, roundCap: roundCap, random: Random(seed));

void main() {
  group('sequence growth', () {
    test('first round uses startLength, then grows by exactly one', () {
      final logic = newLogic(startLength: 4);
      expect(logic.length, 0);
      logic.beginRound();
      expect(logic.length, 4);
      for (var expected = 5; expected <= 9; expected++) {
        logic.beginRound();
        expect(logic.length, expected);
      }
    });

    test('growing only appends — earlier steps never change', () {
      final logic = newLogic(startLength: 3);
      logic.beginRound();
      final first = logic.sequence;
      for (var i = 0; i < 6; i++) {
        logic.beginRound();
      }
      expect(
        logic.sequence.sublist(0, first.length),
        first,
        reason: 'the prefix must stay stable across rounds',
      );
    });

    test('every pad is a valid 0..3 index', () {
      for (var seed = 1; seed <= 40; seed++) {
        final logic = newLogic(startLength: 3, seed: seed);
        logic.beginRound();
        logic.beginRound();
        for (final pad in logic.sequence) {
          expect(pad, inInclusiveRange(0, SimonLogic.padCount - 1));
        }
      }
    });

    test('same seed replays the same sequence', () {
      final a = newLogic(seed: 42);
      final b = newLogic(seed: 42);
      for (var i = 0; i < 4; i++) {
        a.beginRound();
        b.beginRound();
      }
      expect(a.sequence, b.sequence);
    });
  });

  group('input judging', () {
    test('correct taps advance and complete the round', () {
      final logic = newLogic(startLength: 3, seed: 7);
      logic.beginRound();
      final seq = logic.sequence;
      expect(logic.awaitingInput, isTrue);
      expect(logic.input(seq[0]), SimonInputResult.advance);
      expect(logic.input(seq[1]), SimonInputResult.advance);
      expect(logic.inputIndex, 2);
      expect(logic.input(seq[2]), SimonInputResult.roundComplete);
    });

    test('a wrong pad fails the run', () {
      final logic = newLogic(startLength: 2, seed: 3);
      logic.beginRound();
      final seq = logic.sequence;
      final wrongPad = (seq[0] + 1) % SimonLogic.padCount;
      expect(logic.input(wrongPad), SimonInputResult.wrong);
      expect(logic.failed, isTrue);
      expect(logic.awaitingInput, isFalse);
      // Further taps are ignored while failed.
      expect(logic.input(seq[0]), SimonInputResult.ignored);
    });

    test('length guard: taps after a completed round are ignored', () {
      final logic = newLogic(startLength: 3, seed: 5);
      logic.beginRound();
      for (final pad in logic.sequence) {
        logic.input(pad);
      }
      expect(logic.input(logic.sequence.last), SimonInputResult.ignored,
          reason: 'no new round started — nothing left to accept');
      expect(logic.failed, isFalse);
    });

    test('out-of-range pads and taps before any round are ignored', () {
      final logic = newLogic();
      expect(logic.input(0), SimonInputResult.ignored);
      expect(logic.input(-1), SimonInputResult.ignored);
      expect(logic.input(4), SimonInputResult.ignored);
      expect(logic.failed, isFalse);
    });
  });

  group('revive after continue', () {
    test('revive retries the SAME sequence from the input phase', () {
      final logic = newLogic(startLength: 3, seed: 9);
      logic.beginRound();
      final seq = logic.sequence;
      logic.input(seq[0]);
      expect(logic.input((seq[1] + 1) % 4), SimonInputResult.wrong);
      expect(logic.failed, isTrue);

      logic.revive();
      expect(logic.failed, isFalse);
      expect(logic.awaitingInput, isTrue);
      expect(logic.inputIndex, 0);
      expect(logic.sequence, seq, reason: 'revive must not grow or reshuffle');
      // The retried sequence still completes normally.
      for (final pad in seq) {
        expect(logic.input(pad), isNot(SimonInputResult.wrong));
      }
      expect(logic.inputIndex, seq.length);
    });

    test('a revived run can fail again and revive again', () {
      final logic = newLogic(startLength: 1, seed: 11);
      logic.beginRound();
      expect(
        logic.input((logic.sequence.first + 1) % 4),
        SimonInputResult.wrong,
      );
      logic.revive();
      expect(
        logic.input((logic.sequence.first + 1) % 4),
        SimonInputResult.wrong,
      );
      logic.revive();
      expect(logic.input(logic.sequence.first), SimonInputResult.roundComplete);
    });

    test('serialization round-trip preserves mid-run state', () {
      final logic = newLogic(startLength: 3, seed: 13);
      logic.beginRound();
      logic.input(logic.sequence.first);
      final restored =
          SimonLogic.fromMap(logic.toMap(), random: Random(99));
      expect(restored.sequence, logic.sequence);
      expect(restored.inputIndex, 1);
      expect(restored.failed, isFalse);
      expect(restored.startLength, 3);
      expect(restored.roundCap, 15);
      // The restored run continues judging from where it left off.
      expect(restored.input(restored.sequence[1]), SimonInputResult.advance);
    });

    test('a failed state restores as failed', () {
      final logic = newLogic(startLength: 2, seed: 17);
      logic.beginRound();
      logic.input((logic.sequence.first + 2) % 4);
      final restored = SimonLogic.fromMap(logic.toMap(), random: Random(1));
      expect(restored.failed, isTrue);
      expect(restored.awaitingInput, isFalse);
    });
  });

  group('round cap', () {
    test('the cap round is flagged and beginRound never grows past it', () {
      final logic = newLogic(startLength: 3, roundCap: 6);
      logic.beginRound();
      while (logic.length < 6) {
        logic.beginRound();
      }
      expect(logic.length, 6);
      expect(logic.isCapRound, isTrue);
      logic.beginRound();
      expect(logic.length, 6, reason: 'cap must clamp growth');
      expect(logic.isCapRound, isTrue);
    });

    test('completing the cap round still reports roundComplete', () {
      final logic = newLogic(startLength: 2, roundCap: 3, seed: 21);
      logic.beginRound(); // 2
      logic.beginRound(); // 3 — cap
      expect(logic.isCapRound, isTrue);
      for (final pad in logic.sequence) {
        expect(logic.input(pad), isNot(SimonInputResult.wrong));
      }
      // The final input completed the cap round.
      expect(logic.inputIndex, logic.length);
      expect(logic.failed, isFalse);
    });

    test('below the cap is not the cap round', () {
      final logic = newLogic(startLength: 3, roundCap: 15);
      logic.beginRound();
      expect(logic.isCapRound, isFalse);
    });
  });
}

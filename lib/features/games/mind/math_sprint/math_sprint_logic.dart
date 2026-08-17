/// Math Sprint pure logic — seeded arithmetic question generation with
/// guaranteed-exact division, unique multiple-choice options and
/// streak-multiplied scoring.
///
/// No Flutter imports — deterministic given a seeded [Random] and fully
/// unit-testable standalone.
library;

import 'dart:math';

/// The four sprint operations.
enum MathOp { add, subtract, multiply, divide }

/// One arithmetic question plus its four unique answer options.
class MathQuestion {
  const MathQuestion({
    required this.op,
    required this.a,
    required this.b,
    required this.answer,
    required this.options,
  });

  final MathOp op;

  /// Left operand (the dividend for division).
  final int a;

  /// Right operand (always the divisor for division, >= 2).
  final int b;

  final int answer;

  /// Exactly four unique non-negative values; always contains [answer].
  final List<int> options;

  String get symbol => switch (op) {
        MathOp.add => '+',
        MathOp.subtract => '−',
        MathOp.multiply => '×',
        MathOp.divide => '÷',
      };

  /// Screen-reader friendly prompt, e.g. `7 × 8`.
  String get prompt => '$a $symbol $b';
}

/// Question stream plus streak / accuracy bookkeeping for one sprint run.
class MathSprintLogic {
  MathSprintLogic({this.maxOperand = 12, Random? random})
      : assert(maxOperand >= 2, 'maxOperand must allow real arithmetic'),
        _random = random ?? Random(),
        tableCap = maxOperand < 12 ? maxOperand : 12;

  /// Largest +/− operand.
  final int maxOperand;

  /// Largest operand for the × and ÷ tables (playability cap).
  final int tableCap;

  final Random _random;

  int score = 0;
  int streak = 0;
  int bestStreak = 0;
  int answered = 0;
  int correct = 0;

  MathQuestion? _current;

  /// The question currently on screen (generates the first one lazily).
  MathQuestion get current => _current ??= next();

  /// Streak multiplier: ×1 for the first correct answer in a row, ×2 for
  /// the second, ×3 from the third onwards (cap).
  int get multiplier => streak < 3 ? streak : 3;

  /// Percentage of submitted answers that were correct (100 when idle).
  int get accuracyPct => answered == 0 ? 100 : (correct * 100) ~/ answered;

  /// Generates (and stores) the next question.
  MathQuestion next() {
    final roll = _random.nextInt(100);
    final op = roll < 30
        ? MathOp.add
        : roll < 60
            ? MathOp.subtract
            : roll < 85
                ? MathOp.multiply
                : MathOp.divide;
    late final int a;
    late final int b;
    late final int answer;
    switch (op) {
      case MathOp.add:
        a = _operand(1, maxOperand);
        b = _operand(1, maxOperand);
        answer = a + b;
      case MathOp.subtract:
        var x = _operand(1, maxOperand);
        var y = _operand(1, maxOperand);
        if (y > x) {
          final t = x;
          x = y;
          y = t;
        }
        a = x;
        b = y;
        answer = x - y;
      case MathOp.multiply:
        a = _operand(1, tableCap);
        b = _operand(1, tableCap);
        answer = a * b;
      case MathOp.divide:
        // a = b × answer with every factor inside the capped tables, so
        // division is always exact and never divides by 1.
        b = _operand(2, tableCap);
        answer = _operand(1, tableCap);
        a = b * answer;
    }
    return _current = MathQuestion(
      op: op,
      a: a,
      b: b,
      answer: answer,
      options: _optionsFor(answer),
    );
  }

  int _operand(int min, int max) => min + _random.nextInt(max - min + 1);

  /// Builds four unique options around [answer] (near misses keep the
  /// wrong choices plausible).
  List<int> _optionsFor(int answer) {
    final options = <int>{answer};
    final deltas = <int>[1, 2, 3, 5, 10];
    var guard = 0;
    while (options.length < 4 && guard++ < 256) {
      final delta = deltas[_random.nextInt(deltas.length)];
      var candidate = answer + (_random.nextBool() ? delta : -delta);
      if (candidate < 0) candidate = answer + delta;
      options.add(candidate);
    }
    // Deterministic widening fallback guarantees four unique options even
    // if the random deltas kept colliding.
    var widen = 1;
    while (options.length < 4) {
      options.add(answer + 10 * widen++);
    }
    return options.toList()..shuffle(_random);
  }

  /// Scores a submitted value against the current question. Correct
  /// answers grow the streak (and score); wrong answers reset it.
  bool submit(int value) {
    final q = current;
    answered += 1;
    if (value == q.answer) {
      correct += 1;
      streak += 1;
      if (streak > bestStreak) bestStreak = streak;
      score += 10 * multiplier;
      return true;
    }
    streak = 0;
    return false;
  }

  /// Decent-pace win rule: at least a quarter of the sprint duration
  /// answered (pure integer math, safe for odd durations).
  static bool meetsWinThreshold(int answered, int durationSec) =>
      answered * 4 >= durationSec;
}

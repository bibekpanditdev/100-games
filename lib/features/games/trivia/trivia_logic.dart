/// Pure logic for the trivia engine: offline question-bank parsing,
/// difficulty-weighted question selection, option shuffling, answer judging,
/// scoring and streak tracking.
///
/// This class has no Flutter bindings — the bank arrives as a raw JSON string
/// in the constructor so unit tests can feed inline fixtures without
/// `rootBundle`. The UI layer drives it through [startSession],
/// [submitAnswer] / [timeUp] and [advance].
library;

import 'dart:convert';
import 'dart:math';

import '../../catalog/domain/game_definition.dart';

/// Question categories shipped in `assets/trivia/questions.json`.
const List<String> kTriviaCategories = [
  'general',
  'science',
  'movies',
  'sports',
  'history',
  'geography',
  'technology',
];

/// Every value accepted by the `qset` engine config (categories + `mixed`).
const List<String> kTriviaQsets = [...kTriviaCategories, 'mixed'];

/// Bank difficulty keys, ordered easy -> hard (also the pool indices).
const List<String> _difficultyKeys = ['easy', 'medium', 'hard'];

/// Selection weights per session difficulty for the (easy, medium, hard)
/// pools. A weight of zero means that pool is never rolled.
const Map<Difficulty, List<double>> _poolWeights = {
  Difficulty.easy: [0.7, 0.3, 0.0],
  Difficulty.medium: [0.4, 0.4, 0.2],
  Difficulty.hard: [0.0, 0.3, 0.7],
};

/// Fallback pool order (indices into [_difficultyKeys]) used when the rolled
/// pool runs dry. Guarantees an easy session never touches the hard pool
/// while easier questions remain — and vice versa for hard sessions.
const Map<Difficulty, List<int>> _fallbackOrder = {
  Difficulty.easy: [0, 1, 2],
  Difficulty.medium: [1, 0, 2],
  Difficulty.hard: [2, 1, 0],
};

/// One playable question with its options already shuffled for display.
class TriviaQuestion {
  const TriviaQuestion({
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.difficulty,
  });

  /// Bank category the question came from (or `'mixed'` per entry otherwise).
  final String category;

  final String prompt;

  /// Four answer options in display order.
  final List<String> options;

  /// Index into [options] of the correct answer.
  final int correctIndex;

  /// Bank difficulty: `easy`, `medium` or `hard`.
  final String difficulty;

  /// The correct answer text (survives option shuffling).
  String get correctAnswer => options[correctIndex];
}

/// Result of one submitted answer.
class TriviaAnswerResult {
  const TriviaAnswerResult({
    required this.correct,
    required this.basePoints,
    required this.timeBonus,
  });

  /// Whether the picked option was the correct one.
  final bool correct;

  /// 100 for a correct answer, 0 otherwise.
  final int basePoints;

  /// Timed-question bonus: `max(0, (timePerQ - secondsTaken) * 5)`.
  final int timeBonus;

  /// Total points earned by this answer (never negative).
  int get total => basePoints + timeBonus;
}

/// Internal, validated bank entry before options are shuffled.
class _BankEntry {
  const _BankEntry({
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctIndex,
    required this.difficulty,
  });

  final String category;
  final String prompt;
  final List<String> answers;
  final int correctIndex;
  final String difficulty;
}

/// Parses the offline question bank and runs one quiz session.
///
/// Typical lifecycle:
/// 1. `TriviaLogic(bankJson, random: Random(seed))`
/// 2. [startSession] — selects and shuffles questions.
/// 3. Repeat: [submitAnswer] (or [timeUp]) then [advance].
/// 4. Read [score], [correctCount], [perfect], [won] and [stats].
class TriviaLogic {
  /// [bankJson] is the raw contents of `assets/trivia/questions.json`.
  ///
  /// Throws [FormatException] when the JSON is structurally invalid, so bad
  /// banks fail loudly (and early) instead of during gameplay.
  TriviaLogic(String bankJson, {Random? random}) : _random = random ?? Random() {
    _loadBank(bankJson);
  }

  /// Points awarded per correct answer.
  static const int basePointsPerCorrect = 100;

  /// Points per unused second on timed questions.
  static const int timeBonusPerSecond = 5;

  final Random _random;
  final Map<String, List<_BankEntry>> _bank = {};

  List<TriviaQuestion> _questions = const [];
  int _index = 0;
  int _timePerQ = 0;
  int _score = 0;
  int _correctCount = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  bool _answered = false;
  int _pickedIndex = -1;
  TriviaAnswerResult? _lastResult;
  bool _hintUsed = false;
  final Set<int> _removedOptions = {};

  /// Categories present in the parsed bank.
  List<String> get loadedCategories => _bank.keys.toList(growable: false);

  /// Number of bank questions in [category] (0 when unknown).
  int questionCount(String category) => _bank[category]?.length ?? 0;

  // ---- Session state ------------------------------------------------------

  /// Questions selected for this session, in play order.
  List<TriviaQuestion> get questions => List.unmodifiable(_questions);

  int get questionTotal => _questions.length;

  /// 0-based index of the current question (== [questionTotal] once over).
  int get currentIndex => _index;

  int get answeredCount => _index + (_answered ? 1 : 0);

  bool get isFinished => _index >= _questions.length;

  /// Whether the current question has already been answered.
  bool get isAnswered => _answered;

  /// Seconds allowed per question; 0 means untimed.
  int get timePerQ => _timePerQ;

  TriviaQuestion get current => _questions[_index];

  /// Result of the most recent answer, or null before the first answer.
  TriviaAnswerResult? get lastResult => _lastResult;

  /// Option picked for the current (answered) question; -1 on timeout.
  int get pickedIndex => _pickedIndex;

  int get score => _score;

  int get correctCount => _correctCount;

  int get currentStreak => _currentStreak;

  int get bestStreak => _bestStreak;

  /// True when every question in the session was answered correctly.
  bool get perfect => _questions.isNotEmpty && _correctCount == _questions.length;

  /// Win condition: at least 60% of questions answered correctly.
  bool get won => _questions.isNotEmpty && _correctCount * 5 >= _questions.length * 3;

  /// Engine stats for `GameSessionController.finish`.
  Map<String, int> get stats => {
        'correct': _correctCount,
        'total': _questions.length,
        'perfect': perfect ? 1 : 0,
      };

  // ---- Session setup ------------------------------------------------------

  /// Samples [count] questions from [qset] (a category or `'mixed'`),
  /// weighted by the session [difficulty], and shuffles each question's
  /// options. An unknown [qset] falls back to `'mixed'`.
  void startSession({
    required String qset,
    required int count,
    required Difficulty difficulty,
    int timePerQ = 0,
  }) {
    _timePerQ = timePerQ < 0 ? 0 : timePerQ;
    _resetSessionState();
    _questions = _selectQuestions(qset: qset, count: count, difficulty: difficulty)
        .map(_materialize)
        .toList(growable: false);
  }

  void _resetSessionState() {
    _index = 0;
    _score = 0;
    _correctCount = 0;
    _currentStreak = 0;
    _bestStreak = 0;
    _answered = false;
    _pickedIndex = -1;
    _lastResult = null;
    _hintUsed = false;
    _removedOptions.clear();
  }

  List<_BankEntry> _selectQuestions({
    required String qset,
    required int count,
    required Difficulty difficulty,
  }) {
    final pools = _poolsByDifficulty(qset);
    if (pools.isEmpty || count <= 0) return const [];

    // Mutable copies so picked questions are removed from their pool.
    final remaining = [for (final key in _difficultyKeys) List<_BankEntry>.of(pools[key] ?? const [])];
    final weights = _poolWeights[difficulty]!;
    final fallback = _fallbackOrder[difficulty]!;
    final picked = <_BankEntry>[];

    for (var i = 0; i < count; i++) {
      var slot = _rollSlot(weights);
      if (remaining[slot].isEmpty) {
        // Roll fell on an exhausted pool: walk the preference order.
        slot = fallback.firstWhere(
          (s) => remaining[s].isNotEmpty,
          orElse: () => -1,
        );
      }
      if (slot < 0) break; // Bank exhausted entirely.
      final pool = remaining[slot];
      picked.add(pool.removeAt(_random.nextInt(pool.length)));
    }
    return picked;
  }

  /// Groups the qset's entries into per-difficulty pools.
  Map<String, List<_BankEntry>> _poolsByDifficulty(String qset) {
    final entries = (qset == 'mixed' || !_bank.containsKey(qset))
        ? [for (final list in _bank.values) ...list]
        : _bank[qset]!;
    if (entries.isEmpty) return const {};
    final pools = <String, List<_BankEntry>>{};
    for (final entry in entries) {
      pools.putIfAbsent(entry.difficulty, () => []).add(entry);
    }
    return pools;
  }

  /// Rolls a pool index according to [weights].
  int _rollSlot(List<double> weights) {
    final total = weights[0] + weights[1] + weights[2];
    var roll = _random.nextDouble() * total;
    for (var slot = 0; slot < weights.length; slot++) {
      if (roll < weights[slot]) return slot;
      roll -= weights[slot];
    }
    return weights.length - 1;
  }

  /// Shuffles a bank entry's options and recomputes the correct index.
  TriviaQuestion _materialize(_BankEntry entry) {
    final order = [0, 1, 2, 3]..shuffle(_random);
    final options = [for (final i in order) entry.answers[i]];
    return TriviaQuestion(
      category: entry.category,
      prompt: entry.prompt,
      options: options,
      correctIndex: order.indexOf(entry.correctIndex),
      difficulty: entry.difficulty,
    );
  }

  // ---- Answering, scoring, advancing ---------------------------------------

  /// Judges [optionIndex] against the current question.
  ///
  /// [secondsTaken] is the whole number of seconds the player used; it only
  /// matters for timed questions. Returns the earned points: +100 for a
  /// correct answer plus a time bonus of `max(0, (timePerQ - secondsTaken) * 5)`
  /// — never negative. Ignored (returns a zero result) when the question was
  /// already answered or the session is over.
  TriviaAnswerResult submitAnswer(int optionIndex, {int secondsTaken = 0}) {
    if (isFinished || _answered) {
      return const TriviaAnswerResult(correct: false, basePoints: 0, timeBonus: 0);
    }
    final question = current;
    final correct = optionIndex == question.correctIndex;
    var bonus = 0;
    if (correct && _timePerQ > 0) {
      final secondsLeft = _timePerQ - secondsTaken;
      bonus = max(0, secondsLeft * timeBonusPerSecond);
    }
    _answered = true;
    _pickedIndex = optionIndex;
    if (correct) {
      _correctCount++;
      _currentStreak++;
      _bestStreak = max(_bestStreak, _currentStreak);
      _score += basePointsPerCorrect + bonus;
    } else {
      _currentStreak = 0;
    }
    return _lastResult = TriviaAnswerResult(
      correct: correct,
      basePoints: correct ? basePointsPerCorrect : 0,
      timeBonus: bonus,
    );
  }

  /// Marks the current question as timed out (counts as a wrong answer).
  TriviaAnswerResult timeUp() => submitAnswer(-1, secondsTaken: _timePerQ);

  /// Moves on to the next question. No-op unless the current question was
  /// answered; the session becomes [isFinished] after the last one.
  void advance() {
    if (!_answered || isFinished) return;
    _index++;
    _answered = false;
    _pickedIndex = -1;
    _lastResult = null;
    _hintUsed = false;
    _removedOptions.clear();
  }

  // ---- 50/50 hint -----------------------------------------------------------

  /// Whether a hint can still be applied to the current question.
  bool get hintAvailable => !_answered && !isFinished && !_hintUsed;

  /// Whether [optionIndex] was removed by the active 50/50 hint.
  bool isRemoved(int optionIndex) => _removedOptions.contains(optionIndex);

  /// Removes two wrong options from the current question (one hint per
  /// question maximum). Returns the removed option indices, or an empty list
  /// when no hint is available.
  List<int> fiftyFifty() {
    if (!hintAvailable) return const [];
    _hintUsed = true;
    final wrong = [for (var i = 0; i < current.options.length; i++) if (i != current.correctIndex) i];
    wrong.shuffle(_random);
    final removed = (wrong.take(2).toList()..sort());
    _removedOptions.addAll(removed);
    return removed;
  }

  // ---- Bank parsing ---------------------------------------------------------

  void _loadBank(String bankJson) {
    final dynamic decoded = jsonDecode(bankJson); // FormatException on bad JSON.
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Trivia bank root must be a JSON object.');
    }
    final dynamic categories = decoded['categories'];
    if (categories is! Map<String, dynamic>) {
      throw const FormatException('Trivia bank must contain a "categories" object.');
    }
    categories.forEach((category, rawList) {
      if (rawList is! List) {
        throw FormatException('Category "$category" must contain a list of questions.');
      }
      final entries = <_BankEntry>[];
      final prompts = <String>{};
      for (final raw in rawList) {
        final entry = _parseEntry(category, raw);
        if (!prompts.add(entry.prompt)) {
          throw FormatException('Duplicate question in category "$category": "${entry.prompt}"');
        }
        entries.add(entry);
      }
      _bank[category] = entries;
    });
  }

  _BankEntry _parseEntry(String category, dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw FormatException('Question in "$category" must be a JSON object.');
    }
    final dynamic prompt = raw['q'];
    if (prompt is! String || prompt.trim().isEmpty) {
      throw FormatException('Question in "$category" needs a non-empty "q" string.');
    }
    final dynamic answers = raw['a'];
    if (answers is! List || answers.length != 4) {
      throw FormatException('Question "$prompt" needs exactly 4 options in "a".');
    }
    for (final dynamic answer in answers) {
      if (answer is! String || answer.trim().isEmpty) {
        throw FormatException('Question "$prompt" has an empty option.');
      }
    }
    final dynamic correct = raw['correct'];
    if (correct is! int || correct < 0 || correct >= answers.length) {
      throw FormatException('Question "$prompt" has an out-of-range "correct" index.');
    }
    final dynamic difficulty = raw['difficulty'];
    if (difficulty is! String || !_difficultyKeys.contains(difficulty)) {
      throw FormatException('Question "$prompt" has an invalid "difficulty".');
    }
    return _BankEntry(
      category: category,
      prompt: prompt,
      answers: List<String>.from(answers.cast<String>()),
      correctIndex: correct,
      difficulty: difficulty,
    );
  }
}

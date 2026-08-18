/// Pure logic for the offline daily word game — deterministic daily answer
/// selection, guess validation, duplicate-aware letter feedback, keyboard
/// state accumulation and save/resume serialization.
///
/// NO Flutter imports: plain Dart, testable from inline fixtures.
library;

import '../../../../core/utils/formatters.dart';

/// Per-position feedback for one submitted guess.
enum WordleMark {
  /// Right letter, right spot (green + check marker).
  correct,

  /// Letter exists elsewhere in the answer (amber + dot marker).
  present,

  /// Letter not in the answer (muted + strike marker).
  absent,
}

/// Why a typed guess was rejected.
enum WordleReject {
  /// Not exactly five letters.
  badLength,

  /// Contains characters other than A–Z.
  badLetters,

  /// Not in the offline dictionary.
  notInDictionary,

  /// The run is already over.
  gameOver,
}

/// One submitted guess with its per-letter feedback.
class WordleGuess {
  const WordleGuess({required this.word, required this.marks});

  final String word;
  final List<WordleMark> marks;
}

class WordleDailyLogic {
  WordleDailyLogic._(this.answer, this.maxGuesses, this._valid, this._guesses);

  /// Builds a run around an explicit answer (tests, restores).
  factory WordleDailyLogic({
    required String answer,
    required int maxGuesses,
    Set<String>? validWords,
  }) {
    final clean = answer.trim().toUpperCase();
    final safeAnswer = clean.length == 5 && _onlyLetters(clean)
        ? clean
        : 'QUIET';
    var safeMax = maxGuesses;
    if (safeMax < 4) safeMax = 4;
    if (safeMax > 8) safeMax = 8;
    return WordleDailyLogic._(safeAnswer, safeMax, validWords ?? <String>{},
        <WordleGuess>[]);
  }

  /// The offline daily pick: the same word all day per game variant,
  /// changing at local midnight, no network.
  ///
  /// `answer = bank5[stableHash(dayKey + '|' + definitionId) % bank5.length]`
  factory WordleDailyLogic.daily({
    required List<String> bank5,
    required String dayKey,
    required String definitionId,
    required int maxGuesses,
    Set<String>? extraValid,
  }) {
    final bank = normalizeBank(bank5).toList();
    final pool = bank.isEmpty ? <String>['QUIET'] : bank;
    final answer =
        pool[stableHash('$dayKey|$definitionId') % pool.length];
    final valid = normalizeBank(bank5);
    if (extraValid != null) valid.addAll(extraValid);
    return WordleDailyLogic(
      answer: answer,
      maxGuesses: maxGuesses,
      validWords: valid,
    );
  }

  /// Restores a run saved with [toMap]; null when [map] is invalid.
  static WordleDailyLogic? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final answer = map['answer'];
    final maxGuesses = map['maxGuesses'];
    final guesses = map['guesses'];
    if (answer is! String || maxGuesses is! int || guesses is! List) {
      return null;
    }
    final clean = answer.trim().toUpperCase();
    if (clean.length != 5 || !_onlyLetters(clean)) return null;
    if (maxGuesses < 4 || maxGuesses > 8) return null;
    final logic = WordleDailyLogic._(
      clean,
      maxGuesses,
      <String>{...normalizeBank([clean])},
      <WordleGuess>[],
    );
    for (final raw in guesses) {
      if (raw is! String) return null;
      final guess = raw.trim().toUpperCase();
      if (guess.length != 5 || !_onlyLetters(guess)) return null;
      if (logic._guesses.any((g) => g.word == guess)) return null;
      logic._guesses.add(WordleGuess(
        word: guess,
        marks: feedbackFor(guess, clean),
      ));
    }
    if (logic._guesses.length > maxGuesses) return null;
    return logic;
  }

  /// Uppercases, trims and de-duplicates a bank, keeping only 5-letter
  /// A–Z words.
  static Set<String> normalizeBank(List<String> words) {
    final out = <String>{};
    for (final raw in words) {
      final word = raw.trim().toUpperCase();
      if (word.length == 5 && _onlyLetters(word)) out.add(word);
    }
    return out;
  }

  /// Extracts the 5-letter answer bank from decoded `word_bank.json`.
  static List<String> answersFromBank(Map<String, dynamic> bank) {
    final list = bank['wordle_answers'];
    if (list is! List) return const [];
    return normalizeBank([
      for (final w in list) if (w is String) w,
    ]).toList()
      ..sort();
  }

  /// Extracts the extra allowed-guess bank from decoded `word_bank.json`.
  static List<String> allowedFromBank(Map<String, dynamic> bank) {
    final list = bank['wordle_allowed'];
    if (list is! List) return const [];
    return normalizeBank([
      for (final w in list) if (w is String) w,
    ]).toList()
      ..sort();
  }

  static bool _onlyLetters(String word) {
    for (final c in word.codeUnits) {
      if (c < 65 || c > 90) return false;
    }
    return true;
  }

  final String answer;
  final int maxGuesses;
  final Set<String> _valid;
  final List<WordleGuess> _guesses;

  List<WordleGuess> get guesses => List.unmodifiable(_guesses);

  int get guessCount => _guesses.length;

  int get guessesLeft => maxGuesses - _guesses.length;

  bool get canSubmit => !isOver;

  bool get isWon => _guesses.isNotEmpty && _guesses.last.word == answer;

  bool get isLost => !isWon && _guesses.length >= maxGuesses;

  bool get isOver => isWon || isLost;

  /// Validates a typed guess without consuming it.
  WordleReject? checkGuess(String guess) {
    if (isOver) return WordleReject.gameOver;
    final clean = guess.trim().toUpperCase();
    if (clean.length != 5) return WordleReject.badLength;
    if (!_onlyLetters(clean)) return WordleReject.badLetters;
    if (_valid.isNotEmpty && !_valid.contains(clean)) {
      return WordleReject.notInDictionary;
    }
    return null;
  }

  /// Submits a guess. Returns its feedback, or null when rejected
  /// (see [checkGuess]).
  WordleGuess? submit(String guess) {
    if (checkGuess(guess) != null) return null;
    final clean = guess.trim().toUpperCase();
    final wordleGuess = WordleGuess(
      word: clean,
      marks: feedbackFor(clean, answer),
    );
    _guesses.add(wordleGuess);
    return wordleGuess;
  }

  /// Best accumulated keyboard state per letter:
  /// correct > present > absent.
  Map<String, WordleMark> get keyboardState {
    final out = <String, WordleMark>{};
    for (final guess in _guesses) {
      for (var i = 0; i < 5; i++) {
        final letter = guess.word[i];
        final mark = guess.marks[i];
        final current = out[letter];
        if (current == null || mark.index < current.index) {
          out[letter] = mark;
        }
      }
    }
    return out;
  }

  /// Duplicate-aware Wordle feedback: exact matches first, then "present"
  /// marks consume the remaining unmatched letter count of the answer.
  static List<WordleMark> feedbackFor(String guess, String answer) {
    final marks = List<WordleMark>.filled(5, WordleMark.absent);
    final remaining = <String, int>{};
    for (var i = 0; i < 5; i++) {
      if (guess[i] == answer[i]) {
        marks[i] = WordleMark.correct;
      } else {
        remaining[answer[i]] = (remaining[answer[i]] ?? 0) + 1;
      }
    }
    for (var i = 0; i < 5; i++) {
      if (marks[i] == WordleMark.correct) continue;
      final c = guess[i];
      final left = remaining[c] ?? 0;
      if (left > 0) {
        marks[i] = WordleMark.present;
        remaining[c] = left - 1;
      }
    }
    return marks;
  }

  /// Serialization for [GameSessionController.saveState] / resume.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'answer': answer,
        'maxGuesses': maxGuesses,
        'guesses': [for (final g in _guesses) g.word],
      };
}

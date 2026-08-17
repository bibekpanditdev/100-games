/// Pure logic for the hangman word game — deterministic word selection from
/// the offline bank, letter judging, lives and save/resume serialization.
///
/// NO Flutter imports: everything here is plain Dart so the unit tests can
/// construct it from inline fixtures.
library;

import 'dart:math';

/// Outcome of trying a letter.
enum HangmanGuessResult {
  /// Letter is in the word (newly revealed).
  hit,

  /// Letter is not in the word — one life lost.
  miss,

  /// Already tried earlier in this run.
  alreadyTried,

  /// Game already over (won or lost); input ignored.
  ignored,
}

const List<String> kHangmanVowels = ['A', 'E', 'I', 'O', 'U'];

/// Emergency pool used only when the caller hands us an empty bank so a
/// malformed asset can never crash gameplay.
const List<String> kHangmanFallbackWords = [
  'APPLE', 'BREAD', 'CLOUD', 'DREAM', 'EAGLE', 'FLAME', 'GRAPE', 'HOUSE',
  'ISLAND', 'JUNGLE', 'LEMON', 'MAGIC', 'NOBLE', 'OCEAN', 'PIANO', 'QUEEN',
  'RIVER', 'STONE', 'TIGER', 'WATER', 'SMILE', 'BRAVE', 'CANDY', 'LIGHT',
];

class HangmanLogic {
  HangmanLogic._(this.word, this.maxLives, this._lives, this._tried);

  /// Starts a run around an explicit word (tests, restores).
  factory HangmanLogic({required String word, required int lives, Set<String>? tried}) {
    var clean = word.trim().toUpperCase();
    if (!_isPlayable(clean)) clean = 'PUZZLE';
    var safeLives = lives;
    if (safeLives < 1) safeLives = 1;
    if (safeLives > 12) safeLives = 12;
    final logic = HangmanLogic._(clean, safeLives, safeLives, <String>{});
    if (tried != null) {
      for (final letter in tried) {
        final l = letter.trim().toUpperCase();
        if (l.length == 1 && l.codeUnitAt(0) >= 65 && l.codeUnitAt(0) <= 90) {
          logic._tried.add(l);
        }
      }
    }
    return logic;
  }

  /// Picks a word from [bank] whose length is within [minLen]..[maxLen]
  /// using the injected (seeded) [random] — deterministic per seed.
  factory HangmanLogic.start({
    required List<String> bank,
    required int minLen,
    required int maxLen,
    required int lives,
    required Random random,
  }) {
    final lo = min(minLen, maxLen);
    final hi = max(minLen, maxLen);
    var pool = pickPool(bank, lo, hi);
    if (pool.isEmpty) pool = pickPool(kHangmanFallbackWords, lo, hi);
    if (pool.isEmpty) pool = kHangmanFallbackWords;
    final word = pool[random.nextInt(pool.length)];
    return HangmanLogic(word: word, lives: lives);
  }

  /// Restores a run saved with [toMap]; returns null when [map] is not a
  /// valid hangman state (engines then start a fresh word).
  static HangmanLogic? tryFromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final word = map['word'];
    if (word is! String || !_isPlayable(word.trim().toUpperCase())) return null;
    final lives = map['lives'];
    final maxLives = map['maxLives'];
    final tried = map['tried'];
    if (lives is! int || maxLives is! int) return null;
    if (lives < 0 || maxLives < 1 || maxLives > 12 || lives > maxLives) {
      return null;
    }
    if (tried is! List) return null;
    final logic = HangmanLogic._(
      word.trim().toUpperCase(),
      maxLives,
      lives,
      <String>{},
    );
    for (final letter in tried) {
      if (letter is String) {
        final l = letter.trim().toUpperCase();
        if (l.length == 1 && l.codeUnitAt(0) >= 65 && l.codeUnitAt(0) <= 90) {
          logic._tried.add(l);
        }
      }
    }
    return logic;
  }

  /// Flattens the decoded `word_bank.json` hangman tiers (short / medium /
  /// long) into one sorted, de-duplicated, uppercased list.
  static List<String> wordsFromBank(Map<String, dynamic> bank) {
    final hangman = bank['hangman'];
    if (hangman is! Map) return const [];
    final out = <String>{};
    for (final tier in hangman.values) {
      if (tier is! List) continue;
      for (final word in tier) {
        if (word is String) {
          final clean = word.trim().toUpperCase();
          if (_isPlayable(clean)) out.add(clean);
        }
      }
    }
    return out.toList()..sort();
  }

  /// Words from [bank] whose length is within [minLen]..[maxLen], sorted and
  /// de-duplicated. Falls back to the full bank when the range is empty.
  static List<String> pickPool(List<String> bank, int minLen, int maxLen) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in bank) {
      final word = raw.trim().toUpperCase();
      if (!_isPlayable(word)) continue;
      if (word.length < minLen || word.length > maxLen) continue;
      if (seen.add(word)) out.add(word);
    }
    if (out.isEmpty) {
      for (final raw in bank) {
        final word = raw.trim().toUpperCase();
        if (_isPlayable(word) && seen.add(word)) out.add(word);
      }
    }
    out.sort();
    return out;
  }

  static bool _isPlayable(String word) {
    if (word.length < 2 || word.length > 16) return false;
    for (final c in word.codeUnits) {
      if (c < 65 || c > 90) return false;
    }
    return true;
  }

  final String word;
  final int maxLives;
  int _lives;
  final Set<String> _tried = <String>{};

  /// Lives still remaining (0 = lost).
  int get lives => _lives;

  /// Letters tried so far, in try order.
  List<String> get tried => List.unmodifiable(_tried);

  /// Whether [letter] has already been tried this run.
  bool hasTried(String letter) => _tried.contains(_normalize(letter));

  /// Number of word positions currently revealed.
  int get revealedCount {
    var n = 0;
    for (final c in word.split('')) {
      if (_tried.contains(c)) n++;
    }
    return n;
  }

  /// Distinct vowels (A/E/I/O/U) present in the word AND already found.
  int get vowelsFound =>
      kHangmanVowels.where((v) => _tried.contains(v) && word.contains(v)).length;

  /// Distinct vowels in the word regardless of discovery (HUD target line).
  int get vowelTotal =>
      kHangmanVowels.where((v) => word.contains(v)).length;

  /// The word with undiscovered letters masked as `_` (display + semantics).
  String get maskedWord {
    final sb = StringBuffer();
    for (final c in word.split('')) {
      sb.write(_tried.contains(c) ? c : '_');
    }
    return sb.toString();
  }

  /// Every distinct letter of the word has been revealed.
  bool get isWon => revealedCount == word.length;

  /// No lives left.
  bool get isLost => _lives <= 0;

  bool get isOver => isWon || isLost;

  /// Tries [letter]. See [HangmanGuessResult].
  HangmanGuessResult tryLetter(String letter) {
    if (isOver) return HangmanGuessResult.ignored;
    final l = _normalize(letter);
    if (!_isLetter(l)) return HangmanGuessResult.ignored;
    if (_tried.contains(l)) return HangmanGuessResult.alreadyTried;
    _tried.add(l);
    if (word.contains(l)) return HangmanGuessResult.hit;
    _lives -= 1;
    return HangmanGuessResult.miss;
  }

  /// Serialization for [GameSessionController.saveState] / resume.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'word': word,
        'tried': tried,
        'lives': _lives,
        'maxLives': maxLives,
      };

  static String _normalize(String letter) => letter.trim().toUpperCase();

  static bool _isLetter(String l) =>
      l.length == 1 && l.codeUnitAt(0) >= 65 && l.codeUnitAt(0) <= 90;
}

/// Pure logic for the Simon sequence-recall game — deterministic sequence
/// growth, input judging with a length guard, the revive-after-continue
/// state and the round cap.
///
/// NO Flutter imports: plain Dart, testable with a seeded Random.
library;

import 'dart:math';

/// What a pad tap during the input phase means.
enum SimonInputResult {
  /// Correct pad; more pads remain in this sequence.
  advance,

  /// Correct pad; the whole sequence was recalled.
  roundComplete,

  /// Wrong pad — the run fails (subject to a continue/revive).
  wrong,

  /// Tap outside the input phase, after a failure, or beyond the sequence
  /// length (length guard).
  ignored,
}

class SimonLogic {
  SimonLogic({
    required this.startLength,
    required this.roundCap,
    required Random random,
  })  : _random = random,
        assert(startLength >= 1, 'startLength must be positive'),
        assert(roundCap >= startLength, 'roundCap must allow the start length');

  /// Restores a run saved with [toMap]; null when [map] is invalid.
  factory SimonLogic.fromMap(Map<String, dynamic> map, {required Random random}) {
    final sequence = map['sequence'];
    final inputIndex = map['inputIndex'];
    final failed = map['failed'];
    final startLength = map['startLength'];
    final roundCap = map['roundCap'];
    if (sequence is! List || inputIndex is! int || failed is! bool) {
      return SimonLogic(startLength: 3, roundCap: 15, random: random);
    }
    if (startLength is! int || roundCap is! int) {
      return SimonLogic(startLength: 3, roundCap: 15, random: random);
    }
    final logic = SimonLogic(
      startLength: startLength.clamp(1, 8).toInt(),
      roundCap: roundCap.clamp(startLength, 99).toInt(),
      random: random,
    );
    for (final pad in sequence) {
      if (pad is int && pad >= 0 && pad < 4) logic._sequence.add(pad);
    }
    logic._inputIndex = inputIndex.clamp(0, logic._sequence.length).toInt();
    logic._failed = failed;
    return logic;
  }

  /// Number of pads (classic Simon: four, one per tone/colour/icon).
  static const int padCount = 4;

  /// Sequence length at which the run is won instead of growing further.
  final int roundCap;

  /// Sequence length of the first round.
  final int startLength;

  final Random _random;
  final List<int> _sequence = <int>[];
  int _inputIndex = 0;
  bool _failed = false;

  /// The current sequence (playback order).
  List<int> get sequence => List.unmodifiable(_sequence);

  /// Current sequence length.
  int get length => _sequence.length;

  /// How many pads of the sequence were already correctly re-entered.
  int get inputIndex => _inputIndex;

  /// Whether the player failed the current sequence (awaiting continue).
  bool get failed => _failed;

  /// True while more input is accepted for the current sequence.
  bool get awaitingInput => !_failed && _sequence.isNotEmpty && _inputIndex < _sequence.length;

  /// The sequence reached the cap — completing it wins the run.
  bool get isCapRound => _sequence.length >= roundCap;

  /// Starts (first round: [startLength] pads) or grows the sequence by one
  /// pad and resets the input cursor. Never grows past [roundCap].
  void beginRound() {
    if (_sequence.isEmpty) {
      for (var i = 0; i < startLength; i++) {
        _sequence.add(_random.nextInt(padCount));
      }
    } else if (_sequence.length < roundCap) {
      _sequence.add(_random.nextInt(padCount));
    }
    _inputIndex = 0;
    _failed = false;
  }

  /// Judges one pad tap. See [SimonInputResult].
  SimonInputResult input(int pad) {
    if (pad < 0 || pad >= padCount) return SimonInputResult.ignored;
    if (_failed || _sequence.isEmpty) return SimonInputResult.ignored;
    if (_inputIndex >= _sequence.length) return SimonInputResult.ignored;
    if (_sequence[_inputIndex] != pad) {
      _failed = true;
      return SimonInputResult.wrong;
    }
    _inputIndex += 1;
    return _inputIndex == _sequence.length
        ? SimonInputResult.roundComplete
        : SimonInputResult.advance;
  }

  /// Continue/revive: the player retrys the SAME sequence from the start of
  /// the input phase (no playback, no growth).
  void revive() {
    _failed = false;
    _inputIndex = 0;
  }

  /// Serialization for pause/save snapshots (score lives in the engine).
  Map<String, dynamic> toMap() => <String, dynamic>{
        'sequence': List<int>.of(_sequence),
        'inputIndex': _inputIndex,
        'failed': _failed,
        'startLength': startLength,
        'roundCap': roundCap,
      };
}

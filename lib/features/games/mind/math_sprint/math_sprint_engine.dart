/// Math Sprint engine — a countdown arithmetic sprint: four answer buttons,
/// streak-multiplied scoring and a decent-pace win rule.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'math_sprint_logic.dart';

/// Catalog engine for the `math_sprint` template.
class MathSprintEngine implements GameEngine {
  const MathSprintEngine();

  @override
  String get templateId => 'math_sprint';

  @override
  String get instructions =>
      'Answer as many quick sums as you can before the clock runs out. Build '
      'a streak to triple your points per answer — a wrong answer resets '
      'the streak.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => MathSprintGame(session: session);
}

/// The Math Sprint gameplay screen for one session.
class MathSprintGame extends StatefulWidget {
  const MathSprintGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<MathSprintGame> createState() => _MathSprintGameState();
}

class _MathSprintGameState extends State<MathSprintGame> {
  static const Duration _correctPause = Duration(milliseconds: 300);
  static const Duration _wrongPause = Duration(milliseconds: 800);

  late MathSprintLogic _logic;
  late int _durationSec;
  int _secondsLeft = 0;
  Timer? _timer;
  Timer? _feedbackTimer;
  int? _chosenOption;
  bool? _lastCorrect;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _durationSec = cfg.getInt('durationSec', 90).clamp(30, 300);
    final restored = widget.session.restoredState;
    if (restored != null &&
        restored['secondsLeft'] is num &&
        restored['maxOperand'] is num) {
      _logic = MathSprintLogic(
        maxOperand: _operandCap((restored['maxOperand'] as num).toInt()),
      );
      _logic.score = _toInt(restored['score'], 0);
      _logic.streak = _toInt(restored['streak'], 0);
      _logic.answered = _toInt(restored['answered'], 0);
      _logic.correct = _toInt(restored['correct'], 0);
      _secondsLeft = _toInt(restored['secondsLeft'], _durationSec)
          .clamp(1, _durationSec);
    } else {
      _logic = MathSprintLogic(
        maxOperand: _operandCap(cfg.getInt('maxOperand', 12)),
      );
      _secondsLeft = _durationSec;
      _logic.current; // Generate the first question eagerly.
      _save();
    }
    widget.session.addListener(_onSessionChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pushHud();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _timer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  static int _operandCap(int value) => value.clamp(2, 99);

  static int _toInt(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  bool get _interactive =>
      !_finished &&
      !widget.session.isPaused &&
      !widget.session.isFinished;

  /// Grading lock: while the tick/cross feedback is on screen the buttons
  /// are inert.
  bool get _grading => _chosenOption != null;

  void _onSessionChanged() {
    if (widget.session.isFinished) {
      _timer?.cancel();
      _feedbackTimer?.cancel();
    } else if (widget.session.isPaused) {
      _save();
    }
  }

  void _tick() {
    if (!mounted || !_interactive) return;
    _secondsLeft -= 1;
    if (_secondsLeft <= 0) {
      _secondsLeft = 0;
      _pushHud();
      _finish();
      return;
    }
    if (_secondsLeft % 10 == 0) _save();
    _pushHud();
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.score,
      status: 'Time ${_secondsLeft}s',
      detail: 'Streak x${_logic.multiplier}',
      progress: _durationSec == 0 ? null : 1 - _secondsLeft / _durationSec,
    );
  }

  void _onAnswer(int value) {
    if (!_interactive || _grading) return;
    final wasCorrect = _logic.submit(value);
    AudioService.I.sfx(wasCorrect ? SfxKeys.correct : SfxKeys.wrong);
    setState(() {
      _chosenOption = value;
      _lastCorrect = wasCorrect;
    });
    _pushHud();
    _save();
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(wasCorrect ? _correctPause : _wrongPause, () {
      if (!mounted || _finished) return;
      _logic.next();
      setState(() {
        _chosenOption = null;
        _lastCorrect = null;
      });
    });
  }

  void _finish() {
    if (_finished || widget.session.isFinished) return;
    _finished = true;
    _timer?.cancel();
    _feedbackTimer?.cancel();
    final won =
        MathSprintLogic.meetsWinThreshold(_logic.answered, _durationSec);
    AudioService.I.sfx(won ? SfxKeys.win : SfxKeys.lose);
    widget.session.finish(
      won: won,
      score: _logic.score,
      stats: {
        'answered': _logic.answered,
        'accuracy': _logic.accuracyPct,
        'bestStreak': _logic.bestStreak,
      },
    );
  }

  void _save() {
    widget.session.saveState(<String, dynamic>{
      'maxOperand': _logic.maxOperand,
      'score': _logic.score,
      'streak': _logic.streak,
      'answered': _logic.answered,
      'correct': _logic.correct,
      'secondsLeft': _secondsLeft,
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    final theme = Theme.of(context);
    final q = _logic.current;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Semantics(
                label: 'Question, ${q.prompt}',
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  decoration: BoxDecoration(
                    color: palette.boardA,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          q.prompt,
                          style: theme.textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: GamePalette.contrastOn(palette.boardA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastCorrect == null
                            ? 'Streak x${_logic.multiplier}'
                            : (_lastCorrect!
                                ? 'Correct! +${10 * _logic.multiplier}'
                                : 'Answer: ${q.answer}'),
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: GamePalette.contrastOn(palette.boardA)
                              .withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                for (var row = 0; row < 2; row++)
                  Row(
                    children: [
                      for (var col = 0; col < 2; col++)
                        Expanded(
                          child: _answerButton(
                            q.options[row * 2 + col],
                            q,
                            palette,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerButton(int value, MathQuestion q, GamePalette palette) {
    Color? background;
    IconData? mark;
    if (_lastCorrect != null && value == q.answer) {
      background = kPieceColors[2]; // green
      mark = Icons.check;
    } else if (_chosenOption == value && _lastCorrect == false) {
      background = kPieceColors[5]; // vermillion
      mark = Icons.close;
    }
    final enabled = _interactive && !_grading;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Semantics(
        label: 'Answer $value${enabled ? '' : ', unavailable'}',
        button: true,
        child: SizedBox(
          height: 64, // Well past the 48dp minimum touch target.
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: background,
              foregroundColor: background == null
                  ? null
                  : GamePalette.contrastOn(background),
            ),
            onPressed: enabled ? () => _onAnswer(value) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$value',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (mark != null) ...[
                  const SizedBox(width: 6),
                  Icon(mark, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

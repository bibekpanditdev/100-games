/// The trivia quiz flow: loads the offline bank, runs one session against a
/// [GameSessionController] (HUD, pause, hints, finish) and renders the
/// question card, answer buttons, timer bar and between-question feedback.
///
/// All state lives in this [State] object, so the shell restarts a run by
/// rebuilding the widget with a fresh `Key`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game_player/game_contracts.dart';
import '../../../core/services/audio_service.dart';
import 'trivia_answer_button.dart';
import 'trivia_logic.dart';
import 'trivia_widgets.dart';

/// One gameplay run of the trivia template.
class TriviaQuizScreen extends StatefulWidget {
  const TriviaQuizScreen({super.key, required this.session});

  final GameSessionController session;

  @override
  State<TriviaQuizScreen> createState() => _TriviaQuizScreenState();
}

class _TriviaQuizScreenState extends State<TriviaQuizScreen> {
  static const String _bankAssetPath = 'assets/trivia/questions.json';
  static const int _tickMs = 100;
  static const int _feedbackMs = 600;

  TriviaLogic? _logic;
  String? _error;
  Timer? _ticker;
  int _elapsedMs = 0;
  int _feedbackElapsedMs = 0;
  bool _timedOut = false;
  bool _wasHalted = false;

  GameSessionController get session => widget.session;

  // ---- Lifecycle -----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _wasHalted = session.isPaused || session.isFinished;
    session.addListener(_handleSessionChanged);
    session.onHintGranted = _applyHint;
    _loadBank();
  }

  @override
  void dispose() {
    session.removeListener(_handleSessionChanged);
    if (identical(session.onHintGranted, _applyHint)) {
      session.onHintGranted = null;
    }
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }

  Future<void> _loadBank() async {
    try {
      final json = await rootBundle
          .loadString(_bankAssetPath)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final logic = TriviaLogic(json);
      setState(() {
        _logic = logic;
      });
      _startSession(logic);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the question bank.';
      });
    }
  }

  void _startSession(TriviaLogic logic) {
    final config = session.config;
    logic.startSession(
      qset: _sanitizeQset(config.getString('qset', 'mixed')),
      count: config.getInt('count', 10) >= 20 ? 20 : 10,
      difficulty: session.definition.difficulty,
      timePerQ: _sanitizeTime(config.getInt('timePerQ', 20)),
    );
    _pushHud();
    if (logic.isFinished) {
      _complete();
    } else {
      _beginQuestion();
    }
  }

  static String _sanitizeQset(String value) =>
      kTriviaQsets.contains(value) ? value : 'mixed';

  static int _sanitizeTime(int value) {
    if (value <= 0) return 0;
    return value <= 15 ? 12 : 20;
  }

  // ---- Ticking (timer + feedback) -------------------------------------------

  void _beginQuestion() {
    _elapsedMs = 0;
    _feedbackElapsedMs = 0;
    _timedOut = false;
    _ensureTicker();
  }

  void _ensureTicker() {
    if (session.isPaused || session.isFinished || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: _tickMs), _onTick);
  }

  void _onTick(Timer timer) {
    final logic = _logic;
    if (logic == null || session.isPaused || session.isFinished) return;
    if (logic.isAnswered) {
      _feedbackElapsedMs += _tickMs;
      if (_feedbackElapsedMs >= _feedbackMs) {
        _advance();
      } else if (mounted) {
        setState(() {});
      }
    } else if (logic.timePerQ > 0) {
      _elapsedMs += _tickMs;
      if (!mounted) return;
      if (_elapsedMs % 1000 == 0) {
        final secondsLeft = logic.timePerQ - _elapsedMs ~/ 1000;
        if (secondsLeft > 0 && secondsLeft <= 5) {
          AudioService.I.sfx(SfxKeys.tick);
        }
      }
      if (_elapsedMs >= logic.timePerQ * 1000) {
        _timedOut = true;
        logic.timeUp();
        _pushHud();
      }
      setState(() {});
    }
  }

  void _advance() {
    final logic = _logic;
    if (logic == null) return;
    logic.advance();
    if (logic.isFinished) {
      _complete();
    } else {
      _beginQuestion();
      _pushHud();
    }
  }

  void _complete() {
    _ticker?.cancel();
    _ticker = null;
    final logic = _logic;
    if (logic == null || session.isFinished) return;
    if (logic.questionTotal > 0 && logic.correctCount == logic.questionTotal) {
      AudioService.I.sfx(SfxKeys.win);
    }
    session.finish(won: logic.won, score: logic.score, stats: logic.stats);
  }

  void _handleSessionChanged() {
    if (!mounted) return;
    final halted = session.isPaused || session.isFinished;
    if (halted) {
      _ticker?.cancel();
      _ticker = null;
    } else if (_wasHalted) {
      _ensureTicker();
    }
    _wasHalted = halted;
    if (session.isFinished) return;
    setState(() {});
  }

  // ---- Player actions --------------------------------------------------------

  void _answer(int optionIndex) {
    final logic = _logic;
    if (logic == null || logic.isAnswered || logic.isFinished) return;
    final seconds = logic.timePerQ > 0 ? _elapsedMs ~/ 1000 : 0;
    _timedOut = false;
    _feedbackElapsedMs = 0;
    logic.submitAnswer(optionIndex, secondsTaken: seconds);
    final result = logic.lastResult;
    if (result != null) {
      AudioService.I.sfx(result.correct ? SfxKeys.correct : SfxKeys.wrong);
    }
    setState(() {});
    _pushHud();
  }

  Future<void> _requestHint() async {
    final granted = await session.requestHint();
    if (granted && mounted) _applyHint(); // Also fires via onHintGranted.
  }

  /// Applies the 50/50 (idempotent — guarded by `hintAvailable`).
  void _applyHint() {
    final logic = _logic;
    if (logic == null || !logic.hintAvailable) return;
    logic.fiftyFifty();
    AudioService.I.sfx(SfxKeys.hint);
    if (mounted) setState(() {});
  }

  void _pushHud() {
    final logic = _logic;
    if (logic == null) return;
    final total = logic.questionTotal;
    final current = math.min(logic.currentIndex + 1, total);
    session.updateHud(
      score: logic.score,
      status: 'Q $current/$total',
      detail: 'Correct ${logic.correctCount}',
      progress: total == 0 ? 1 : logic.answeredCount / total,
    );
  }

  // ---- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return TriviaMessageView(icon: Icons.error_outline, message: _error!);
    }
    final logic = _logic;
    if (logic == null) {
      return const TriviaMessageView(
        icon: Icons.hourglass_top,
        message: 'Loading questions...',
      );
    }
    if (logic.isFinished) {
      return const TriviaMessageView(
        icon: Icons.emoji_events,
        message: 'Quiz complete!',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final pad = wide ? 32.0 : 16.0;
        final gap = wide ? 20.0 : 12.0;
        final optionWidth = wide ? (constraints.maxWidth - 2 * pad - gap) / 2 : double.infinity;
        return Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              TriviaProgressHeader(
                current: logic.currentIndex + 1,
                total: logic.questionTotal,
                streak: logic.currentStreak,
                palette: session.palette,
              ),
              if (logic.timePerQ > 0) ...[
                SizedBox(height: gap / 2),
                TriviaTimerBar(
                  secondsLeft: _secondsLeft(logic),
                  totalSeconds: logic.timePerQ,
                  palette: session.palette,
                ),
              ],
              SizedBox(height: gap),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: TriviaQuestionCard(
                      question: logic.current,
                      palette: session.palette,
                      compact: !wide,
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < logic.current.options.length; i++)
                    if (!logic.isRemoved(i))
                      SizedBox(
                        width: optionWidth,
                        child: TriviaAnswerButton(
                          optionIndex: i,
                          label: logic.current.options[i],
                          state: _stateFor(logic, i),
                          palette: session.palette,
                          onTap: () => _answer(i),
                        ),
                      ),
                ],
              ),
              SizedBox(height: gap),
              SizedBox(
                height: TriviaAnswerButton.minHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: logic.isAnswered && logic.lastResult != null
                      ? TriviaFeedbackView(
                          key: ValueKey('feedback-${logic.currentIndex}'),
                          result: logic.lastResult!,
                          timedOut: _timedOut,
                        )
                      : TriviaHintButton(
                          key: ValueKey('hint-${logic.currentIndex}'),
                          available: logic.hintAvailable,
                          onPressed: _requestHint,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _secondsLeft(TriviaLogic logic) {
    if (logic.isAnswered) {
      // Freeze the bar at the moment the answer locked in.
      final frozen = logic.timePerQ * 1000 - _elapsedMs;
      return frozen.clamp(0, logic.timePerQ * 1000) ~/ 1000;
    }
    return math.max(0, logic.timePerQ - _elapsedMs ~/ 1000);
  }

  TriviaOptionState _stateFor(TriviaLogic logic, int optionIndex) {
    if (!logic.isAnswered) return TriviaOptionState.neutral;
    if (optionIndex == logic.current.correctIndex) {
      return TriviaOptionState.correct;
    }
    final result = logic.lastResult;
    final pickedWrong = result != null && !result.correct && logic.pickedIndex == optionIndex;
    return pickedWrong ? TriviaOptionState.wrong : TriviaOptionState.dimmed;
  }
}

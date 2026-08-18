/// Pattern recall engine — a set of cells flashes, then the player taps the
/// cells they remember (order irrelevant). Every three rounds one more cell
/// is added; pausing freezes both the flash and the recall timers.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../core/utils/formatters.dart';
import 'pattern_recall_logic.dart';

class PatternRecallEngine implements GameEngine {
  const PatternRecallEngine();

  @override
  String get templateId => 'pattern_recall';

  @override
  String get instructions =>
      'Watch which cells light up, then tap them all back — the order does '
      'not matter, but one wrong tap ends the round. Every few rounds one '
      'more cell joins the pattern.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) =>
      PatternRecallGame(session: session);
}

enum _PrPhase { idle, flashing, recall, revealSuccess, revealMiss }

class PatternRecallGame extends StatefulWidget {
  const PatternRecallGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<PatternRecallGame> createState() => _PatternRecallGameState();
}

class _PatternRecallGameState extends State<PatternRecallGame> {
  static const int _flashMs = 1200;
  static const int _revealSuccessMs = 700;
  static const int _revealMissMs = 1100;
  static const Duration _tick = Duration(milliseconds: 40);

  late PatternRecallLogic _logic;
  _PrPhase _phase = _PrPhase.idle;
  int _remainingMs = 0;
  int _windowMs = 0;
  int _score = 0;
  int? _wrongCell;
  Timer? _timer;

  GameSessionController get _session => widget.session;

  @override
  void initState() {
    super.initState();
    final cfg = _session.config;
    final grid = cfg.getInt('grid', 4).clamp(3, 6).toInt();
    _logic = PatternRecallLogic(
      grid: grid,
      baseCells: cfg.getInt('cells', 4).clamp(2, grid * grid ~/ 2).toInt(),
      totalRounds: cfg.getInt('rounds', 8).clamp(5, 20).toInt(),
      random: Random(stableHash(_session.definition.id)),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRound());
    _timer = Timer.periodic(_tick, (_) => _onTick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startRound() {
    if (_session.isFinished) return;
    _logic.startRound();
    _windowMs = _recallWindow();
    _remainingMs = _flashMs;
    _wrongCell = null;
    _phase = _PrPhase.flashing;
    _pushHud();
    if (mounted) setState(() {});
  }

  int _recallWindow() => 8000 + _logic.cellCount * 1000;

  /// The single game clock — frozen while paused, dead once finished.
  void _onTick() {
    if (!mounted || _session.isPaused || _session.isFinished) return;
    switch (_phase) {
      case _PrPhase.idle:
        return;
      case _PrPhase.flashing:
        _remainingMs -= _tick.inMilliseconds;
        if (_remainingMs <= 0) {
          _phase = _PrPhase.recall;
          _remainingMs = _windowMs;
          AudioService.I.sfx(SfxKeys.flip);
          _pushHud();
        }
      case _PrPhase.recall:
        _remainingMs -= _tick.inMilliseconds;
        if (_remainingMs <= 0) {
          _logic.timeoutRound();
          _enterMissReveal(wrongCell: null);
        }
      case _PrPhase.revealSuccess:
        _remainingMs -= _tick.inMilliseconds;
        if (_remainingMs <= 0) _afterRound();
      case _PrPhase.revealMiss:
        _remainingMs -= _tick.inMilliseconds;
        if (_remainingMs <= 0) _afterRound();
    }
    if (mounted) setState(() {});
  }

  void _onCellTap(int cell) {
    if (_phase != _PrPhase.recall ||
        _session.isPaused ||
        _session.isFinished) {
      return;
    }
    switch (_logic.tap(cell)) {
      case PatternTapResult.correct:
        AudioService.I.sfx(SfxKeys.place);
        HapticFeedback.selectionClick();
      case PatternTapResult.roundComplete:
        final elapsed = _windowMs - max(0, _remainingMs).toInt();
        _score += _logic.roundScore(elapsedMs: elapsed, windowMs: _windowMs);
        AudioService.I.sfx(SfxKeys.correct);
        _phase = _PrPhase.revealSuccess;
        _remainingMs = _revealSuccessMs;
        _pushHud();
      case PatternTapResult.wrong:
        AudioService.I.sfx(SfxKeys.wrong);
        HapticFeedback.lightImpact();
        _enterMissReveal(wrongCell: cell);
      case PatternTapResult.ignored:
        return;
    }
    setState(() {});
  }

  void _enterMissReveal({int? wrongCell}) {
    _wrongCell = wrongCell;
    _phase = _PrPhase.revealMiss;
    _remainingMs = _revealMissMs;
    _pushHud();
  }

  void _afterRound() {
    if (_logic.isDone) {
      _timer?.cancel();
      _session.updateHud(score: _score);
      AudioService.I.sfx(_logic.won ? SfxKeys.win : SfxKeys.lose);
      _session.finish(
        won: _logic.won,
        score: _score,
        stats: {'rounds': _logic.roundsCompleted},
      );
      return;
    }
    _startRound();
  }

  void _pushHud() {
    _session.updateHud(
      score: _score,
      status: 'Round ${min(_logic.roundsPlayed, _logic.totalRounds)}'
          '/${_logic.totalRounds}',
      detail: '${_logic.cellCount} cells',
      progress: _logic.roundsPlayed / _logic.totalRounds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _session.palette;
    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.biggest.shortestSide,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Semantics(
                        label: 'Pattern grid, ${_logic.grid} by '
                            '${_logic.grid}. $_phaseDescription',
                        child: _board(palette),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _timeBar(palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _phaseDescription => switch (_phase) {
        _PrPhase.flashing => 'Memorize the lit cells',
        _PrPhase.recall => 'Tap the cells you remember',
        _PrPhase.revealSuccess => 'Round complete',
        _PrPhase.revealMiss => 'Missed — shown the pattern',
        _PrPhase.idle => 'Get ready',
      };

  Widget _board(GamePalette palette) {
    final grid = _logic.grid;
    return Column(
      children: [
        for (var r = 0; r < grid; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < grid; c++) Expanded(child: _cell(r, c, palette)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int r, int c, GamePalette palette) {
    final index = r * _logic.grid + c;
    final isFlash = _logic.flashCells.contains(index);
    final isRecalled = _logic.recalledCells.contains(index);
    final isWrong = _wrongCell == index;
    var filled = false;
    Color color = palette.boardB;
    IconData? icon;
    Color? iconColor;
    switch (_phase) {
      case _PrPhase.flashing:
        filled = isFlash;
        if (isFlash) color = palette.accent;
      case _PrPhase.recall:
        filled = isRecalled;
        if (isRecalled) color = palette.accent;
      case _PrPhase.revealSuccess:
        filled = isFlash;
        if (isFlash) color = kPieceColors[2];
      case _PrPhase.revealMiss:
        if (isWrong) {
          filled = true;
          color = const Color(0xFFB71C1C);
          icon = Icons.close;
        } else if (isFlash) {
          filled = true;
          color = kPieceColors[1];
        }
      case _PrPhase.idle:
        break;
    }
    final fg = GamePalette.contrastOn(color);
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        button: _phase == _PrPhase.recall,
        label: 'Cell row ${r + 1} column ${c + 1}'
            '${isRecalled ? ', recalled' : ''}',
        child: GestureDetector(
          onTap: _phase == _PrPhase.recall ? () => _onCellTap(index) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: filled ? color : palette.boardB,
              borderRadius: BorderRadius.circular(8),
              border: filled
                  ? null
                  : Border.all(
                      color: GamePalette.contrastOn(palette.boardB)
                          .withValues(alpha: 0.15),
                    ),
            ),
            child: icon == null
                ? null
                : Icon(icon, color: iconColor ?? fg, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _timeBar(GamePalette palette) {
    final double value;
    switch (_phase) {
      case _PrPhase.flashing:
        value = 1.0;
      case _PrPhase.recall:
        value = (_remainingMs / _windowMs).clamp(0.0, 1.0);
      default:
        value = 0.0;
    }
    return Semantics(
      label: _phaseDescription,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_phaseDescription,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              width: double.infinity,
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: palette.accent,
                backgroundColor: palette.boardB,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

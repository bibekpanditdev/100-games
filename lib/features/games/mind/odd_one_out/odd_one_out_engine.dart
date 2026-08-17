/// Odd-one-out engine — find the single tile whose shape (and colour)
/// differs from the group before the shrinking time window closes. Wrong
/// taps cost points and shake; the board is never colour-only.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../core/utils/formatters.dart';
import 'odd_one_out_logic.dart';
import 'shapes.dart';

class OddOneOutEngine implements GameEngine {
  const OddOneOutEngine();

  @override
  String get templateId => 'odd_one_out';

  @override
  String get instructions =>
      'One tile does not belong: its shape and colour both differ from the '
      'rest. Tap it before the timer bar empties — it gets shorter every '
      'round, and wrong taps cost points.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => OddOneOutGame(session: session);
}

enum _OooPhase { idle, playing, revealFound, revealMiss }

class OddOneOutGame extends StatefulWidget {
  const OddOneOutGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<OddOneOutGame> createState() => _OddOneOutGameState();
}

class _OddOneOutGameState extends State<OddOneOutGame> {
  static const Duration _tick = Duration(milliseconds: 40);
  static const int _revealFoundMs = 450;
  static const int _revealMissMs = 750;
  static const int _shakeMsTotal = 320;

  late OddOneOutLogic _logic;
  _OooPhase _phase = _OooPhase.idle;
  int _windowMs = 0;
  int _remainingMs = 0;
  int _revealMs = 0;
  int _score = 0;
  int? _shakeTile;
  int _shakeMs = 0;
  Timer? _timer;

  GameSessionController get _session => widget.session;

  @override
  void initState() {
    super.initState();
    final cfg = _session.config;
    final items = cfg.getInt('items', 6).clamp(4, 16).toInt();
    _logic = OddOneOutLogic(
      items: items,
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
    _windowMs = OddOneOutLogic.windowMsForRound(_logic.round);
    _remainingMs = _windowMs;
    _phase = _OooPhase.playing;
    _shakeTile = null;
    _pushHud();
    if (mounted) setState(() {});
  }

  void _onTick() {
    if (!mounted || _session.isPaused || _session.isFinished) return;
    if (_shakeMs > 0) _shakeMs -= _tick.inMilliseconds;
    switch (_phase) {
      case _OooPhase.idle:
        return;
      case _OooPhase.playing:
        _remainingMs -= _tick.inMilliseconds;
        if (_remainingMs <= 0) {
          _logic.timeoutRound();
          _phase = _OooPhase.revealMiss;
          _revealMs = _revealMissMs;
          AudioService.I.sfx(SfxKeys.mismatch);
          _pushHud();
        }
      case _OooPhase.revealFound:
        _revealMs -= _tick.inMilliseconds;
        if (_revealMs <= 0) _afterRound();
      case _OooPhase.revealMiss:
        _revealMs -= _tick.inMilliseconds;
        if (_revealMs <= 0) _afterRound();
    }
    if (mounted) setState(() {});
  }

  void _onTileTap(int index) {
    if (_phase != _OooPhase.playing ||
        _session.isPaused ||
        _session.isFinished) {
      return;
    }
    switch (_logic.tap(index)) {
      case OddTapResult.found:
        _score = OddOneOutLogic.scoreAfter(score: _score, found: true);
        AudioService.I.sfx(SfxKeys.correct);
        HapticFeedback.selectionClick();
        _phase = _OooPhase.revealFound;
        _revealMs = _revealFoundMs;
        _pushHud();
      case OddTapResult.wrong:
        _score = OddOneOutLogic.scoreAfter(score: _score, found: false);
        AudioService.I.sfx(SfxKeys.wrong);
        HapticFeedback.lightImpact();
        _shakeTile = index;
        _shakeMs = _shakeMsTotal;
        _pushHud();
      case OddTapResult.ignored:
        return;
    }
    setState(() {});
  }

  void _afterRound() {
    if (_logic.isDone) {
      _timer?.cancel();
      _session.updateHud(score: _score);
      AudioService.I.sfx(_logic.won ? SfxKeys.win : SfxKeys.lose);
      _session.finish(
        won: _logic.won,
        score: _score,
        stats: {'found': _logic.found},
      );
      return;
    }
    _startRound();
  }

  void _pushHud() {
    _session.updateHud(
      score: _score,
      status: 'Round ${min(_logic.round, _logic.totalRounds)}'
          '/${_logic.totalRounds}',
      detail: 'Found ${_logic.found}',
      progress: _logic.round / _logic.totalRounds,
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
                      aspectRatio: _aspectFor(_logic.items),
                      child: Semantics(
                        label: 'Odd one out board, ${_logic.items} tiles. '
                            'Find the tile with a different shape and colour.',
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

  double _aspectFor(int items) {
    final cols = _columnsFor(items);
    final rows = (items / cols).ceil();
    return cols / rows;
  }

  int _columnsFor(int items) {
    if (items == 4) return 2;
    if (items == 6 || items == 9) return 3;
    if (items == 12) return 4;
    return max(2, sqrt(items).ceil());
  }

  Widget _board(GamePalette palette) {
    final cols = _columnsFor(_logic.items);
    return Column(
      children: [
        for (var r = 0; r * cols < _logic.items; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < cols; c++)
                  Expanded(
                    child: r * cols + c < _logic.items
                        ? _tile(r * cols + c, palette)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tile(int index, GamePalette palette) {
    final tiles = _logic.tiles;
    if (index >= tiles.length) return const SizedBox.shrink();
    final tile = tiles[index];
    final shape = MindShape.values[tile.shape % MindShape.values.length];
    final color = kPieceColors[tile.color % kPieceColors.length];
    final revealing =
        _phase == _OooPhase.revealFound || _phase == _OooPhase.revealMiss;
    final isOdd = revealing && index == _logic.oddIndex;
    final shakeNow = _shakeTile == index && _shakeMs > 0;
    final dx = shakeNow ? sin(_shakeMs * 0.09) * 6 : 0.0;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Semantics(
        button: _phase == _OooPhase.playing,
        label: '${shape.semanticLabel}'
            '${isOdd ? ', the odd one' : ''}',
        child: GestureDetector(
          onTap: _phase == _OooPhase.playing ? () => _onTileTap(index) : null,
          child: Transform.translate(
            offset: Offset(dx, 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: palette.boardA,
                borderRadius: BorderRadius.circular(10),
                border: isOdd
                    ? Border.all(color: palette.accent, width: 4)
                    : Border.all(
                        color:
                            GamePalette.contrastOn(palette.boardA).withOpacity(0.1),
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: MindShapeView(shape: shape, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeBar(GamePalette palette) {
    final double value = _phase == _OooPhase.playing
        ? (_remainingMs / _windowMs).clamp(0.0, 1.0)
        : 1.0;
    final label = switch (_phase) {
      _OooPhase.playing => 'Find the odd one',
      _OooPhase.revealFound => 'Found it!',
      _OooPhase.revealMiss => 'Missed — there it was',
      _OooPhase.idle => 'Get ready',
    };
    return Semantics(
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
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

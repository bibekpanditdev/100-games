/// Tap-reflex engine: a target flashes somewhere on the board for a short
/// window — tap it fast for 100 points plus a speed bonus. Misses cost a
/// life; clear every round to win.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'tap_reflex_logic.dart';

/// Catalog engine for the `tap_reflex` template.
class TapReflexEngine implements GameEngine {
  const TapReflexEngine();

  @override
  String get templateId => 'tap_reflex';

  @override
  String get instructions =>
      'Tap the target the moment it appears — the faster you react, the '
      'bigger the bonus. Each round you miss costs one of your three '
      'lives.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) =>
      TapReflexGame(session: session);
}

/// The tap-reflex gameplay screen for one session.
class TapReflexGame extends StatefulWidget {
  const TapReflexGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<TapReflexGame> createState() => _TapReflexGameState();
}

class _TapReflexGameState extends State<TapReflexGame> {
  static const int _tickMs = 33;
  static const double _targetSize = 72;

  late final TapReflexLogic _logic;

  Timer? _timer;
  int _hudScore = -1;
  int _hudRound = -1;
  int _hudLives = -1;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final rounds = _bounded(cfg.getInt('rounds', 10), 5, 30);
    final windowMs = _bounded(cfg.getInt('windowMs', 1000), 400, 3000);
    _logic = TapReflexLogic(
      rounds: rounds,
      windowMs: windowMs,
      random: Random(),
    );
    widget.session.addListener(_onSessionChanged);
    _pushHud();
    _ensureTicker();
  }

  @override
  void dispose() {
    _cancelTicker();
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  // Timer ---------------------------------------------------------------------

  void _onSessionChanged() {
    if (widget.session.isFinished || widget.session.isPaused) {
      _cancelTicker();
    } else {
      _ensureTicker();
    }
    if (mounted) setState(() {});
  }

  void _ensureTicker() {
    if (_timer != null || !_interactive) return;
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), _onTick);
  }

  void _cancelTicker() {
    _timer?.cancel();
    _timer = null;
  }

  void _onTick() {
    if (!_interactive) return;
    final livesBefore = _logic.lives;
    _logic.advance(_tickMs);
    if (_logic.lives < livesBefore) {
      AudioService.I.sfx(SfxKeys.wrong);
      if (_logic.lives <= 0) AudioService.I.sfx(SfxKeys.die);
    }
    _pushHud();
    if (_logic.isOver) {
      _cancelTicker();
      widget.session.finish(
        won: _logic.won,
        stats: {'avgMs': _logic.avgReactionMs},
      );
      return;
    }
    if (mounted) setState(() {});
  }

  void _pushHud() {
    final round =
        (_logic.roundsPlayed + 1).clamp(1, _logic.rounds).toInt();
    if (_logic.score == _hudScore &&
        round == _hudRound &&
        _logic.lives == _hudLives) {
      return;
    }
    _hudScore = _logic.score;
    _hudRound = round;
    _hudLives = _logic.lives;
    widget.session.updateHud(
      score: _logic.score,
      status: 'Round $round/${_logic.rounds}',
      detail: 'Lives ${_logic.lives}',
      progress: _logic.roundsPlayed / _logic.rounds,
    );
  }

  // Input ---------------------------------------------------------------------

  void _tapTarget() {
    if (!_interactive) return;
    final reaction = _logic.tapTarget();
    if (reaction >= 0) AudioService.I.sfx(SfxKeys.hit);
    _pushHud();
    if (_logic.isOver) {
      _cancelTicker();
      widget.session.finish(
        won: _logic.won,
        stats: {'avgMs': _logic.avgReactionMs},
      );
      return;
    }
    if (mounted) setState(() {});
  }

  // Build ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: _buildBoard());
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final targetVisible =
            _logic.phase == TapReflexPhase.targetUp && _interactive;
        final left =
            min(max(0.0, _logic.targetX * width - _targetSize / 2),
                max(0.0, width - _targetSize));
        final top = min(max(0.0, _logic.targetY * height - _targetSize / 2),
            max(0.0, height - _targetSize));
        return Semantics(
          label: 'Reflex board. Tap the circle target as soon as it '
              'appears.',
          child: Stack(
            children: [
              Container(color: palette.boardA),
              if (!targetVisible) _buildIdleMessage(context),
              if (targetVisible)
                Positioned(
                  left: left,
                  top: top,
                  child: _buildTarget(palette),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIdleMessage(BuildContext context) {
    final message = _logic.phase == TapReflexPhase.starting
        ? 'Get ready…'
        : _logic.phase == TapReflexPhase.over
            ? 'Round complete'
            : 'Watch for the next target…';
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: GamePalette.contrastOn(widget.session.palette.boardA),
            ),
      ),
    );
  }

  Widget _buildTarget(GamePalette palette) {
    return Semantics(
      button: true,
      label: 'Target — tap now',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tapTarget,
        child: Container(
          width: _targetSize,
          height: _targetSize,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
            border: Border.all(
              color: GamePalette.contrastOn(palette.accent),
              width: 3,
            ),
          ),
          child: const Center(
            child: CustomPaint(
              painter: _ReflexTargetPainter(),
              size: Size(28, 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inner diamond marker so the target reads by shape as well as colour.
class _ReflexTargetPainter extends CustomPainter {
  const _ReflexTargetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, h / 2)
      ..lineTo(w / 2, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _ReflexTargetPainter oldDelegate) => false;
}

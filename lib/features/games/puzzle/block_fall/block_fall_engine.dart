/// Block fall engine (Tetris-lite): steer falling tetrominoes with the
/// on-screen buttons or swipes, clear lines, reach the target before the
/// stack tops out. Supports one paid continue (clears the top rows).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'block_fall_logic.dart';

/// Catalog engine for the `block_fall` template.
class BlockFallEngine implements GameEngine {
  const BlockFallEngine();

  @override
  String get templateId => 'block_fall';

  @override
  String get instructions =>
      'Steer the falling blocks with the buttons or swipes and clear full '
      'lines. Reach the line target before the stack reaches the top.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) => BlockFallGame(session: session);
}

/// The block fall gameplay screen for one session.
class BlockFallGame extends StatefulWidget {
  const BlockFallGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<BlockFallGame> createState() => _BlockFallGameState();
}

class _BlockFallGameState extends State<BlockFallGame> {
  static const int _tickMs = 100;

  late final BlockFallLogic _logic;
  late final int _targetLines;

  Timer? _ticker;
  double _fallAccumulator = 0;
  double _dragX = 0;
  double _dragY = 0;
  bool _awaitingContinue = false;
  int _lastLines = 0;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final cols = _bounded(cfg.getInt('cols', 8), 8, 10);
    final speed = cfg.getDouble('speed', 1.6);
    final targetLines = cfg.getInt('targetLines', 10);
    _targetLines = targetLines < 1 ? 1 : targetLines;
    _logic = BlockFallLogic(cols: cols, random: Random())..gravitySpeed = speed;
    widget.session.onExtraLifeGranted = _onExtraLife;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
    _ticker = Timer.periodic(
      const Duration(milliseconds: _tickMs),
      _onTick,
    );
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _ticker?.cancel();
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_awaitingContinue &&
      !_logic.gameOver;

  void _onSessionChanged() {
    if (widget.session.isFinished) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _pushHud() {
    final ratio = _logic.lines / _targetLines;
    widget.session.updateHud(
      score: _logic.score,
      status: 'Lines ${_logic.lines}',
      detail: 'Target $_targetLines',
      progress: ratio < 0 ? 0.0 : (ratio > 1 ? 1.0 : ratio),
    );
  }

  void _onTick([Timer? _]) {
    if (!_interactive) return;
    _fallAccumulator += _tickMs / 1000 * _logic.gravitySpeed;
    var landed = false;
    while (_fallAccumulator >= 1) {
      _fallAccumulator -= 1;
      if (!_logic.stepDown()) {
        landed = true;
        break;
      }
    }
    if (!mounted) return;
    if (landed) {
      _afterLanding();
    } else {
      setState(() {});
    }
  }

  /// Central post-lock bookkeeping: HUD, win check, top-out continue flow.
  void _afterLanding() {
    final cleared = _logic.lines - _lastLines;
    _lastLines = _logic.lines;
    if (cleared >= 4) {
      AudioService.I.sfx(SfxKeys.powerup);
    } else if (cleared > 0) {
      AudioService.I.sfx(SfxKeys.matchFound);
    } else {
      AudioService.I.sfx(SfxKeys.place);
    }
    _pushHud();
    if (mounted) setState(() {});
    if (_logic.lines >= _targetLines) {
      AudioService.I.sfx(SfxKeys.win);
      widget.session.finish(
        won: true,
        stats: {'lines': _logic.lines, 'level': _logic.level},
      );
      return;
    }
    if (_logic.gameOver) _handleTopOut();
  }

  Future<void> _handleTopOut() async {
    if (_awaitingContinue || widget.session.isFinished) return;
    AudioService.I.sfx(SfxKeys.die);
    _awaitingContinue = true;
    // Ask the shell BEFORE finishing; a true result means the
    // onExtraLifeGranted callback has already revived the player.
    final revived = await widget.session.requestContinue();
    if (!mounted) return;
    if (!revived) {
      widget.session.finish(
        won: false,
        stats: {'lines': _logic.lines, 'level': _logic.level},
      );
    }
  }

  void _onExtraLife() {
    _logic.clearTopRows(6);
    _logic.spawnNext();
    AudioService.I.sfx(SfxKeys.correct);
    _awaitingContinue = false;
    _fallAccumulator = 0;
    _pushHud();
    if (mounted) setState(() {});
  }

  // Controls ----------------------------------------------------------------

  void _steer(int dc) {
    if (!_interactive) return;
    if (_logic.move(0, dc)) setState(() {});
  }

  void _rotate() {
    if (!_interactive) return;
    if (_logic.rotate()) setState(() {});
  }

  void _drop() {
    if (!_interactive) return;
    _logic.hardDrop();
    _afterLanding();
  }

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text('Next', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 8),
                _nextPreview(),
                const Spacer(),
                Text('Level ${_logic.level}',
                    style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _logic.cols / _logic.rows,
                child: _buildBoard(),
              ),
            ),
          ),
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    final view = _logic.viewGrid();
    return Semantics(
      label: 'Falling blocks board, tap to rotate, swipe to steer',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _rotate,
        onHorizontalDragUpdate: (details) {
          _dragX += details.delta.dx;
          const step = 36.0;
          while (_dragX.abs() >= step) {
            _steer(_dragX.isNegative ? -1 : 1);
            _dragX -= _dragX.isNegative ? -step : step;
          }
        },
        onHorizontalDragEnd: (_) => _dragX = 0,
        onVerticalDragUpdate: (details) {
          _dragY += details.delta.dy;
          const stepY = 30.0;
          while (_dragY >= stepY) {
            _dragY -= stepY;
            if (!_interactive) break;
            if (!_logic.stepDown()) {
              _afterLanding();
              return;
            }
          }
          if (mounted) setState(() {});
        },
        onVerticalDragEnd: (details) {
          _dragY = 0;
          if (details.velocity.pixelsPerSecond.dy > 420) _drop();
        },
        child: Container(
          decoration: BoxDecoration(
            color: palette.boardB,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              for (final row in view)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < row.length; c++)
                        Expanded(child: _buildCell(row[c])),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int value) {
    if (value < 0) {
      return Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: const Color(0x1A000000), // subtle empty-cell tint
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    final color = kPieceColors[value % kPieceColors.length];
    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: GamePalette.contrastOn(color), width: 0.5),
      ),
    );
  }

  Widget _nextPreview() {
    final next = _logic.nextType;
    final def = kTetrominoes[next];
    final color = kPieceColors[next % kPieceColors.length];
    return SizedBox(
      width: 40,
      height: 34,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var r = 0; r < def.box; r++)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var c = 0; c < def.box; c++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.all(0.5),
                      decoration: BoxDecoration(
                        color: def.baseCells.any((p) => p.r == r && p.c == c)
                            ? color
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Semantics(
      label: 'Block controls',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _controlButton(Icons.arrow_back, 'Move block left', () => _steer(-1)),
            _controlButton(Icons.rotate_right, 'Rotate block', _rotate),
            _controlButton(Icons.arrow_forward, 'Move block right', () => _steer(1)),
            _controlButton(Icons.south, 'Drop block to the floor', _drop),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, String label, VoidCallback onPressed) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        icon: Icon(icon, size: 28),
        constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
        onPressed: _interactive ? onPressed : null,
      ),
    );
  }
}

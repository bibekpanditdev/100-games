/// Connect-four engine: drop discs into a 7x6 grid and line up four before
/// the CPU does. Player discs are solid, CPU discs are rings, so colour is
/// never the only cue.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'connect_four_logic.dart';

/// Catalog engine for the `connect_four` template.
class ConnectFourEngine implements GameEngine {
  const ConnectFourEngine();

  @override
  String get templateId => 'connect_four';

  @override
  String get instructions =>
      'Tap a column to drop your disc; line up four in any direction before '
      'the CPU lines up its own. Filling the board counts as a draw, which '
      'still beats losing.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => ConnectFourGame(session: session);
}

/// The connect-four gameplay screen for one session.
class ConnectFourGame extends StatefulWidget {
  const ConnectFourGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<ConnectFourGame> createState() => _ConnectFourGameState();
}

class _ConnectFourGameState extends State<ConnectFourGame> {
  static const _cpuDelay = Duration(milliseconds: 600);
  static const _hintDuration = Duration(seconds: 3);

  late final ConnectFourLogic _logic;
  late final int _level;

  bool _cpuThinking = false;
  int? _hintColumn;
  Timer? _cpuTimer;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _level = _bounded(cfg.getInt('aiLevel', 2), 1, 3);
    _logic = ConnectFourLogic(aiLevel: _level, random: Random());
    widget.session.onHintGranted = _applyHint;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_cpuThinking &&
      !_logic.isGameOver;

  void _onSessionChanged() {
    final session = widget.session;
    if (session.isPaused || session.isFinished) {
      _cpuTimer?.cancel();
      _cpuTimer = null;
      if (session.isFinished) {
        _hintTimer?.cancel();
        _hintTimer = null;
      }
    } else if (_cpuThinking) {
      // Resume: restart the CPU delay from scratch.
      _scheduleCpu();
    }
    if (mounted) setState(() {});
  }

  void _pushHud() {
    widget.session.updateHud(
      score: 0,
      status: _statusLine(),
      detail: 'Level $_level',
      progress: null,
    );
  }

  String _statusLine() {
    if (_logic.isGameOver) {
      return switch (_logic.winner) {
        ConnectFourLogic.player => 'You win!',
        ConnectFourLogic.cpu => 'CPU wins',
        _ => 'Draw',
      };
    }
    return _cpuThinking ? 'CPU thinking' : 'Your move';
  }

  void _onColumnTap(int col) {
    if (!_interactive || !_logic.canDrop(col)) return;
    if (!_logic.play(col)) return;
    AudioService.I.sfx(SfxKeys.place);
    HapticFeedback.lightImpact();
    _afterMove();
  }

  void _afterMove() {
    if (_logic.isGameOver) {
      _settle();
    } else {
      _cpuThinking = true;
      _scheduleCpu();
    }
    _pushHud();
    if (mounted) setState(() {});
  }

  void _scheduleCpu() {
    _cpuTimer?.cancel();
    _cpuTimer = Timer(_cpuDelay, _onCpuTick);
  }

  void _onCpuTick() {
    _cpuTimer = null;
    if (widget.session.isPaused || widget.session.isFinished) return;
    _logic.cpuMove();
    _cpuThinking = false;
    AudioService.I.sfx(SfxKeys.place);
    HapticFeedback.selectionClick();
    if (_logic.isGameOver) {
      _settle();
    } else {
      _pushHud();
    }
    if (mounted) setState(() {});
  }

  void _settle() {
    _cpuTimer?.cancel();
    _cpuTimer = null;
    _hintTimer?.cancel();
    final won = _logic.winner == ConnectFourLogic.player;
    final draw = _logic.isDraw;
    if (won) {
      AudioService.I.sfx(SfxKeys.win);
    } else if (draw) {
      AudioService.I.sfx(SfxKeys.place);
    }
    _pushHud();
    widget.session.finish(
      won: won || draw,
      score: won ? 100 : (draw ? 50 : 0),
      stats: {'result': won ? 1 : (draw ? 0 : -1), 'level': _level},
    );
  }

  Future<void> _requestHint() async {
    // The shell applies the hint via onHintGranted after payment; a false
    // return just means the request was declined.
    await widget.session.requestHint();
  }

  void _applyHint() {
    final session = widget.session;
    if (session.isPaused || session.isFinished || _logic.isGameOver) return;
    final col = _logic.bestColumnFor(ConnectFourLogic.player);
    if (col < 0) return;
    AudioService.I.sfx(SfxKeys.hint);
    _hintTimer?.cancel();
    setState(() => _hintColumn = col);
    _hintTimer = Timer(_hintDuration, () {
      if (mounted) setState(() => _hintColumn = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _logic.cols / _logic.rows,
                child: _buildBoard(),
              ),
            ),
          ),
          _buildColumnButtons(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _statusLine(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                _hintButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return Semantics(
      label:
          'Connect four board, ${_logic.cols} columns by ${_logic.rows} rows',
      child: Container(
        decoration: BoxDecoration(
          color: palette.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var c = 0; c < _logic.cols; c++)
              Expanded(child: _buildColumn(c)),
          ],
        ),
      ),
    );
  }

  Widget _buildColumn(int col) {
    final hinted = _hintColumn == col;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onColumnTap(col),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: hinted ? GamePalette.contrastOn(widget.session.palette.accent).withOpacity(0.15) : null,
        ),
        child: Column(
          children: [
            for (var r = 0; r < _logic.rows; r++)
              Expanded(child: _buildCell(r, col)),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final palette = widget.session.palette;
    final idx = r * _logic.cols + c;
    final mark = _logic.board[idx];
    final isLast = _logic.lastMove == idx;
    final owner = mark == 0
        ? 'empty'
        : mark == ConnectFourLogic.player ? 'your disc' : 'CPU disc';
    return Semantics(
      container: true,
      label: 'Row ${r + 1} column ${c + 1}, $owner',
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: CustomPaint(
          size: Size.infinite,
          painter: _DiscPainter(
            mark: mark,
            emptyColor: palette.boardB,
            isLast: isLast,
          ),
        ),
      ),
    );
  }

  Widget _buildColumnButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var c = 0; c < _logic.cols; c++)
            Expanded(
              child: Semantics(
                button: true,
                label: 'Drop a disc into column ${c + 1}',
                child: IconButton(
                  tooltip: 'Drop into column ${c + 1}',
                  icon: const Icon(Icons.arrow_drop_down_circle),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: _interactive && _logic.canDrop(c)
                      ? () => _onColumnTap(c)
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hintButton() {
    return Semantics(
      button: true,
      label: 'Get a hint',
      child: FilledButton.tonalIcon(
        onPressed: _interactive ? _requestHint : null,
        style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Hint'),
      ),
    );
  }
}

/// Draws one cell: an empty socket, a solid player disc (with an inner
/// dot) or a ringed CPU disc — shape redundancy for colour-blind safety.
class _DiscPainter extends CustomPainter {
  const _DiscPainter({
    required this.mark,
    required this.emptyColor,
    required this.isLast,
  });

  final int mark;
  final Color emptyColor;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * 0.42;
    if (mark == 0) {
      canvas.drawCircle(center, radius, Paint()..color = emptyColor);
      return;
    }
    final color = mark == ConnectFourLogic.player ? kPieceColors[0] : kPieceColors[1];
    if (mark == ConnectFourLogic.player) {
      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center,
        radius * 0.28,
        Paint()..color = GamePalette.contrastOn(color),
      );
    } else {
      canvas.drawCircle(
        center,
        radius * 0.78,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.42,
      );
    }
    if (isLast) {
      canvas.drawCircle(
        center,
        radius * 0.98,
        Paint()
          ..color = GamePalette.contrastOn(color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.05,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DiscPainter oldDelegate) =>
      oldDelegate.mark != mark ||
      oldDelegate.emptyColor != emptyColor ||
      oldDelegate.isLast != isLast;
}

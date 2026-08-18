/// Tic-tac-toe engine: the player is X against a three-tier CPU O. Level 3
/// plays perfect minimax and can only be drawn against, never beaten.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'tic_tac_toe_logic.dart';

/// Catalog engine for the `tic_tac_toe` template.
class TicTacToeEngine implements GameEngine {
  const TicTacToeEngine();

  @override
  String get templateId => 'tic_tac_toe';

  @override
  String get instructions =>
      'Line up three X marks in a row, column or diagonal before the CPU '
      'lines up its O marks. A draw still counts as a win on level 3 — the '
      'perfect player cannot be beaten.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => TicTacToeGame(session: session);
}

/// The tic-tac-toe gameplay screen for one session.
class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  static const _cpuDelay = Duration(milliseconds: 550);
  static const _hintDuration = Duration(seconds: 3);

  late final TicTacToeLogic _logic;
  late final int _level;

  bool _cpuThinking = false;
  bool _finished = false;
  int? _hintCell;
  Timer? _cpuTimer;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _level = _bounded(cfg.getInt('aiLevel', 2), 1, 3);
    _logic = TicTacToeLogic(aiLevel: _level, random: Random());
    widget.session.onHintGranted = _applyHint;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
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

  @override
  void dispose() {
    _cpuTimer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _pushHud() {
    widget.session.updateHud(
      score: 0,
      status: _statusLine(),
      detail: 'Level $_level',
    );
  }

  String _statusLine() {
    if (_logic.isGameOver) {
      return switch (_logic.winner) {
        TicTacToeLogic.player => 'You win!',
        TicTacToeLogic.cpu => 'CPU wins',
        _ => 'Draw',
      };
    }
    return _cpuThinking ? 'CPU thinking' : 'Your move';
  }

  void _onCellTap(int index) {
    if (!_interactive) return;
    if (!_logic.play(index)) return;
    AudioService.I.sfx(SfxKeys.place);
    HapticFeedback.lightImpact();
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
    if (_finished) return;
    _finished = true;
    _cpuTimer?.cancel();
    _cpuTimer = null;
    _hintTimer?.cancel();
    final won = _logic.winner == TicTacToeLogic.player;
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
      stats: {
        'result': won ? 1 : (draw ? 0 : -1),
        'level': _level,
      },
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
    final move = _logic.bestMoveForPlayer();
    if (move < 0) return;
    AudioService.I.sfx(SfxKeys.hint);
    _hintTimer?.cancel();
    setState(() => _hintCell = move);
    _hintTimer = Timer(_hintDuration, () {
      if (mounted) setState(() => _hintCell = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
            ),
          ),
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
    final winLine = _logic.winningLine();
    return Semantics(
      label: 'Tic tac toe board, three by three. You are X.',
      child: Container(
        decoration: BoxDecoration(
          color: palette.boardB,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (var r = 0; r < 3; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 3; c++)
                      Expanded(
                        child: _buildCell(r, c, winLine?.contains(r * 3 + c) ?? false),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c, bool inWinLine) {
    final palette = widget.session.palette;
    final index = r * 3 + c;
    final mark = _logic.board[index];
    final hinted = _hintCell == index;
    return GestureDetector(
      onTap: () => _onCellTap(index),
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: (r + c) % 2 == 0 ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: inWinLine ? [BoxShadow(color: palette.accent.withOpacity(0.4), blurRadius: 12)] : null,
          border: inWinLine || hinted
              ? Border.all(color: palette.accent, width: 3)
              : Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
          child: mark == 0
              ? (hinted ? Icon(Icons.lightbulb, color: palette.accent.withOpacity(0.3), size: 30) : null)
              : CustomPaint(
                  key: ValueKey('mark_$index'),
                  size: const Size(50, 50),
                  painter: _MarkPainter(
                    isX: mark == TicTacToeLogic.player,
                    color: mark == TicTacToeLogic.player
                        ? palette.accent
                        : const Color(0xFF424242),
                  ),
                ),
        ),
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

/// Draws an X (two crossed strokes) or an O (a ring) — shape plus colour
/// so marks never rely on colour alone.
class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.isX, required this.color});

  final bool isX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final inset = Size.square(w < h ? w : h).width * 0.14;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w < h ? w : h) * 0.13
      ..strokeCap = StrokeCap.round;
    if (isX) {
      canvas.drawLine(Offset(inset, inset), Offset(w - inset, h - inset), paint);
      canvas.drawLine(Offset(w - inset, inset), Offset(inset, h - inset), paint);
    } else {
      canvas.drawCircle(
        Offset(w / 2, h / 2),
        (w < h ? w : h) / 2 - inset,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      oldDelegate.isX != isX || oldDelegate.color != color;
}

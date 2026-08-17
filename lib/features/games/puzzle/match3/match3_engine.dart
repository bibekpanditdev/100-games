/// Match-3 engine: tap two adjacent pieces to swap, chain cascades for
/// multiplied score, reach the target before the moves run out.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'match3_logic.dart';

/// Catalog engine for the `match3` template.
class Match3Engine implements GameEngine {
  const Match3Engine();

  @override
  String get templateId => 'match3';

  @override
  String get instructions =>
      'Swap two adjacent pieces to line up three or more identical ones. '
      'Cascade chains multiply your score — reach the target before the '
      'moves run out.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => Match3Game(session: session);
}

/// The match-3 gameplay screen for one session.
class Match3Game extends StatefulWidget {
  const Match3Game({super.key, required this.session});

  final GameSessionController session;

  @override
  State<Match3Game> createState() => _Match3GameState();
}

class _Match3GameState extends State<Match3Game> {
  late final Match3Board _board;
  late final int _rows;
  late final int _cols;
  late final int _target;

  int _movesLeft = 0;
  int _score = 0;
  int _maxCascade = 0;
  int _clearedTiles = 0;
  int? _selected;
  Set<int> _hintCells = const <int>{};
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _cols = _bounded(cfg.getInt('cols', 7), 5, 10);
    _rows = _bounded(cfg.getInt('rows', 7), 5, 10);
    _movesLeft = cfg.getInt('moves', 20);
    final target = cfg.getInt('target', 2000);
    _target = target < 1 ? 1 : target;
    _board = Match3Board(rows: _rows, cols: _cols, random: Random());
    widget.session.onHintGranted = _applyHint;
    _pushHud();
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  void _pushHud() {
    final ratio = _score / _target;
    widget.session.updateHud(
      score: _score,
      status: 'Moves $_movesLeft',
      detail: 'Target $_target',
      progress: ratio < 0 ? 0.0 : (ratio > 1 ? 1.0 : ratio),
    );
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  void _onCellTap(int index) {
    if (!_interactive) return;
    final selected = _selected;
    if (selected == null || selected == index) {
      setState(() => _selected = selected == index ? null : index);
      return;
    }
    if (!_board.isAdjacent(selected, index)) {
      // Treat a far tap as starting a new selection.
      setState(() => _selected = index);
      return;
    }
    if (!_board.isValidSwap(selected, index)) {
      // Adjacent but no match: reject the swap and deselect.
      AudioService.I.sfx(SfxKeys.wrong);
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = null);
    _performMove(selected, index);
  }

  void _performMove(int a, int b) {
    _board.applySwap(a, b);
    final result = _board.resolveMatches();
    if (result.cleared > 0) AudioService.I.sfx(SfxKeys.matchFound);
    _movesLeft -= 1;
    _score += result.scoreGained;
    _clearedTiles += result.cleared;
    if (result.cascades > _maxCascade) _maxCascade = result.cascades;
    if (!_board.hasValidMove()) _board.shuffle();
    _pushHud();
    setState(() {});
    if (_score >= _target) {
      _finish(won: true);
    } else if (_movesLeft <= 0) {
      _finish(won: false);
    }
  }

  void _finish({required bool won}) {
    AudioService.I.sfx(won ? SfxKeys.win : SfxKeys.lose);
    widget.session.finish(
      won: won,
      score: _score,
      stats: {'cascades': _maxCascade, 'cleared': _clearedTiles},
    );
  }

  Future<void> _requestHint() async {
    // The shell applies the hint via onHintGranted after payment; a false
    // return just means the request was declined.
    await widget.session.requestHint();
  }

  void _applyHint() {
    if (widget.session.isFinished) return;
    final move = _board.findValidMove();
    if (move == null) return;
    AudioService.I.sfx(SfxKeys.hint);
    _hintTimer?.cancel();
    setState(() => _hintCells = <int>{move.a, move.b});
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintCells = const <int>{});
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
                aspectRatio: _cols / _rows,
                child: _buildBoard(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_hintButton()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return Semantics(
      label: 'Match 3 board, $_rows rows by $_cols columns',
      child: Container(
        decoration: BoxDecoration(
          color: palette.boardB,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (var r = 0; r < _rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < _cols; c++)
                      Expanded(child: _buildCell(r, c)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final palette = widget.session.palette;
    final index = r * _cols + c;
    final piece = _board.pieceAt(r, c);
    final selected = _selected == index;
    final hinted = _hintCells.contains(index);
    return Semantics(
      button: true,
      label: 'Piece row ${r + 1} column ${c + 1}'
          '${selected ? ', selected' : ''}',
      child: GestureDetector(
        onTap: () => _onCellTap(index),
        child: Container(
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            color: (r + c) % 2 == 0 ? palette.boardA : palette.boardB,
            borderRadius: BorderRadius.circular(6),
            border: selected || hinted
                ? Border.all(color: palette.accent, width: 3)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CustomPaint(
              painter: _PieceShapePainter(
                pieceIndex: piece,
                color: kPieceColors[piece % kPieceColors.length],
              ),
              size: Size.infinite,
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

/// Draws one piece as a colour + shape pair (circle, square, diamond,
/// triangle, hexagon, rounded square) so pieces never rely on colour
/// alone — colour-blind players get a second channel.
class _PieceShapePainter extends CustomPainter {
  const _PieceShapePainter({required this.pieceIndex, required this.color});

  final int pieceIndex;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minSide = w < h ? w : h;
    final paint = Paint()..color = color;
    switch (pieceIndex % 6) {
      case 0:
        canvas.drawCircle(Offset(w / 2, h / 2), minSide * 0.42, paint);
      case 1:
        {
          canvas.drawRect(
            Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.72, h * 0.72),
            paint,
          );
        }
      case 2:
        {
          final path = Path()
            ..moveTo(w / 2, h * 0.08)
            ..lineTo(w * 0.92, h / 2)
            ..lineTo(w / 2, h * 0.92)
            ..lineTo(w * 0.08, h / 2)
            ..close();
          canvas.drawPath(path, paint);
        }
      case 3:
        {
          final path = Path()
            ..moveTo(w / 2, h * 0.12)
            ..lineTo(w * 0.90, h * 0.84)
            ..lineTo(w * 0.10, h * 0.84)
            ..close();
          canvas.drawPath(path, paint);
        }
      case 4:
        {
          final path = Path();
          final radius = minSide * 0.44;
          for (var i = 0; i < 6; i++) {
            final angle = -pi / 2 + i * pi / 3;
            final x = w / 2 + radius * cos(angle);
            final y = h / 2 + radius * sin(angle);
            if (i == 0) {
              path.moveTo(x, y);
            } else {
              path.lineTo(x, y);
            }
          }
          path.close();
          canvas.drawPath(path, paint);
        }
      case 5:
        {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.12, h * 0.12, w * 0.76, h * 0.76),
              Radius.circular(minSide * 0.2),
            ),
            paint,
          );
        }
    }
  }

  @override
  bool shouldRepaint(covariant _PieceShapePainter oldDelegate) =>
      oldDelegate.pieceIndex != pieceIndex || oldDelegate.color != color;
}

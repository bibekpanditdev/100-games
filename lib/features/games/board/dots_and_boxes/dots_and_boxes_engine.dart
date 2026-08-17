/// Dots-and-boxes engine: tap the gap between two dots to draw a line.
/// Completing a box claims it, scores and grants another turn — whoever
/// claims the most boxes wins.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'dots_and_boxes_logic.dart';

/// Catalog engine for the `dots_and_boxes` template.
class DotsAndBoxesEngine implements GameEngine {
  const DotsAndBoxesEngine();

  @override
  String get templateId => 'dots_and_boxes';

  @override
  String get instructions =>
      'Tap the gap between two dots to draw a line. Completing a box claims '
      'it and gives you another turn — claim more boxes than the CPU to win.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => DotsAndBoxesGame(session: session);
}

/// The dots-and-boxes gameplay screen for one session.
class DotsAndBoxesGame extends StatefulWidget {
  const DotsAndBoxesGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<DotsAndBoxesGame> createState() => _DotsAndBoxesGameState();
}

class _DotsAndBoxesGameState extends State<DotsAndBoxesGame> {
  static const _cpuDelay = Duration(milliseconds: 650);

  late final DotsAndBoxesLogic _logic;
  late final int _level;

  Timer? _cpuTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final size = _bounded(cfg.getInt('size', 4), 2, 8);
    _level = _bounded(cfg.getInt('aiLevel', 2), 1, 3);
    _logic = DotsAndBoxesLogic(size: size, aiLevel: _level, random: Random());
    widget.session.addListener(_onSessionChanged);
    _pushHud();
  }

  @override
  void dispose() {
    _cpuTimer?.cancel();
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_logic.isGameOver &&
      _logic.turn == DotsAndBoxesLogic.player;

  void _onSessionChanged() {
    final session = widget.session;
    if (session.isPaused || session.isFinished) {
      _cpuTimer?.cancel();
      _cpuTimer = null;
    } else if (_logic.turn == DotsAndBoxesLogic.cpu && !_logic.isGameOver) {
      // Resume: restart the CPU delay from scratch.
      _scheduleCpu();
    }
    if (mounted) setState(() {});
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.playerBoxes * 50,
      status: 'You ${_logic.playerBoxes} — ${_logic.cpuBoxes} CPU',
      detail: _logic.turn == DotsAndBoxesLogic.player
          ? 'Your turn'
          : 'CPU thinking',
      progress: _logic.claimedBoxes / _logic.totalBoxes,
    );
  }

  void _onEdgeTap(DotsEdge edge) {
    if (!_interactive) return;
    final boxesBefore = _logic.claimedBoxes;
    if (!_logic.playEdge(edge)) return;
    if (_logic.claimedBoxes > boxesBefore) {
      AudioService.I.sfx(SfxKeys.matchFound);
    } else {
      AudioService.I.sfx(SfxKeys.place);
    }
    HapticFeedback.lightImpact();
    _pushHud();
    if (mounted) setState(() {});
    if (_logic.isGameOver) {
      _settle();
    } else if (_logic.turn == DotsAndBoxesLogic.cpu) {
      _scheduleCpu();
    }
  }

  void _scheduleCpu() {
    _cpuTimer?.cancel();
    _cpuTimer = Timer(_cpuDelay, _onCpuTick);
  }

  void _onCpuTick() {
    _cpuTimer = null;
    if (widget.session.isPaused ||
        widget.session.isFinished ||
        _logic.isGameOver ||
        _logic.turn != DotsAndBoxesLogic.cpu) {
      return;
    }
    final boxesBefore = _logic.claimedBoxes;
    _logic.cpuMove();
    if (_logic.claimedBoxes > boxesBefore) {
      AudioService.I.sfx(SfxKeys.matchFound);
    } else {
      AudioService.I.sfx(SfxKeys.place);
    }
    HapticFeedback.selectionClick();
    _pushHud();
    if (mounted) setState(() {});
    if (_logic.isGameOver) {
      _settle();
    } else if (_logic.turn == DotsAndBoxesLogic.cpu) {
      // The CPU completed a box and keeps the turn.
      _scheduleCpu();
    }
  }

  void _settle() {
    _cpuTimer?.cancel();
    _cpuTimer = null;
    AudioService.I.sfx(
      _logic.playerBoxes > _logic.cpuBoxes ? SfxKeys.win : SfxKeys.lose,
    );
    _pushHud();
    widget.session.finish(
      won: _logic.playerBoxes > _logic.cpuBoxes,
      score: _logic.playerBoxes * 50,
      stats: {
        'playerBoxes': _logic.playerBoxes,
        'cpuBoxes': _logic.cpuBoxes,
        'level': _level,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildBoard()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              _logic.isGameOver
                  ? (_logic.playerBoxes > _logic.cpuBoxes
                      ? 'You win!'
                      : (_logic.playerBoxes == _logic.cpuBoxes
                          ? 'Tied game'
                          : 'CPU wins'))
                  : (_logic.turn == DotsAndBoxesLogic.player
                      ? 'Your turn — draw a line'
                      : 'CPU thinking'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final step = (w < h ? w : h) / (_logic.size + 0.6);
        final originX = (w - _logic.size * step) / 2;
        final originY = (h - _logic.size * step) / 2;
        return Semantics(
          label:
              'Dots and boxes board, ${_logic.size} by ${_logic.size} boxes',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: Size.infinite,
                painter: _BoardPainter(logic: _logic, palette: palette),
              ),
              for (final edge in _edgeHitList())
                _buildEdgeHit(edge, step, originX, originY),
            ],
          ),
        );
      },
    );
  }

  Iterable<DotsEdge> _edgeHitList() {
    final size = _logic.size;
    return [
      for (var r = 0; r < size; r++)
        for (var c = 0; c <= size; c++) (horizontal: true, row: r, col: c),
      for (var r = 0; r <= size; r++)
        for (var c = 0; c < size; c++) (horizontal: false, row: r, col: c),
    ];
  }

  Widget _buildEdgeHit(DotsEdge edge, double step, double ox, double oy) {
    final thickness = step * 0.34;
    final length = step * 0.66;
    final cx = ox + (edge.col + (edge.horizontal ? 0.5 : 0)) * step;
    final cy = oy + (edge.row + (edge.horizontal ? 0 : 0.5)) * step;
    final drawn = _logic.isDrawn(edge);
    return Positioned(
      left: edge.horizontal ? cx - length / 2 : cx - thickness / 2,
      top: edge.horizontal ? cy - thickness / 2 : cy - length / 2,
      width: edge.horizontal ? length : thickness,
      height: edge.horizontal ? thickness : length,
      child: Semantics(
        button: true,
        label: edge.horizontal
            ? 'Horizontal line, row ${edge.row + 1}, between columns '
                '${edge.col + 1} and ${edge.col + 2}'
            : 'Vertical line, column ${edge.col + 1}, between rows '
                '${edge.row + 1} and ${edge.row + 2}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: drawn ? null : () => _onEdgeTap(edge),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Paints the dots, the claimed lines (player accent vs CPU contrast
/// colour) and the X / O marks inside claimed boxes.
class _BoardPainter extends CustomPainter {
  const _BoardPainter({required this.logic, required this.palette});

  final DotsAndBoxesLogic logic;
  final GamePalette palette;

  static const _cpuColor = kPieceColors[5]; // vermillion

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final step = (w < h ? w : h) / (logic.size + 0.6);
    final ox = (w - logic.size * step) / 2;
    final oy = (h - logic.size * step) / 2;

    Offset dot(int i, int j) => Offset(ox + j * step, oy + i * step);

    // Claimed boxes: tinted fill + an X (player) or O (CPU) mark.
    for (var r = 0; r < logic.size; r++) {
      for (var c = 0; c < logic.size; c++) {
        final owner = logic.boxOwner[r * logic.size + c];
        if (owner == 0) continue;
        final color =
            owner == DotsAndBoxesLogic.player ? palette.accent : _cpuColor;
        final rect = Rect.fromCenter(
          center: dot(r, c) + Offset(step / 2, step / 2),
          width: step * 0.7,
          height: step * 0.7,
        );
        canvas.drawRect(rect, Paint()..color = color.withOpacity(0.18));
        final mark = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = step * 0.07
          ..strokeCap = StrokeCap.round;
        final inset = step * 0.12;
        if (owner == DotsAndBoxesLogic.player) {
          canvas.drawLine(rect.topLeft + Offset(inset, inset),
              rect.bottomRight - Offset(inset, inset), mark);
          canvas.drawLine(rect.topRight - Offset(inset, -inset),
              rect.bottomLeft + Offset(inset, -inset), mark);
        } else {
          canvas.drawCircle(rect.center, rect.width / 2 - inset, mark);
        }
      }
    }

    // Drawn lines: player lines use the palette accent, CPU lines a
    // contrasting piece colour.
    final linePaint = Paint()
      ..strokeWidth = step * 0.1
      ..strokeCap = StrokeCap.round;
    for (final edge in logic.drawnEdges) {
      final a = dot(edge.row, edge.col);
      final b = edge.horizontal
          ? dot(edge.row, edge.col + 1)
          : dot(edge.row + 1, edge.col);
      linePaint.color =
          logic.edgeOwner[edge] == DotsAndBoxesLogic.player ? palette.accent : _cpuColor;
      canvas.drawLine(a, b, linePaint);
    }

    // Dots on top.
    final dotPaint = Paint()..color = const Color(0xFF37474F);
    for (var i = 0; i <= logic.size; i++) {
      for (var j = 0; j <= logic.size; j++) {
        canvas.drawCircle(dot(i, j), step * 0.07, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter oldDelegate) => true;
}

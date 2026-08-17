/// Pipes engine — rotate-to-connect: tap tiles to twist them until every
/// end cap is fed from the central pump. No timer; paid hints twist one
/// wrong tile home. Full save/resume through [GameSessionController].
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../common/grid_render.dart';
import 'pipes_logic.dart';

/// Catalog engine for the `pipes` template.
class PipesEngine implements GameEngine {
  const PipesEngine();

  @override
  String get templateId => 'pipes';

  @override
  String get instructions =>
      'Rotate the pipe segments by tapping them until water from the '
      'central pump reaches every end cap. Filled tiles light up — there is '
      'no timer, so take your time.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => PipesGame(session: session);
}

/// The Pipes gameplay screen for one session.
class PipesGame extends StatefulWidget {
  const PipesGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<PipesGame> createState() => _PipesGameState();
}

class _PipesGameState extends State<PipesGame> {
  late PipesLogic _logic;
  late int _seed;
  late int _size;
  late int _par;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final size = cfg.getInt('size', 6);
    _size = size < 4 ? 4 : (size > 8 ? 8 : size);
    _seed = Random().nextInt(0x7FFFFFFF);
    _logic = PipesLogic(size: _size, random: Random(_seed));
    _par = _logic.minRotationsToSolve();

    final restored = widget.session.restoredState;
    if (restored != null &&
        restored['seed'] is num &&
        restored['size'] is num &&
        restored['rot'] is List) {
      final rSize = (restored['size'] as num).toInt();
      final rotRaw = restored['rot'] as List;
      final rotations = <int>[
        for (final r in rotRaw) r is num ? r.toInt() : -1,
      ];
      if (rSize >= 3 && rSize <= 9 && rotations.length == rSize * rSize) {
        final candidate = PipesLogic(
          size: rSize,
          random: Random((restored['seed'] as num).toInt().abs() & 0x7FFFFFFF),
        );
        if (candidate.restoreRotations(
          rotations,
          moves: _toInt(restored['rotations'], 0),
        )) {
          _logic = candidate;
          _size = rSize;
          _seed = (restored['seed'] as num).toInt().abs() & 0x7FFFFFFF;
          _par = _toInt(restored['par'], 0);
          if (_par <= 0) {
            _par = candidate.rotations + candidate.minRotationsToSolve();
          }
        }
      }
    }
    widget.session.onHintGranted = _grantHint;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
    _save();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    super.dispose();
  }

  static int _toInt(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  bool get _interactive =>
      !_finished &&
      !widget.session.isPaused &&
      !widget.session.isFinished;

  void _onSessionChanged() {
    // No timers here — just keep the persisted board fresh on pause.
    if (widget.session.isPaused) _save();
  }

  void _pushHud() {
    final total = _logic.endpoints.length;
    widget.session.updateHud(
      score: 0,
      status: 'Live ${_logic.liveEndpointCount}/$total',
      detail: 'Rotations ${_logic.rotations}',
      progress: total == 0 ? null : _logic.liveEndpointCount / total,
    );
  }

  void _onTileTap(int index) {
    if (!_interactive) return;
    if (!_logic.rotateCell(index)) return;
    AudioService.I.sfx(SfxKeys.rotate);
    _pushHud();
    setState(() {});
    _save();
    _checkSolved();
  }

  void _checkSolved() {
    if (_finished || !_logic.isSolved) return;
    _finished = true;
    AudioService.I.sfx(SfxKeys.solved);
    final bonus = min(500, max(0, _par * 2 - _logic.rotations) * 10);
    widget.session.finish(
      won: true,
      score: 400 + bonus,
      stats: {'rotations': _logic.rotations},
    );
  }

  Future<void> _onHintPressed() async {
    if (!_interactive) return;
    // Payment is resolved by the shell; the board only reacts inside
    // [_grantHint]. A false return simply means the request was declined.
    await widget.session.requestHint();
  }

  /// Shell-invoked hint (payment already granted): twist one wrong tile to
  /// its correct orientation.
  void _grantHint() {
    if (!_interactive) return;
    final index = _logic.hintIndex();
    if (index == null) return;
    _logic.rotateToSolved(index);
    AudioService.I.sfx(SfxKeys.hint);
    _pushHud();
    setState(() {});
    _save();
    _checkSolved();
  }

  void _save() {
    widget.session.saveState(<String, dynamic>{
      'seed': _seed,
      'size': _size,
      'rot': _logic.rotationSnapshot(),
      'rotations': _logic.rotations,
      'par': _par,
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    label: 'Pipes board, $_size by $_size. The pump sits in '
                        'the centre; every end cap must be connected.',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boardSize = constraints.biggest.shortestSide;
                        return SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: _size,
                            ),
                            itemCount: _size * _size,
                            itemBuilder: (context, index) =>
                                _tile(index, palette),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Semantics(
              label: 'Hint',
              button: true,
              child: OutlinedButton.icon(
                onPressed: _interactive ? _onHintPressed : null,
                icon: const Icon(Icons.lightbulb),
                label: const Text('Hint'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(int index, GamePalette palette) {
    final x = index % _size;
    final y = index ~/ _size;
    final isSource = index == _logic.source;
    final isEndpoint = _logic.endpoints.contains(index);
    final live = _logic.isLive(index);
    final mask = _logic.maskOf(index);

    final pipeColor = isSource
        ? GamePalette.contrastOn(palette.accent)
        : (live
            ? palette.accent
            : GamePalette.contrastOn(palette.boardB).withOpacity(0.4));
    final markerColor = isSource
        ? GamePalette.contrastOn(palette.accent)
        : isEndpoint
            ? (live
                ? kPieceColors[2]
                : GamePalette.contrastOn(palette.boardB).withOpacity(0.5))
            : GamePalette.contrastOn(live ? palette.accent : palette.boardB);

    return MindGridCell(
      onTap: () => _onTileTap(index),
      backgroundColor: isSource
          ? palette.accent
          : (live ? palette.boardA : palette.boardB),
      semanticsLabel: '${isSource ? 'Pump' : 'Pipe'}, row ${y + 1} column '
          '${x + 1}, ${PipeDirs.count(mask)} connections, '
          '${live ? 'connected' : 'not connected'}. Rotates on tap.',
      child: CustomPaint(
        painter: _PipeTilePainter(
          mask: mask,
          pipeColor: pipeColor,
          markerColor: markerColor,
          isSource: isSource,
          isEndpoint: isEndpoint,
          live: live,
        ),
      ),
    );
  }
}

class _PipeTilePainter extends CustomPainter {
  const _PipeTilePainter({
    required this.mask,
    required this.pipeColor,
    required this.markerColor,
    required this.isSource,
    required this.isEndpoint,
    required this.live,
  });

  final int mask;
  final Color pipeColor;
  final Color markerColor;
  final bool isSource;
  final bool isEndpoint;
  final bool live;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final stroke = Paint()
      ..color = pipeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.22
      ..strokeCap = StrokeCap.round;

    for (final d in PipeDirs.all) {
      if (mask & d == 0) continue;
      final target = switch (d) {
        PipeDirs.n => Offset(center.dx, 0),
        PipeDirs.e => Offset(w, center.dy),
        PipeDirs.s => Offset(center.dx, h),
        _ => Offset(0, center.dy),
      };
      canvas.drawLine(center, target, stroke);
    }

    if (isSource) {
      // The pump: double ring, never colour-only.
      final ring = Paint()
        ..color = markerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08;
      canvas.drawCircle(center, w * 0.3, ring);
      canvas.drawCircle(center, w * 0.12, Paint()..color = markerColor);
    } else if (isEndpoint) {
      // End cap: filled square when fed, hollow when dry (shape + colour).
      final marker = Paint()
        ..color = markerColor
        ..style = live ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = w * 0.06;
      final r = w * 0.22;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 2, height: r * 2),
          Radius.circular(r * 0.4),
        ),
        marker,
      );
    } else if (live) {
      // Small filled dot on every live plain pipe.
      canvas.drawCircle(center, w * 0.07, Paint()..color = markerColor);
    }
  }

  @override
  bool shouldRepaint(_PipeTilePainter oldDelegate) =>
      oldDelegate.mask != mask ||
      oldDelegate.live != live ||
      oldDelegate.isSource != isSource ||
      oldDelegate.isEndpoint != isEndpoint ||
      oldDelegate.pipeColor != pipeColor ||
      oldDelegate.markerColor != markerColor;
}

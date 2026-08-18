library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';

class CloudGliderEngine implements GameEngine {
  const CloudGliderEngine();
  @override
  String get templateId => 'cloud_glider';
  @override
  String get instructions => 'Tap to flap your wings and glide through the gaps. Don\'t hit the pipes!';
  @override
  bool get supportsHint => false;
  @override
  bool get supportsContinue => true;
  @override
  Widget build(GameSessionController session) => CloudGliderGame(session: session);
}

class CloudGliderGame extends StatefulWidget {
  const CloudGliderGame({super.key, required this.session});
  final GameSessionController session;
  @override
  State<CloudGliderGame> createState() => _CloudGliderGameState();
}

class _CloudGliderGameState extends State<CloudGliderGame> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _birdY = 0.0;
  double _birdV = 0.0;
  final List<_Pipe> _pipes = [];
  int _score = 0;
  bool _dead = false;
  final Random _rand = Random();
  double _tick = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..addListener(_update)..repeat();
    widget.session.onExtraLifeGranted = _revive;
  }

  void _revive() {
    setState(() {
      _dead = false;
      _pipes.clear();
      _birdY = 0.0;
      _birdV = 0.0;
    });
  }

  void _update() {
    if (widget.session.isPaused || widget.session.isFinished || _dead) return;

    setState(() {
      _tick += 0.016;
      _birdV += 0.0008; // Gravity
      _birdY += _birdV;

      if (_birdY > 1.0 || _birdY < -1.0) _die();

      for (final p in _pipes) {
        p.x -= 0.01;
        if (p.x < -0.2 && !p.passed) {
          p.passed = true;
          _score++;
          AudioService.I.sfx(SfxKeys.correct);
        }
        // Collision
        if (p.x < 0.1 && p.x > -0.1) {
          if (_birdY < p.gapTop || _birdY > p.gapBottom) _die();
        }
      }
      _pipes.removeWhere((p) => p.x < -1.0);

      if (_tick > 1.5) {
        _tick = 0;
        final gapTop = -0.6 + _rand.nextDouble() * 0.8;
        _pipes.add(_Pipe(x: 1.2, gapTop: gapTop, gapBottom: gapTop + 0.5));
      }
    });
    widget.session.updateHud(score: _score);
  }

  void _flap() {
    if (_dead) return;
    _birdV = -0.018;
    AudioService.I.sfx(SfxKeys.jump);
  }

  void _die() {
    _dead = true;
    AudioService.I.sfx(SfxKeys.die);
    widget.session.finish(won: _score > 5, score: _score);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flap,
      child: Container(
        color: Colors.transparent,
        child: CustomPaint(
          painter: _GliderPainter(birdY: _birdY, pipes: _pipes, palette: widget.session.palette),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Pipe {
  double x;
  double gapTop;
  double gapBottom;
  bool passed = false;
  _Pipe({required this.x, required this.gapTop, required this.gapBottom});
}

class _GliderPainter extends CustomPainter {
  _GliderPainter({required this.birdY, required this.pipes, required this.palette});
  final double birdY;
  final List<_Pipe> pipes;
  final GamePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = palette.accent;
    
    // Bird (Stylized circle for speed)
    canvas.drawCircle(Offset(size.width * 0.2, (birdY + 1) / 2 * size.height), 15, paint);
    
    // Pipes
    paint.color = palette.boardA;
    for (final p in pipes) {
      final x = p.x * size.width;
      final topH = (p.gapTop + 1) / 2 * size.height;
      final botY = (p.gapBottom + 1) / 2 * size.height;
      
      canvas.drawRect(Rect.fromLTWH(x, 0, 40, topH), paint);
      canvas.drawRect(Rect.fromLTWH(x, botY, 40, size.height - botY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

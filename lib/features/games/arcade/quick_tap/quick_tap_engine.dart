import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';

class QuickTapEngine implements GameEngine {
  const QuickTapEngine();
  @override
  String get templateId => 'quick_tap';
  @override
  String get instructions => 'Tap the dots as fast as you can before they disappear!';
  @override
  bool get supportsHint => false;
  @override
  bool get supportsContinue => true;
  @override
  Widget build(GameSessionController session) => QuickTapGame(session: session);
}

class QuickTapGame extends StatefulWidget {
  const QuickTapGame({super.key, required this.session});
  final GameSessionController session;
  @override
  State<QuickTapGame> createState() => _QuickTapGameState();
}

class _QuickTapGameState extends State<QuickTapGame> {
  final Random _random = Random();
  Offset? _dotPos;
  double _dotSize = 0.0;
  int _score = 0;
  int _lives = 3;
  Timer? _timer;
  double _shrinkRate = 0.02;

  @override
  void initState() {
    super.initState();
    widget.session.onExtraLifeGranted = () => setState(() => _lives = 3);
    _spawnDot();
    _startLoop();
  }

  void _startLoop() {
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (widget.session.isPaused || widget.session.isFinished) return;
      setState(() {
        _dotSize -= _shrinkRate;
        if (_dotSize <= 0) {
          _handleMiss();
        }
      });
      widget.session.updateHud(score: _score, status: 'Lives: $_lives');
    });
  }

  void _spawnDot() {
    _dotPos = Offset(0.1 + _random.nextDouble() * 0.8, 0.1 + _random.nextDouble() * 0.8);
    _dotSize = 1.0;
    _shrinkRate = 0.01 + (_score / 1000) * 0.02;
  }

  void _handleTap() {
    _score += 10;
    AudioService.I.sfx(SfxKeys.correct);
    _spawnDot();
  }

  void _handleMiss() {
    _lives--;
    AudioService.I.sfx(SfxKeys.wrong);
    if (_lives <= 0) {
      _timer?.cancel();
      _finishGame();
    } else {
      _spawnDot();
    }
  }

  void _finishGame() {
    widget.session.finish(won: _score > 100, score: _score);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onTapDown: (details) {
          if (_dotPos == null) return;
          final tapPos = details.localPosition;
          final dotCenter = Offset(_dotPos!.dx * constraints.maxWidth, _dotPos!.dy * constraints.maxHeight);
          final dist = (tapPos - dotCenter).distance;
          if (dist < 40 * _dotSize + 20) {
            _handleTap();
          }
        },
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              if (_dotPos != null)
                Positioned(
                  left: _dotPos!.dx * constraints.maxWidth - 40,
                  top: _dotPos!.dy * constraints.maxHeight - 40,
                  child: Opacity(
                    opacity: _dotSize.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _dotSize,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: widget.session.palette.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: widget.session.palette.accent.withOpacity(0.5), blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

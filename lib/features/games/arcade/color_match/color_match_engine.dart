import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';

class ColorMatchEngine implements GameEngine {
  const ColorMatchEngine();
  @override
  String get templateId => 'color_match';
  @override
  String get instructions => 'Tap the button that matches the center color. Be fast!';
  @override
  bool get supportsHint => false;
  @override
  bool get supportsContinue => false;
  @override
  Widget build(GameSessionController session) => ColorMatchGame(session: session);
}

class ColorMatchGame extends StatefulWidget {
  const ColorMatchGame({super.key, required this.session});
  final GameSessionController session;
  @override
  State<ColorMatchGame> createState() => _ColorMatchGameState();
}

class _ColorMatchGameState extends State<ColorMatchGame> {
  late Color _targetColor;
  late List<Color> _options;
  int _score = 0;
  double _timeLeft = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _nextRound();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      if (widget.session.isPaused || widget.session.isFinished) return;
      setState(() {
        _timeLeft -= 0.01;
        if (_timeLeft <= 0) {
          _timer?.cancel();
          widget.session.finish(won: false, score: _score);
        }
      });
      widget.session.updateHud(progress: _timeLeft, score: _score);
    });
  }

  void _nextRound() {
    final random = Random();
    _options = List.from(kPieceColors)..shuffle(random);
    _options = _options.take(4).toList();
    _targetColor = _options[random.nextInt(_options.length)];
    _timeLeft = 1.0;
  }

  void _handleTap(Color color) {
    if (color == _targetColor) {
      _score += 10;
      AudioService.I.sfx(SfxKeys.correct);
      setState(_nextRound);
    } else {
      AudioService.I.sfx(SfxKeys.wrong);
      _timeLeft -= 0.2;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: _targetColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _targetColor.withValues(alpha: 0.5), blurRadius: 20)],
            ),
          ),
          const SizedBox(height: 60),
          Wrap(
            spacing: 20, runSpacing: 20,
            children: _options.map((c) => GestureDetector(
              onTap: () => _handleTap(c),
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

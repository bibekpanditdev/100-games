/// Higher-or-lower engine: bet whether the next card from a fresh deck is
/// higher or lower than the current one. Correct calls build a streak
/// multiplier; wrong calls cost one of three lives (one paid continue).
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import 'higher_lower_logic.dart';

/// Catalog engine for the `higher_lower` template.
class HigherLowerEngine implements GameEngine {
  const HigherLowerEngine();

  @override
  String get templateId => 'higher_lower';

  @override
  String get instructions =>
      'Will the next card be higher or lower than the one showing? Aces are '
      'low, kings are high and equal ranks are wrong. Three wrong calls end '
      'the run — an extra life keeps your streak alive.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) => HigherLowerGame(session: session);
}

/// The higher-or-lower gameplay screen for one session.
class HigherLowerGame extends StatefulWidget {
  const HigherLowerGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<HigherLowerGame> createState() => _HigherLowerGameState();
}

class _HigherLowerGameState extends State<HigherLowerGame> {
  late final HigherLowerLogic _logic;
  late final int _rounds;

  bool _awaitingContinue = false;
  HigherLowerGuessResult? _lastResult;
  int _bestStreak = 0;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _rounds = _bounded(cfg.getInt('rounds', 10), 5, 30);
    _logic = HigherLowerLogic(rounds: _rounds, random: Random());
    widget.session.onExtraLifeGranted = _onExtraLife;
    _pushHud();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_awaitingContinue &&
      !_logic.isOver;

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.score,
      status: 'Round ${(_logic.round + 1).clamp(1, _rounds)}/$_rounds',
      detail: 'Lives ${_logic.lives}',
      progress: _logic.round / _rounds,
    );
  }

  void _guess(HigherLowerChoice choice) {
    if (!_interactive) return;
    final result = _logic.guess(choice);
    if (_logic.streak > _bestStreak) _bestStreak = _logic.streak;
    _lastResult = result;
    AudioService.I.sfx(SfxKeys.deal);
    if (result.correct) {
      AudioService.I.sfx(SfxKeys.correct);
      HapticFeedback.mediumImpact();
    } else {
      AudioService.I.sfx(SfxKeys.wrong);
      HapticFeedback.heavyImpact();
    }
    _pushHud();
    if (mounted) setState(() {});
    if (_logic.outOfLives) {
      _handleOutOfLives();
    } else if (_logic.completedRounds) {
      widget.session.finish(
        won: true,
        score: _logic.score,
        stats: {'rounds': _logic.round, 'bestStreak': _bestStreak},
      );
    }
  }

  Future<void> _handleOutOfLives() async {
    if (_awaitingContinue || widget.session.isFinished) return;
    _awaitingContinue = true;
    if (mounted) setState(() {});
    // Ask the shell BEFORE finishing; a true result means the
    // onExtraLifeGranted callback has already revived the player.
    final continued = await widget.session.requestContinue();
    if (!mounted) return;
    if (!continued) {
      widget.session.finish(
        won: false,
        score: _logic.score,
        stats: {'rounds': _logic.round, 'bestStreak': _bestStreak},
      );
    }
  }

  void _onExtraLife() {
    if (widget.session.isFinished) return;
    _logic.revive();
    AudioService.I.sfx(SfxKeys.powerup);
    _awaitingContinue = false;
    _pushHud();
    if (mounted) setState(() {});
    // Surviving on the very last round still completes the session.
    if (_logic.completedRounds) {
      widget.session.finish(
        won: true,
        score: _logic.score,
        stats: {'rounds': _logic.round, 'bestStreak': _bestStreak},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: _buildCardArea()),
          _buildButtons(),
        ],
      ),
    );
  }

  Widget _buildCardArea() {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.biggest.shortestSide * 0.55;
          final card = _logic.currentCard;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Current card: ${_rankLabel(card.rank)} of ${_suitName(card.suit)}',
                child: _CardFace(
                  rank: card.rank,
                  suit: card.suit,
                  width: width,
                ),
              ),
              const SizedBox(height: 20),
              _feedback(),
            ],
          );
        },
      ),
    );
  }

  Widget _feedback() {
    final result = _lastResult;
    if (_awaitingContinue) {
      return const Text('Out of lives!', style: TextStyle(fontSize: 18));
    }
    if (result == null) {
      return const Text('Higher or lower?', style: TextStyle(fontSize: 18));
    }
    return Text(
      result.correct
          ? 'Correct! +${result.pointsGained}'
          : 'Wrong — ${_rankLabel(result.nextCard.rank)} of '
              '${_suitName(result.nextCard.suit)}',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: result.correct ? widget.session.palette.accent : const Color(0xFFC62828),
      ),
    );
  }

  Widget _buildButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _betButton(
              label: 'Higher',
              semanticLabel: 'Bet the next card is higher',
              icon: Icons.arrow_upward,
              onPressed: () => _guess(HigherLowerChoice.higher),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _betButton(
              label: 'Lower',
              semanticLabel: 'Bet the next card is lower',
              icon: Icons.arrow_downward,
              onPressed: () => _guess(HigherLowerChoice.lower),
            ),
          ),
        ],
      ),
    );
  }

  Widget _betButton({
    required String label,
    required String semanticLabel,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: FilledButton.icon(
        onPressed: _interactive ? onPressed : null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// Face-up playing card: white surface, rank text and a suit shape.
class _CardFace extends StatelessWidget {
  const _CardFace({required this.rank, required this.suit, required this.width});

  final int rank;
  final int suit;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = _suitColor(suit);
    return Container(
      width: width,
      height: width * 1.45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBDBDBD)),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _rankLabel(rank),
            style: TextStyle(
              fontSize: width * 0.34,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          CustomPaint(
            size: Size.square(width * 0.3),
            painter: _SuitPainter(suit: suit, color: color),
          ),
        ],
      ),
    );
  }
}

/// Hearts / diamonds read red-ish, spades / clubs dark. Suits differ in
/// shape so colour is never the only cue.
Color _suitColor(int suit) => suit == 0 || suit == 1
    ? const Color(0xFFC62828)
    : const Color(0xFF1C1C1E);

String _rankLabel(int rank) => switch (rank) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$rank',
    };

String _suitName(int suit) =>
    switch (suit) { 0 => 'hearts', 1 => 'diamonds', 2 => 'spades', _ => 'clubs' };

/// Draws one of the four suit shapes as a filled path.
class _SuitPainter extends CustomPainter {
  const _SuitPainter({required this.suit, required this.color});

  final int suit;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..color = color;
    switch (suit) {
      case 0: // hearts
        final heart = Path()
          ..moveTo(w * 0.5, h * 0.96)
          ..cubicTo(w * -0.08, h * 0.52, w * 0.16, h * 0.02, w * 0.5, h * 0.3)
          ..cubicTo(w * 0.84, h * 0.02, w * 1.08, h * 0.52, w * 0.5, h * 0.96)
          ..close();
        canvas.drawPath(heart, paint);
      case 1: // diamonds
        final diamond = Path()
          ..moveTo(w * 0.5, h * 0.03)
          ..lineTo(w * 0.97, h * 0.5)
          ..lineTo(w * 0.5, h * 0.97)
          ..lineTo(w * 0.03, h * 0.5)
          ..close();
        canvas.drawPath(diamond, paint);
      case 2: // spades
        final body = Path()
          ..moveTo(w * 0.5, h * 0.02)
          ..cubicTo(w * 1.02, h * 0.5, w * 0.86, h * 0.98, w * 0.5, h * 0.7)
          ..cubicTo(w * 0.14, h * 0.98, w * -0.02, h * 0.5, w * 0.5, h * 0.02)
          ..close();
        canvas.drawPath(body, paint);
        canvas.drawPath(_stem(w, h), paint);
      default: // clubs
        canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.27, paint);
        canvas.drawCircle(Offset(w * 0.26, h * 0.58), w * 0.27, paint);
        canvas.drawCircle(Offset(w * 0.74, h * 0.58), w * 0.27, paint);
        canvas.drawPath(_stem(w, h), paint);
    }
  }

  Path _stem(double w, double h) => Path()
    ..moveTo(w * 0.5, h * 0.58)
    ..quadraticBezierTo(w * 0.52, h * 0.88, w * 0.24, h * 0.96)
    ..lineTo(w * 0.76, h * 0.96)
    ..quadraticBezierTo(w * 0.48, h * 0.88, w * 0.5, h * 0.58)
    ..close();

  @override
  bool shouldRepaint(covariant _SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

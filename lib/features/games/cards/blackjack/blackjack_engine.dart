/// Blackjack engine: a fixed number of hands with a fixed bet. Beat the
/// dealer without busting — blackjack pays 3:2 and the dealer stands on
/// all 17s. Finish with more chips than you started with to win.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'blackjack_logic.dart';

/// Catalog engine for the `blackjack` template.
class BlackjackEngine implements GameEngine {
  const BlackjackEngine();

  @override
  String get templateId => 'blackjack';

  @override
  String get instructions =>
      'Get closer to 21 than the dealer without going over. Aces count 1 or '
      '11, blackjack pays 3:2 and the dealer stands on all 17s. End the '
      'session with more than 100 chips to win.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => BlackjackGame(session: session);
}

/// The blackjack gameplay screen for one session.
class BlackjackGame extends StatefulWidget {
  const BlackjackGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<BlackjackGame> createState() => _BlackjackGameState();
}

class _BlackjackGameState extends State<BlackjackGame> {
  late final BlackjackLogic _logic;
  late final int _rounds;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _rounds = _bounded(cfg.getInt('rounds', 5), 1, 20);
    _logic = BlackjackLogic(rounds: _rounds, random: Random())..startHand();
    AudioService.I.sfx(SfxKeys.deal);
    if (_logic.sessionOver) _finishSession();
    _pushHud();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive => !widget.session.isPaused && !widget.session.isFinished;

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.chips,
      status: 'Chips ${_logic.chips}',
      detail: 'Hand ${_logic.currentHandNumber}/$_rounds',
      progress: _logic.handsPlayed / _rounds,
    );
  }

  void _hit() {
    if (!_interactive || _logic.handOver) return;
    HapticFeedback.selectionClick();
    _logic.hit();
    AudioService.I.sfx(SfxKeys.flip);
    _afterAction();
  }

  void _stand() {
    if (!_interactive || _logic.handOver) return;
    HapticFeedback.selectionClick();
    _logic.stand();
    _afterAction();
  }

  void _nextHand() {
    if (!_interactive || !_logic.handOver || _logic.sessionOver) return;
    HapticFeedback.lightImpact();
    _logic.nextHand();
    AudioService.I.sfx(SfxKeys.deal);
    if (_logic.sessionOver) {
      _finishSession();
    }
    _pushHud();
    if (mounted) setState(() {});
  }

  void _afterAction() {
    _pushHud();
    if (mounted) setState(() {});
    if (_logic.handOver) {
      switch (_logic.result) {
        case BlackjackResult.playerBlackjack:
        case BlackjackResult.playerWins:
          AudioService.I.sfx(SfxKeys.win);
        case BlackjackResult.push:
          AudioService.I.sfx(SfxKeys.place);
        default:
          AudioService.I.sfx(SfxKeys.lose);
      }
      HapticFeedback.mediumImpact();
      if (_logic.sessionOver) {
        _finishSession();
      }
    }
  }

  void _finishSession() {
    widget.session.finish(
      won: _logic.chips > _logic.startingChips,
      score: _logic.chips,
      stats: {
        'chips': _logic.chips,
        'hands': _rounds,
        'reshuffles': _logic.reshuffles,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _handSection(
                    title: 'Dealer',
                    cards: _logic.dealer,
                    hideSecond: !_logic.handOver,
                  ),
                  _resultBanner(),
                  _handSection(title: 'You', cards: _logic.player, hideSecond: false),
                ],
              ),
            ),
          ),
          _controls(),
        ],
      ),
    );
  }

  Widget _resultBanner() {
    if (!_logic.handOver) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Bet ${_logic.betPerHand} — your move',
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    final (label, color) = switch (_logic.result) {
      BlackjackResult.playerBlackjack => ('Blackjack! Pays 3:2', widget.session.palette.accent),
      BlackjackResult.playerWins => ('You win the hand', widget.session.palette.accent),
      BlackjackResult.push => ('Push — bet returned', const Color(0xFF616161)),
      _ => ('Dealer wins the hand', const Color(0xFFC62828)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _handSection({
    required String title,
    required List<BlackjackCard> cards,
    required bool hideSecond,
  }) {
    final showValue = !hideSecond && cards.isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            showValue
                ? '$title: ${BlackjackLogic.handValue(cards)}'
                : '$title: ?',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 116,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth / 5.2).clamp(44.0, 78.0);
              return ListView(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (var i = 0; i < cards.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: hideSecond && i == 1
                          ? _CardBack(color: widget.session.palette.accent)
                          : _CardFace(
                              rank: cards[i].rank,
                              suit: cards[i].suit.index,
                              width: width,
                            ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _controls() {
    if (!_logic.handOver) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Take another card',
                child: FilledButton.icon(
                  onPressed: _interactive ? _hit : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.add),
                  label: const Text('Hit'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Keep your current cards',
                child: FilledButton.tonalIcon(
                  onPressed: _interactive ? _stand : null,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.pan_tool),
                  label: const Text('Stand'),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          button: true,
          label: 'Deal the next hand',
          child: FilledButton.icon(
            onPressed: _interactive && !_logic.sessionOver ? _nextHand : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: const Icon(Icons.casino),
            label: Text('Deal hand ${_logic.handsPlayed + 2}'),
          ),
        ),
      ),
    );
  }
}

/// Face-down card back: accent colour with a contrast border and motif.
class _CardBack extends StatelessWidget {
  const _CardBack({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GamePalette.contrastOn(color), width: 1.5),
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size(24, 24),
        painter: _SuitPainter(suit: 1, color: GamePalette.contrastOn(color)),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _rankLabel(rank),
            style: TextStyle(
              fontSize: width * 0.3,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          CustomPaint(
            size: Size.square(width * 0.26),
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

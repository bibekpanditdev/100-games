/// Playing-card visuals for the memory-match board: face-down backs,
/// face-up cards (rank text + suit shape) and the four suit painters.
///
/// Suits differ in shape and hearts/diamonds read red-ish vs the dark
/// spades/clubs, so colour is never the only cue.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/palettes.dart';

/// Face-up playing card: white surface, rank text and a suit shape.
class MemoryCardFace extends StatelessWidget {
  const MemoryCardFace({super.key, required this.rank, required this.suit});

  final int rank;
  final int suit;

  @override
  Widget build(BuildContext context) {
    final color = suitColor(suit);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDBDBD)),
      ),
      padding: const EdgeInsets.all(3),
      child: FittedBox(
        fit: BoxFit.contain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              rankLabel(rank),
              style: TextStyle(
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            CustomPaint(
              size: const Size(20, 20),
              painter: SuitPainter(suit: suit, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Face-down card back: accent colour with a contrast border and a centre
/// diamond motif.
class MemoryCardBack extends StatelessWidget {
  const MemoryCardBack({super.key, required this.color, this.highlighted = false});

  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        return Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: GamePalette.contrastOn(color),
              width: highlighted ? 3 : 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: Size.square(side * 0.4),
            painter: SuitPainter(suit: 1, color: GamePalette.contrastOn(color)),
          ),
        );
      },
    );
  }
}

/// Hearts / diamonds read red-ish, spades / clubs dark.
Color suitColor(int suit) =>
    suit == 0 || suit == 1 ? const Color(0xFFC62828) : const Color(0xFF1C1C1E);

String rankLabel(int rank) => switch (rank) {
      1 => 'A',
      11 => 'J',
      12 => 'Q',
      13 => 'K',
      _ => '$rank',
    };

String suitName(int suit) => switch (suit) {
      0 => 'hearts',
      1 => 'diamonds',
      2 => 'spades',
      _ => 'clubs',
    };

/// Draws one of the four suit shapes as a filled path.
class SuitPainter extends CustomPainter {
  const SuitPainter({required this.suit, required this.color});

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
  bool shouldRepaint(covariant SuitPainter oldDelegate) =>
      oldDelegate.suit != suit || oldDelegate.color != color;
}

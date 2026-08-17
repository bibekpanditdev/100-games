/// Shared shape-painter helpers for the odd-one-out engine (and any other
/// mind game needing six distinct, colour-independent tile shapes).
///
/// Shapes carry the redundancy required by `palettes.dart`: no game state is
/// ever communicated by colour alone.
library;

import 'package:flutter/material.dart';

/// Six distinct tile shapes.
enum MindShape { circle, square, triangle, diamond, star, hexagon }

extension MindShapeLabel on MindShape {
  /// Accessible name, e.g. `circle`.
  String get label => name;

  /// Human label for semantics, e.g. `circle shape`.
  String get semanticLabel => '$name shape';
}

/// Fills [shape] in [color] inside the given box.
class MindShapePainter extends CustomPainter {
  const MindShapePainter({required this.shape, required this.color});

  final MindShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(pathFor(shape, size), paint);
  }

  /// The path of [shape] scaled into [size] (kept square by callers).
  static Path pathFor(MindShape shape, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    switch (shape) {
      case MindShape.circle:
        path.addOval(Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.86,
          height: h * 0.86,
        ));
      case MindShape.square:
        path.addRect(Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.78,
          height: h * 0.78,
        ));
      case MindShape.triangle:
        path
          ..moveTo(w * 0.5, h * 0.08)
          ..lineTo(w * 0.94, h * 0.88)
          ..lineTo(w * 0.06, h * 0.88)
          ..close();
      case MindShape.diamond:
        path
          ..moveTo(w * 0.5, h * 0.05)
          ..lineTo(w * 0.95, h * 0.5)
          ..lineTo(w * 0.5, h * 0.95)
          ..lineTo(w * 0.05, h * 0.5)
          ..close();
      case MindShape.star:
        const points = 5;
        final outer = Offset(w / 2, h / 2);
        final outerR = w * 0.48;
        final innerR = outerR * 0.44;
        for (var i = 0; i < points * 2; i++) {
          final r = i.isEven ? outerR : innerR;
          final angle = -pi / 2 + i * pi / points;
          final point = Offset(
            outer.dx + r * cos(angle),
            outer.dy + r * sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
      case MindShape.hexagon:
        final center = Offset(w / 2, h / 2);
        final r = w * 0.47;
        for (var i = 0; i < 6; i++) {
          final angle = -pi / 2 + i * pi / 3;
          final point = Offset(
            center.dx + r * cos(angle),
            center.dy + r * sin(angle),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path.close();
    }
    return path;
  }

  @override
  bool shouldRepaint(MindShapePainter oldDelegate) =>
      oldDelegate.shape != shape || oldDelegate.color != color;
}

/// A single filled [MindShape] — fills its parent box, painted with
/// [CustomPaint] (no text, no assets).
class MindShapeView extends StatelessWidget {
  const MindShapeView({
    super.key,
    required this.shape,
    required this.color,
  });

  final MindShape shape;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MindShapePainter(shape: shape, color: color),
      size: Size.infinite,
    );
  }
}

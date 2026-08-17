/// 0–3 star rating with optional reveal animation.
library;

import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.stars,
    this.max = 3,
    this.size = 40,
    this.animation,
  });

  final int stars;
  final int max;
  final double size;

  /// Optional 0..1 controller driving a staggered reveal.
  final Animation<double>? animation;

  @override
  Widget build(BuildContext context) {
    final filled = Theme.of(context).colorScheme.tertiary;
    final empty = Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget star(int index, bool active, double scale) => Semantics(
          label: active ? 'Star ${index + 1} of $max earned' : 'Star ${index + 1} not earned',
          child: Transform.scale(
            scale: scale,
            child: Icon(
              active ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: active ? filled : empty,
            ),
          ),
        );

    if (animation == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [for (var i = 0; i < max; i++) star(i, i < stars, 1)],
      );
    }

    return AnimatedBuilder(
      animation: animation!,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < max; i++)
              star(i, i < stars, _reveal(animation!.value, i)),
          ],
        );
      },
    );
  }

  double _reveal(double t, int index) {
    final start = index * 0.25;
    final local = ((t - start) / 0.35).clamp(0.0, 1.0);
    // Overshoot pop.
    return 0.5 + local - (local * local * (local - 1) * 2).abs() * 0.2;
  }
}

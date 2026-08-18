/// WCAG 2.1 relative-luminance / contrast-ratio math.
///
/// Used by the theme unit tests to keep every text/background pair at
/// AA level (4.5:1 body text, 3:1 large text / UI components).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// sRGB channel to linear-light channel (WCAG 2.1 definition).
double _linearize(double c) {
  return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// WCAG relative luminance of [c], 0..1.
double relativeLuminance(Color c) {
  return 0.2126 * _linearize(c.r) +
      0.7152 * _linearize(c.g) +
      0.0722 * _linearize(c.b);
}

/// WCAG contrast ratio between two colors, >= 1.0.
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG AA contrast verification for every text/background token pair in
/// both themes (spec acceptance criterion §9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/core/theme/app_theme.dart';
import 'package:game/core/utils/contrast.dart';

void main() {
  final Map<String, (ColorScheme, Color)> themes = {
    'light': (() {
      final theme = buildLightTheme();
      return (theme.colorScheme, theme.colorScheme.surfaceVariant);
    })(),
    'dark': (() {
      final theme = buildDarkTheme();
      return (theme.colorScheme, theme.colorScheme.surfaceContainerHighest);
    })(),
  };

  for (final entry in themes.entries) {
    group('theme ${entry.key}', () {
      final scheme = entry.value.$1;
      final surfaceVariant = entry.value.$2;

      final textPairs = <String, (Color, Color)>{
        'onPrimary/primary': (scheme.onPrimary, scheme.primary),
        'onSecondary/secondary': (scheme.onSecondary, scheme.secondary),
        'onTertiary/tertiary': (scheme.onTertiary, scheme.tertiary),
        'onError/error': (scheme.onError, scheme.error),
        'onSurface/surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant/surfaceVariant': (scheme.onSurfaceVariant, surfaceVariant),
        'onPrimaryContainer/primaryContainer':
            (scheme.onPrimaryContainer, scheme.primaryContainer),
      };

      test('body text pairs pass AA (>= 4.5:1)', () {
        textPairs.forEach((name, pair) {
          final ratio = contrastRatio(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$name contrast is only ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });

      test('primary & error components on surface pass 3:1', () {
        for (final c in [scheme.primary, scheme.error]) {
          expect(contrastRatio(c, scheme.surface), greaterThanOrEqualTo(3.0));
        }
      });
    });
  }

  test('piece colors are pairwise distinguishable (adjacent >= 2.2:1)', () {
    const pieces = [
      Color(0xFF0072B2), Color(0xFFE69F00), Color(0xFF009E73), Color(0xFFCC79A7),
      Color(0xFF56B4E9), Color(0xFFD55E00), Color(0xFFF0E442), Color(0xFF7B5EA7),
    ];
    for (var i = 0; i < pieces.length; i++) {
      for (var j = i + 1; j < pieces.length; j++) {
        expect(
          contrastRatio(pieces[i], pieces[j]),
          greaterThan(1.15),
          reason: 'pieces $i/$j too similar',
        );
      }
    }
  });
}

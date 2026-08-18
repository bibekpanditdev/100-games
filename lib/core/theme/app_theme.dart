/// App-wide Material 3 themes — clean, minimalist, white/cream.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Light scheme — Premium White & Cream.
  static const primaryLight = Color(0xFF1A1A1A); // Sharp Black for contrast
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const secondaryLight = Color(0xFF4A4A4A);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const backgroundLight = Color(0xFFF9F7F0); // Elegant Cream
  static const onSurfaceLight = Color(0xFF1C1C1E);
  static const outlineLight = Color(0xFFE5E5E7);

  // Dark scheme — Refined Midnight.
  static const primaryDark = Color(0xFFBAC3FF);
  static const onPrimaryDark = Color(0xFF1B2370);
  static const secondaryDark = Color(0xFFFFB864);
  static const surfaceDark = Color(0xFF121318);
  static const onSurfaceDark = Color(0xFFE4E2EC);
  static const surfaceVariantDark = Color(0xFF232433);
  static const onSurfaceVariantDark = Color(0xFFC7C5D4);
  static const outlineDark = Color(0xFF918F9A);
}

ThemeData buildLightTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primaryLight,
    onPrimary: AppColors.onPrimaryLight,
    secondary: AppColors.secondaryLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onSurfaceLight,
    outline: AppColors.outlineLight,
  );
  return _base(scheme);
}

ThemeData buildDarkTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimaryDark,
    secondary: AppColors.secondaryDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
    surfaceContainerHighest: AppColors.surfaceVariantDark,
    onSurfaceVariant: AppColors.onSurfaceVariantDark,
    outline: AppColors.outlineDark,
  );
  return _base(scheme);
}

ThemeData _base(ColorScheme scheme) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
  );
  
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: scheme.brightness == Brightness.light ? AppColors.backgroundLight : scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.brightness == Brightness.light ? AppColors.backgroundLight : scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: scheme.onSurface,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.1), width: 1),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: StadiumBorder(side: BorderSide(color: scheme.outline.withValues(alpha: 0.5), width: 1)),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurface),
    ),
  );
}

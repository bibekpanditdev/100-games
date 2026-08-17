/// App-wide Material 3 themes.
///
/// All token pairs below are verified against WCAG AA in
/// `test/unit/theme_contrast_test.dart` (4.5:1 for text, 3:1 for large
/// text / UI components). Change colors there AND in the test together.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // Light scheme — hand-picked, contrast-checked.
  static const primaryLight = Color(0xFF2F3A8F);
  static const onPrimaryLight = Color(0xFFFFFFFF);
  static const primaryContainerLight = Color(0xFFDDE1FF);
  static const onPrimaryContainerLight = Color(0xFF101442);
  static const secondaryLight = Color(0xFF7A4E00);
  static const onSecondaryLight = Color(0xFFFFFFFF);
  static const tertiaryLight = Color(0xFF8A4A00);
  static const onTertiaryLight = Color(0xFFFFFFFF);
  static const errorLight = Color(0xFFB3261E);
  static const onErrorLight = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFFDFDFF);
  static const onSurfaceLight = Color(0xFF1A1B22);
  static const surfaceVariantLight = Color(0xFFE4E1EC);
  static const onSurfaceVariantLight = Color(0xFF46464F);
  static const outlineLight = Color(0xFF777680);

  // Dark scheme — hand-picked, contrast-checked.
  static const primaryDark = Color(0xFFBAC3FF);
  static const onPrimaryDark = Color(0xFF1B2370);
  static const primaryContainerDark = Color(0xFF3A42A0);
  static const onPrimaryContainerDark = Color(0xFFE4E6FF);
  static const secondaryDark = Color(0xFFFFB864);
  static const onSecondaryDark = Color(0xFF2C1A00);
  static const tertiaryDark = Color(0xFFFFB77C);
  static const onTertiaryDark = Color(0xFF2E1500);
  static const errorDark = Color(0xFFFFB4AB);
  static const onErrorDark = Color(0xFF370004);
  static const surfaceDark = Color(0xFF121318);
  static const onSurfaceDark = Color(0xFFE4E2EC);
  static const surfaceVariantDark = Color(0xFF232433);
  static const onSurfaceVariantDark = Color(0xFFC7C5D4);
  static const outlineDark = Color(0xFF918F9A);
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.light(
    primary: AppColors.primaryLight,
    onPrimary: AppColors.onPrimaryLight,
    primaryContainer: AppColors.primaryContainerLight,
    onPrimaryContainer: AppColors.onPrimaryContainerLight,
    secondary: AppColors.secondaryLight,
    onSecondary: AppColors.onSecondaryLight,
    tertiary: AppColors.tertiaryLight,
    onTertiary: AppColors.onTertiaryLight,
    error: AppColors.errorLight,
    onError: AppColors.onErrorLight,
    surface: AppColors.surfaceLight,
    onSurface: AppColors.onSurfaceLight,
    surfaceContainerHighest: AppColors.surfaceVariantLight,
    onSurfaceVariant: AppColors.onSurfaceVariantLight,
    outline: AppColors.outlineLight,
  );
  return _base(scheme);
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimaryDark,
    primaryContainer: AppColors.primaryContainerDark,
    onPrimaryContainer: AppColors.onPrimaryContainerDark,
    secondary: AppColors.secondaryDark,
    onSecondary: AppColors.onSecondaryDark,
    tertiary: AppColors.tertiaryDark,
    onTertiary: AppColors.onTertiaryDark,
    error: AppColors.errorDark,
    onError: AppColors.onErrorDark,
    surface: AppColors.surfaceDark,
    onSurface: AppColors.onSurfaceDark,
    surfaceContainerHighest: AppColors.surfaceVariantDark,
    onSurfaceVariant: AppColors.onSurfaceVariantDark,
    outline: AppColors.outlineDark,
  );
  return _base(scheme);
}

ThemeData _base(ColorScheme scheme) {
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: TextStyle(fontFamily: 'Inter', color: scheme.onSurfaceVariant),
      side: BorderSide(color: scheme.outline),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
  );
}

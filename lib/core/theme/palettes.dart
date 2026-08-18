/// Game palettes — clean, modern, and high-quality.
library;

import 'package:flutter/material.dart';

/// Okabe–Ito based, colour-blind-safe piece colours.
const List<Color> kPieceColors = [
  Color(0xFF2F3A8F), // Deep Blue
  Color(0xFF7A4E00), // Rich Gold
  Color(0xFF006D5B), // Deep Teal
  Color(0xFF8E24AA), // Deep Purple
  Color(0xFFD84315), // Burnt Orange
  Color(0xFF33691E), // Forest Green
  Color(0xFF455A64), // Blue Grey
  Color(0xFF000000), // Sharp Black
];

class GamePalette {
  const GamePalette({
    required this.id,
    required this.name,
    required this.accent,
    required this.boardA,
    required this.boardB,
    required this.backgroundLight,
    required this.backgroundDark,
  });

  final String id;
  final String name;
  final Color accent;
  final Color boardA;
  final Color boardB;
  final Color backgroundLight;
  final Color backgroundDark;

  Color get foreground => contrastOn(backgroundDark);
  static Color contrastOn(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF1C1C1E) : Colors.white;
  Color get surface => backgroundLight;

  LinearGradient get bgGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundLight, backgroundLight.withValues(alpha: 0.95)],
      );
}

const List<GamePalette> kPalettes = [
  GamePalette(id: 'classic', name: 'Studio', accent: Color(0xFF1A1A1A), boardA: Color(0xFFF5F5F5), boardB: Color(0xFFE8E8E8), backgroundLight: Color(0xFFFFFFFF), backgroundDark: Color(0xFF121212)),
  GamePalette(id: 'cream', name: 'Paper', accent: Color(0xFF5D4037), boardA: Color(0xFFFFF9E1), boardB: Color(0xFFF3E5AB), backgroundLight: Color(0xFFFFFDF0), backgroundDark: Color(0xFF1B1B15)),
  GamePalette(id: 'ivory', name: 'Ivory', accent: Color(0xFF455A64), boardA: Color(0xFFFDFDF0), boardB: Color(0xFFF5F5DC), backgroundLight: Color(0xFFFFFFFA), backgroundDark: Color(0xFF1B1B10)),
  GamePalette(id: 'soft_blue', name: 'Mist', accent: Color(0xFF3949AB), boardA: Color(0xFFE8EAF6), boardB: Color(0xFFC5CAE9), backgroundLight: Color(0xFFF5F6FF), backgroundDark: Color(0xFF0D1224)),
  GamePalette(id: 'mint', name: 'Botanical', accent: Color(0xFF004D40), boardA: Color(0xFFE0F2F1), boardB: Color(0xFFB2DFDB), backgroundLight: Color(0xFFF5FFFE), backgroundDark: Color(0xFF051815)),
  GamePalette(id: 'slate', name: 'Industrial', accent: Color(0xFF263238), boardA: Color(0xFFECEFF1), boardB: Color(0xFFCFD8DC), backgroundLight: Color(0xFFF8FAFB), backgroundDark: Color(0xFF101416)),
];

GamePalette paletteById(String id) =>
    kPalettes.firstWhere((p) => p.id == id, orElse: () => kPalettes.first);

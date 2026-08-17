/// Game palettes — the "skins" that turn one engine template into hundreds
/// of visually distinct game variants without shipping per-game assets.
///
/// Piece colors use the Okabe–Ito colour-blind-safe palette everywhere.
/// Game pieces additionally vary by shape in the engines, so colour is never
/// the only distinguishing channel (WCAG / CVD redundancy).
library;

import 'package:flutter/material.dart';

/// Okabe–Ito based, colour-blind-safe piece colours (constant across
/// palettes so players can rely on a stable mental model).
const List<Color> kPieceColors = [
  Color(0xFF0072B2), // blue
  Color(0xFFE69F00), // orange
  Color(0xFF009E73), // bluish green
  Color(0xFFCC79A7), // reddish purple
  Color(0xFF56B4E9), // sky blue
  Color(0xFFD55E00), // vermillion
  Color(0xFFF0E442), // yellow
  Color(0xFF7B5EA7), // purple
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

  /// Human name used to compose game titles (e.g. "Neon Snake").
  final String name;

  /// Accent / player colour. Used for chips, highlights and the player's
  /// piece. Pair with [onAccent] for text/icons on top of it.
  final Color accent;

  /// Checker/alternate board tile colours.
  final Color boardA;
  final Color boardB;

  final Color backgroundLight;
  final Color backgroundDark;

  /// Black or white — whichever reads better on [c] (WCAG-aware).
  static Color contrastOn(Color c) => c.computeLuminance() > 0.45 ? const Color(0xFF15151E) : Colors.white;
}

const List<GamePalette> kPalettes = [
  GamePalette(id: 'ocean', name: 'Ocean', accent: Color(0xFF0277BD), boardA: Color(0xFFB3E5FC), boardB: Color(0xFF81D4FA), backgroundLight: Color(0xFFE1F5FE), backgroundDark: Color(0xFF0D1B26)),
  GamePalette(id: 'sunset', name: 'Sunset', accent: Color(0xFFD84315), boardA: Color(0xFFFFCCBC), boardB: Color(0xFFFFAB91), backgroundLight: Color(0xFFFBE9E7), backgroundDark: Color(0xFF24110B)),
  GamePalette(id: 'forest', name: 'Forest', accent: Color(0xFF2E7D32), boardA: Color(0xFFC8E6C9), boardB: Color(0xFFA5D6A7), backgroundLight: Color(0xFFE8F5E9), backgroundDark: Color(0xFF0E1A10)),
  GamePalette(id: 'neon', name: 'Neon', accent: Color(0xFF00B8D4), boardA: Color(0xFF18FFFF), boardB: Color(0xFF00E5FF), backgroundLight: Color(0xFFE0F7FA), backgroundDark: Color(0xFF0A1416)),
  GamePalette(id: 'candy', name: 'Candy', accent: Color(0xFFC2185B), boardA: Color(0xFFF8BBD0), boardB: Color(0xFFF48FB1), backgroundLight: Color(0xFFFDE7EF), backgroundDark: Color(0xFF22101A)),
  GamePalette(id: 'desert', name: 'Desert', accent: Color(0xFF9E6003), boardA: Color(0xFFFFE082), boardB: Color(0xFFFFD54F), backgroundLight: Color(0xFFFFF8E1), backgroundDark: Color(0xFF1D1608)),
  GamePalette(id: 'arctic', name: 'Arctic', accent: Color(0xFF39679E), boardA: Color(0xFFE1F5FE), boardB: Color(0xFFECEFF1), backgroundLight: Color(0xFFF5F9FC), backgroundDark: Color(0xFF101820)),
  GamePalette(id: 'space', name: 'Space', accent: Color(0xFF7E57C2), boardA: Color(0xFF311B92), boardB: Color(0xFF4527A0), backgroundLight: Color(0xFFEDE7F6), backgroundDark: Color(0xFF0B0817)),
  GamePalette(id: 'cherry', name: 'Cherry', accent: Color(0xFFB71C1C), boardA: Color(0xFFFFCDD2), boardB: Color(0xFFEF9A9A), backgroundLight: Color(0xFFFDECEE), backgroundDark: Color(0xFF210809)),
  GamePalette(id: 'mint', name: 'Mint', accent: Color(0xFF00796B), boardA: Color(0xFFB2DFDB), boardB: Color(0xFF80CBC4), backgroundLight: Color(0xFFE0F2F1), backgroundDark: Color(0xFF08201C)),
  GamePalette(id: 'royal', name: 'Royal', accent: Color(0xFF303F9F), boardA: Color(0xFFC5CAE9), boardB: Color(0xFF9FA8DA), backgroundLight: Color(0xFFE8EAF6), backgroundDark: Color(0xFF0C0F24)),
  GamePalette(id: 'amber', name: 'Amber', accent: Color(0xFF8D5A00), boardA: Color(0xFFFFECB3), boardB: Color(0xFFFFE082), backgroundLight: Color(0xFFFFF8E1), backgroundDark: Color(0xFF1C1506)),
  GamePalette(id: 'lagoon', name: 'Lagoon', accent: Color(0xFF00838F), boardA: Color(0xFFB2EBF2), boardB: Color(0xFF80DEEA), backgroundLight: Color(0xFFE0F7FA), backgroundDark: Color(0xFF072226)),
  GamePalette(id: 'volcano', name: 'Volcano', accent: Color(0xFFBF360C), boardA: Color(0xFFFFCCBC), boardB: Color(0xFFFF8A65), backgroundLight: Color(0xFFFBE9E7), backgroundDark: Color(0xFF1F0C05)),
  GamePalette(id: 'glacier', name: 'Glacier', accent: Color(0xFF455A64), boardA: Color(0xFFCFD8DC), boardB: Color(0xFFB0BEC5), backgroundLight: Color(0xFFECEFF1), backgroundDark: Color(0xFF111517)),
  GamePalette(id: 'meadow', name: 'Meadow', accent: Color(0xFF558B2F), boardA: Color(0xFFDCEDC8), boardB: Color(0xFFC5E1A5), backgroundLight: Color(0xFFF1F8E9), backgroundDark: Color(0xFF131C0B)),
  GamePalette(id: 'midnight', name: 'Midnight', accent: Color(0xFF1A237E), boardA: Color(0xFF283593), boardB: Color(0xFF3949AB), backgroundLight: Color(0xFFE8EAF6), backgroundDark: Color(0xFF05071E)),
  GamePalette(id: 'coral', name: 'Coral', accent: Color(0xFFD84315), boardA: Color(0xFFFFE0B2), boardB: Color(0xFFFFCC80), backgroundLight: Color(0xFFFBE9E7), backgroundDark: Color(0xFF1D0E08)),
  GamePalette(id: 'violet', name: 'Violet', accent: Color(0xFF6A1B9A), boardA: Color(0xFFE1BEE7), boardB: Color(0xFFCE93D8), backgroundLight: Color(0xFFF3E5F5), backgroundDark: Color(0xFF16091F)),
  GamePalette(id: 'storm', name: 'Storm', accent: Color(0xFF37474F), boardA: Color(0xFFB0BEC5), boardB: Color(0xFF90A4AE), backgroundLight: Color(0xFFECEFF1), backgroundDark: Color(0xFF0D1114)),
  GamePalette(id: 'honey', name: 'Honey', accent: Color(0xFF8D6E00), boardA: Color(0xFFFFF3C4), boardB: Color(0xFFFFE57F), backgroundLight: Color(0xFFFFFDE7), backgroundDark: Color(0xFF1B1704)),
  GamePalette(id: 'jade', name: 'Jade', accent: Color(0xFF00695C), boardA: Color(0xFFB9F6CA), boardB: Color(0xFF69F0AE), backgroundLight: Color(0xFFE0F2F1), backgroundDark: Color(0xFF07211D)),
  GamePalette(id: 'tulip', name: 'Tulip', accent: Color(0xFFAD1457), boardA: Color(0xFFFCE4EC), boardB: Color(0xFFF8BBD0), backgroundLight: Color(0xFFFDF2F6), backgroundDark: Color(0xFF1F0812)),
  GamePalette(id: 'steel', name: 'Steel', accent: Color(0xFF455A64), boardA: Color(0xFFCFD8DC), boardB: Color(0xFF90A4AE), backgroundLight: Color(0xFFECEFF1), backgroundDark: Color(0xFF11171A)),
  GamePalette(id: 'ember', name: 'Ember', accent: Color(0xFFE65100), boardA: Color(0xFFFFE0B2), boardB: Color(0xFFFFB74D), backgroundLight: Color(0xFFFBE9E7), backgroundDark: Color(0xFF1A0C03)),
  GamePalette(id: 'tundra', name: 'Tundra', accent: Color(0xFF546E7A), boardA: Color(0xFFE0E0E0), boardB: Color(0xFFBDBDBD), backgroundLight: Color(0xFFECEFF1), backgroundDark: Color(0xFF101416)),
  GamePalette(id: 'rally', name: 'Rally', accent: Color(0xFF0097A7), boardA: Color(0xFFB2EBF2), boardB: Color(0xFF4DD0E1), backgroundLight: Color(0xFFE0F7FA), backgroundDark: Color(0xFF062024)),
  GamePalette(id: 'orchid', name: 'Orchid', accent: Color(0xFF7B1FA2), boardA: Color(0xFFE1BEE7), boardB: Color(0xFFBA68C8), backgroundLight: Color(0xFFF3E5F5), backgroundDark: Color(0xFF170A20)),
  GamePalette(id: 'citrus', name: 'Citrus', accent: Color(0xFF9E9D24), boardA: Color(0xFFF0F4C3), boardB: Color(0xFFDCE775), backgroundLight: Color(0xFFF9FBE7), backgroundDark: Color(0xFF151704)),
  GamePalette(id: 'harbor', name: 'Harbor', accent: Color(0xFF01579B), boardA: Color(0xFFB3E5FC), boardB: Color(0xFF4FC3F7), backgroundLight: Color(0xFFE1F5FE), backgroundDark: Color(0xFF04121F)),
];

/// Looks up a palette by id, falling back to the first palette so a bad
/// manifest entry can never crash the game.
GamePalette paletteById(String id) =>
    kPalettes.firstWhere((p) => p.id == id, orElse: () => kPalettes.first);

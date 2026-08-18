/// Game thumbnails.
///
/// Shipping 1,400 bitmap assets is a non-starter (APK size, per §7 of the
/// spec), so thumbnails render procedurally: palette gradient + template
/// glyph + difficulty pips. A manifest may still set `thumbnail` to an
/// asset path (e.g. WebP) which then takes precedence.
library;

import 'package:flutter/material.dart';

import '../../core/theme/palettes.dart';
import '../../features/catalog/domain/game_definition.dart';

IconData templateGlyph(String template) => switch (template) {
      'snake' => Icons.gesture,
      'breakout' => Icons.view_module,
      'whack_a_mole' => Icons.touch_app,
      'tap_reflex' => Icons.flash_on,
      'dodge_runner' => Icons.fast_forward,
      'match3' => Icons.blur_on,
      'sliding_puzzle' => Icons.extension,
      'block_fall' => Icons.layers,
      'word_search' => Icons.search,
      'memory_match' => Icons.style,
      'higher_lower' => Icons.compare_arrows,
      'blackjack' => Icons.casino,
      'tic_tac_toe' => Icons.grid_3x3,
      'connect_four' => Icons.blur_circular,
      'dots_and_boxes' => Icons.apps,
      'trivia' => Icons.quiz,
      'sudoku' => Icons.grid_4x4,
      'minesweeper' => Icons.warning_amber,
      'merge2048' => Icons.merge_type,
      'math_sprint' => Icons.calculate,
      'maze' => Icons.route,
      'pipes' => Icons.settings_input_component,
      'hangman' => Icons.text_fields,
      'wordle_daily' => Icons.spellcheck,
      'simon' => Icons.radio_button_on,
      'pattern_recall' => Icons.visibility,
      'odd_one_out' => Icons.category,
      _ => Icons.videogame_asset,
    };

class GameThumbnail extends StatelessWidget {
  const GameThumbnail({super.key, required this.definition, this.size});

  final GameDefinition definition;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final palette = paletteById(definition.themeId);
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget child;
    if (definition.thumbnail != null) {
      child = Image.asset(
        definition.thumbnail!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CustomPaint(
          painter: _ThumbnailPainter(
            palette: palette,
            background: dark ? palette.backgroundDark : palette.backgroundLight,
            glyph: templateGlyph(definition.template),
            difficultyIndex: definition.difficulty.index + 1,
            dark: dark,
          ),
          size: Size.infinite,
        ),
      );
    } else {
      child = CustomPaint(
        painter: _ThumbnailPainter(
          palette: palette,
          background: dark ? palette.backgroundDark : palette.backgroundLight,
          glyph: templateGlyph(definition.template),
          difficultyIndex: definition.difficulty.index + 1,
          dark: dark,
        ),
        size: Size.infinite,
      );
    }
    return SizedBox(width: size, height: size, child: child);
  }
}

class _ThumbnailPainter extends CustomPainter {
  _ThumbnailPainter({
    required this.palette,
    required this.background,
    required this.glyph,
    required this.difficultyIndex,
    required this.dark,
  });

  final GamePalette palette;
  final Color background;
  final IconData glyph;
  final int difficultyIndex;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect, Paint()..color = background);

    // Accent wash from the top-left corner.
    final wash = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.accent.withOpacity(dark ? 0.55 : 0.30),
          palette.accent.withOpacity(0.0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, wash);

    // Subtle board checker texture.
    final checker = Paint()..color = palette.boardB.withOpacity(dark ? 0.22 : 0.45);
    const cell = 9.0;
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        if (((x ~/ cell) + (y ~/ cell)) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), checker);
        }
      }
    }

    // Template glyph (Material icon font glyph).
    final glyphSize = size.shortestSide * 0.44;
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )
      ..text = TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(
          fontSize: glyphSize,
          fontFamily: glyph.fontFamily,
          package: glyph.fontPackage,
          color: palette.accent,
        ),
      )
      ..layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2 - size.height * 0.05,
      ),
    );

    // Difficulty pips along the bottom.
    final pipRadius = size.shortestSide * 0.035;
    final pipGap = pipRadius * 3.2;
    final totalWidth = 3 * pipRadius * 2 + 2 * (pipGap - pipRadius * 2);
    var cx = (size.width - totalWidth) / 2 + pipRadius;
    for (var i = 0; i < 3; i++) {
      final filled = i < difficultyIndex;
      final pip = Paint()
        ..color = filled
            ? palette.accent
            : (dark ? Colors.white24 : Colors.black12);
      canvas.drawCircle(
        Offset(cx, size.height - pipRadius * 2.6),
        filled ? pipRadius : pipRadius * 0.7,
        pip,
      );
      cx += pipGap;
    }
  }

  @override
  bool shouldRepaint(_ThumbnailPainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.dark != dark ||
      oldDelegate.glyph != glyph ||
      oldDelegate.difficultyIndex != difficultyIndex;
}

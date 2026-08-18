/// High-end procedural game thumbnails + Real Image integration.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/palettes.dart';
import '../../features/catalog/domain/game_definition.dart';

IconData templateGlyph(String template) => switch (template) {
      'snake' => Icons.gesture_rounded,
      'breakout' => Icons.view_module_rounded,
      'dodge_runner' => Icons.directions_car_rounded,
      'match3' => Icons.auto_awesome_rounded,
      'sudoku' => Icons.grid_4x4_rounded,
      'merge2048' => Icons.merge_type_rounded,
      'quick_tap' => Icons.ads_click_rounded,
      'color_match' => Icons.palette_rounded,
      'tic_tac_toe' => Icons.grid_3x3_rounded,
      'minesweeper' => Icons.warning_rounded,
      'cloud_glider' => Icons.wb_cloudy_rounded,
      'connect_four' => Icons.blur_circular_rounded,
      'dots_and_boxes' => Icons.apps_rounded,
      _ => Icons.videogame_asset_rounded,
    };

String categoryKeywords(GameCategory cat) => switch (cat) {
      GameCategory.arcade => 'game,neon,action',
      GameCategory.puzzle => 'puzzle,logic,minimal',
      GameCategory.cards => 'cards,poker,casino',
      GameCategory.board => 'board,chess,strategy',
      GameCategory.mind => 'brain,abstract,geometric',
      _ => 'game',
    };

class GameThumbnail extends StatelessWidget {
  const GameThumbnail({super.key, required this.definition, this.size});

  final GameDefinition definition;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final palette = paletteById(definition.themeId);
    
    // Using high-quality real images from Unsplash source API.
    final fallbackUrl = 'https://source.unsplash.com/featured/400x400/?${categoryKeywords(definition.category)},game&${definition.id.hashCode}';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Real Background Image
          Image.network(
            fallbackUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            },
            errorBuilder: (_, __, ___) => _ProceduralLayer(definition: definition),
          ),
          
          // 2. Premium Overlay (Gradient + Tint)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  palette.backgroundLight.withOpacity(0.1),
                  palette.backgroundLight.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // 3. Main Icon with Modern Styling
          Center(
            child: Icon(
              templateGlyph(definition.template),
              size: (size ?? 100) * 0.4,
              color: palette.accent,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.2), offset: const Offset(0, 4), blurRadius: 10),
              ],
            ),
          ),
          
          // 4. Level Badge
          Positioned(
            left: 10, top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'L${definition.level}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProceduralLayer extends StatelessWidget {
  const _ProceduralLayer({required this.definition});
  final GameDefinition definition;

  @override
  Widget build(BuildContext context) {
    final palette = paletteById(definition.themeId);
    return CustomPaint(
      painter: _ProceduralPainter(
        palette: palette,
        seed: definition.id.hashCode,
      ),
    );
  }
}

class _ProceduralPainter extends CustomPainter {
  _ProceduralPainter({required this.palette, required this.seed});
  final GamePalette palette;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rand = Random(seed);
    final rect = Offset.zero & size;
    final paint = Paint();
    
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [palette.backgroundLight, palette.accent.withOpacity(0.2)],
    );
    canvas.drawRect(rect, paint..shader = bgGradient.createShader(rect));
    
    paint.shader = null;
    for (var i = 0; i < 5; i++) {
      paint.color = palette.accent.withOpacity(rand.nextDouble() * 0.1);
      canvas.drawCircle(
        Offset(rand.nextDouble() * size.width, rand.nextDouble() * size.height),
        rand.nextDouble() * size.width * 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProceduralPainter oldDelegate) => false;
}

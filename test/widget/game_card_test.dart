/// GameCard widget tests (pure widget, no providers).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/core/theme/app_theme.dart';
import 'package:thousand_games/features/catalog/domain/game_definition.dart';
import 'package:thousand_games/features/catalog/presentation/widgets/game_card.dart';
import 'package:thousand_games/shared/widgets/star_rating.dart';

GameDefinition _def() => const GameDefinition(
      id: 'match3_neon_medium',
      title: 'Neon Match Plus',
      category: GameCategory.puzzle,
      template: 'match3',
      difficulty: Difficulty.medium,
      themeId: 'neon',
      popularity: 42,
    );

Future<void> _pumpCard(
  WidgetTester tester, {
  bool compact = false,
  int playCount = 0,
  int? bestStars,
  VoidCallback? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildLightTheme(),
      home: Scaffold(
        body: Center(
          child: compact
              ? GameCard(
                  definition: _def(),
                  compact: true,
                  playCount: playCount,
                  bestStars: bestStars,
                  onTap: onTap,
                )
              : SizedBox(
                  width: 140,
                  height: 260,
                  child: GameCard(
                    definition: _def(),
                    playCount: playCount,
                    bestStars: bestStars,
                    onTap: onTap,
                  ),
                ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders title, chips and best stars', (tester) async {
    await _pumpCard(tester, playCount: 1200, bestStars: 2);

    expect(find.text('Neon Match Plus'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('Offline OK'), findsOneWidget);
    expect(find.text('1.2k'), findsOneWidget); // compactNumber(1200)
    expect(find.byType(StarRating), findsOneWidget);
  });

  testWidgets('hides the star rating when bestStars is null', (tester) async {
    await _pumpCard(tester);

    expect(find.byType(StarRating), findsNothing);
  });

  testWidgets('exposes an accessible button label and fires taps', (
    tester,
  ) async {
    var taps = 0;
    await _pumpCard(tester, bestStars: 3, onTap: () => taps++);

    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('Neon Match Plus, Puzzle, Medium')),
      findsOneWidget,
    );
    handle.dispose();

    await tester.tap(find.byType(GameCard));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('compact variant is a fixed 110x150 card', (tester) async {
    await _pumpCard(tester, compact: true, bestStars: 1);

    expect(
      tester.getSize(find.byType(GameCard)),
      const Size(GameCard.compactWidth, GameCard.compactHeight),
    );
    expect(find.text('Neon Match Plus'), findsOneWidget);
    expect(find.byType(StarRating), findsOneWidget);
  });
}

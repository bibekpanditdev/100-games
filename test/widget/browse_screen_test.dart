/// BrowseScreen widget tests: filtering, sorting and search.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/catalog/domain/game_definition.dart';
import 'package:thousand_games/features/catalog/presentation/browse_screen.dart';
import 'package:thousand_games/features/catalog/presentation/widgets/game_card.dart';

import '../helpers/test_container.dart';
import '../helpers/test_env.dart';

void main() {
  setUpAll(setupTestEnv);

  // Switches the sort menu to A-Z so the visible grid window (lazy
  // builder) starts at the alphabetically first titles, making
  // assertions deterministic. Popularity order is stable but opaque.
  Future<void> sortAZ(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A-Z').last);
    await tester.pumpAndSettle();
  }

  testWidgets('category and difficulty filters narrow the grid', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(tester, container, home: const BrowseScreen());
    await tester.pumpAndSettle();

    await sortAZ(tester);
    // Unfiltered: the alphabetically first card ('Amber Blackjack', cards)
    // and other categories are all present.
    expect(find.text('Amber Blackjack'), findsOneWidget);

    await tester.tap(find.text('Puzzle'));
    await tester.pumpAndSettle();
    expect(find.text('Amber Blocks'), findsOneWidget); // puzzle template
    expect(find.text('Amber Blackjack'), findsNothing); // cards template
    expect(find.text('Amber Snake'), findsNothing); // arcade template

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    expect(find.text('Amber Blocks'), findsNothing); // easy tier
    expect(find.text('Amber Blocks Turbo'), findsOneWidget); // hard tier

    // Deselecting both filters brings the full catalog back.
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Any'));
    await tester.pumpAndSettle();
    expect(find.text('Amber Blackjack'), findsOneWidget);
  });

  testWidgets('initialCategory and initialQuery pre-filter the grid', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(
      tester,
      container,
      home: const BrowseScreen(
        initialCategory: GameCategory.puzzle,
        initialQuery: 'slide',
      ),
    );
    await tester.pumpAndSettle();

    await sortAZ(tester);
    expect(find.text('Amber Slide'), findsOneWidget); // puzzle + query hit
    expect(find.text('Amber Blocks'), findsNothing); // fails the query
    expect(find.text('Amber Snake'), findsNothing); // wrong category
  });

  testWidgets('search field filters and shows the empty state', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(tester, container, home: const BrowseScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    // Gibberish query -> designed empty state.
    await tester.enterText(find.byType(TextField), 'zzzznothing');
    await tester.pumpAndSettle();
    expect(find.text('No games found'), findsOneWidget);
    expect(find.byType(GameCard), findsNothing);

    // Custom-manifest games are not merged in tests, so no specific title
    // is asserted here — just that a real term brings results back.
    await tester.enterText(find.byType(TextField), 'match');
    await tester.pumpAndSettle();
    expect(find.text('No games found'), findsNothing);
    expect(find.byType(GameCard), findsWidgets);

    // The empty state's clear action resets everything.
    await tester.enterText(find.byType(TextField), 'zzzznothing');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(GameCard), findsWidgets);
  });
}

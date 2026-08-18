/// HomeScreen widget tests against the real (in-memory) seeded catalog.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:game/core/routing.dart';
import 'package:game/features/catalog/domain/game_definition.dart';
import 'package:game/features/catalog/presentation/home_screen.dart';
import 'package:game/features/catalog/presentation/widgets/game_card.dart';
import 'package:game/shared/widgets/skeleton.dart';

import '../helpers/test_container.dart';
import '../helpers/test_env.dart';

void main() {
  setUpAll(setupTestEnv);

  testWidgets('shows header, category tabs and catalog content', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(tester, container, home: const HomeScreen());

    // Header and tab bar are static — visible before the catalog loads.
    expect(find.text('1000+ Games'), findsOneWidget);
    expect(find.text('Arcade'), findsOneWidget);
    expect(find.text('Puzzle'), findsOneWidget);
    expect(find.text('Trivia'), findsOneWidget);
    expect(find.byType(SkeletonCarousel), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byType(SkeletonGrid), findsNothing);
    expect(find.byType(GameCard), findsWidgets);
    expect(find.text('Daily Challenge'), findsOneWidget);
    expect(find.text('Popular'), findsOneWidget);

    // The "All games" preview grid is below the fold — scroll to it.
    await tester.dragUntilVisible(
      find.text('All games'),
      find.byType(CustomScrollView),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    expect(find.text('All games'), findsOneWidget);
    expect(find.text('Browse all'), findsOneWidget);
  });

  testWidgets('tapping a category tab opens browse with that category', (
    tester,
  ) async {
    final container = await buildTestContainer();
    final pushedArgs = <String, Object?>{};
    await pumpCatalogApp(
      tester,
      container,
      home: const HomeScreen(),
      onGenerateRoute: recordRoutes(pushedArgs),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arcade'));
    await tester.pumpAndSettle();

    expect(find.text('ROUTE_/browse'), findsOneWidget);
    expect(pushedArgs[Routes.browse], GameCategory.arcade);
  });

  testWidgets('tapping a game card opens the game route with the game id', (
    tester,
  ) async {
    final container = await buildTestContainer();
    final pushedArgs = <String, Object?>{};
    await pumpCatalogApp(
      tester,
      container,
      home: const HomeScreen(),
      onGenerateRoute: recordRoutes(pushedArgs),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(GameCard).first);
    await tester.tap(find.byType(GameCard).first);
    await tester.pumpAndSettle();

    expect(find.text('ROUTE_/game'), findsOneWidget);
    expect(pushedArgs[Routes.game], isA<String>().having(
      (id) => id.length,
      'length',
      greaterThan(0),
    ));
  });
}

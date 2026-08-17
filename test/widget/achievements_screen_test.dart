/// Widget tests for the Achievements screen (static catalog, fresh store).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/achievements/presentation/achievements_screen.dart';
import 'package:thousand_games/features/gamification/achievements/achievement_definitions.dart';

import '../helpers/test_container.dart';

/// The achievement-state provider resolves against in-memory SQLite (FFI),
/// which runs on the real event loop — each runAsync window lets one async
/// hop finish and the following pump renders the result.
Future<void> _settleStates(WidgetTester tester, {int cycles = 4}) async {
  for (var i = 0; i < cycles; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('renders the achievement grid from the static catalog', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(tester, container, home: const AchievementsScreen());
    await _settleStates(tester);

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('0 of ${kAchievements.length} unlocked'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);

    // The grid is lazy — scroll to a far item to prove it builds.
    await tester.scrollUntilVisible(find.text('Coin Collector'), 300);
    expect(find.text('Coin Collector'), findsOneWidget);
  });
}

/// Widget tests for the Leaderboards screen (empty local scores).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:game/features/leaderboards/presentation/leaderboards_screen.dart';

import '../helpers/test_container.dart';

/// The top-scores provider resolves against in-memory SQLite (FFI), which
/// runs on the real event loop — each runAsync window lets one async hop
/// finish and the following pump renders the result.
Future<void> _settleScores(WidgetTester tester, {int cycles = 4}) async {
  for (var i = 0; i < cycles; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('local tab shows the empty state without scores', (
    tester,
  ) async {
    final container = await buildTestContainer();
    await pumpCatalogApp(tester, container, home: const LeaderboardsScreen());
    await _settleScores(tester);

    expect(find.text('Leaderboards'), findsOneWidget);
    expect(find.text('No scores yet'), findsOneWidget);
    expect(find.text('Play a game to set your first record!'), findsOneWidget);
  });
}

/// Widget tests for the Settings screen: preference toggles and the
/// destructive reset flow (confirm dialog -> snackbar).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/core/services/feedback.dart';
import 'package:thousand_games/features/catalog/presentation/catalog_providers.dart';
import 'package:thousand_games/features/settings/presentation/settings_screen.dart';

import '../helpers/test_container.dart';

void main() {
  setUp(() {
    // Haptics/system sounds would hit the platform channel; keep them off
    // so taps stay pure logic in the test environment.
    AppFeedback.configure(hapticsOn: false, soundOn: false);
  });

  testWidgets('toggling the sound switch flips the controller state', (
    tester,
  ) async {
    final container = await buildTestContainer();
    final settings = container.read(settingsProvider);
    expect(settings.soundOn, isTrue);

    await pumpCatalogApp(tester, container, home: const SettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();

    expect(settings.soundOn, isFalse);
  });

  testWidgets('reset asks for confirmation, then shows a snackbar', (
    tester,
  ) async {
    final container = await buildTestContainer();
    final progress = container.read(progressProvider);
    progress.earnCoins(500);
    expect(progress.coins, 500);

    await pumpCatalogApp(tester, container, home: const SettingsScreen());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Reset all progress'), 200);
    await tester.tap(find.text('Reset all progress'));
    await tester.pumpAndSettle();
    expect(find.text('Reset all progress?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    // The reset awaits Hive + SQLite I/O, which resolves on the real event
    // loop — give each hop a runAsync window plus a frame to continue.
    for (var i = 0; i < 5; i++) {
      await tester
          .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.text('Progress reset'), findsOneWidget);
    expect(progress.coins, 0);

    // Let the snackbar auto-dismiss so no timer stays pending.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}

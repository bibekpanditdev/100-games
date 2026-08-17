import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/app.dart';

import 'helpers/test_container.dart';
import 'helpers/test_env.dart';

void main() {
  setUpAll(setupTestEnv);

  testWidgets('App root smoke test', (WidgetTester tester) async {
    final container = await buildTestContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ThousandGamesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ThousandGamesApp), findsOneWidget);
  });
}

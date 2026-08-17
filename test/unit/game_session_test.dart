/// GameSessionController contract tests — the API every engine relies on.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:thousand_games/features/catalog/domain/game_definition.dart';
import 'package:thousand_games/features/game_player/game_contracts.dart';

GameDefinition _def(Map<String, dynamic> config) => GameDefinition(
      id: 'test',
      title: 'Test',
      category: GameCategory.arcade,
      template: 'snake',
      difficulty: Difficulty.medium,
      themeId: 'neon',
      config: config,
    );

void main() {
  test('config typed getters fall back safely', () {
    final s = GameSessionController(
      definition: _def({'grid': 16, 'speed': 6.5, 'wrap': true, 'label': 'x'}),
    );
    expect(s.config.getInt('grid', 0), 16);
    expect(s.config.getDouble('speed', 0), 6.5);
    expect(s.config.getBool('wrap', false), isTrue);
    expect(s.config.getString('label', ''), 'x');
    expect(s.config.getInt('missing', 42), 42);
    expect(s.config.getDouble('grid', 0), 16.0);
    expect(s.config.getString('missing', 'fb'), 'fb');
  });

  test('unknown palette id falls back gracefully', () {
    final s = GameSessionController(definition: _def({}));
    addTearDown(s.dispose);
    expect(s.palette.id, isNotEmpty); // never throws
  });

  test('hud updates merge fields and notify listeners', () {
    final s = GameSessionController(definition: _def({}));
    addTearDown(s.dispose);
    var notifications = 0;
    s.addListener(() => notifications++);

    s.updateHud(score: 10, status: 'Length 4', detail: 'Speed 6');
    expect(s.hud.score, 10);
    expect(s.hud.status, 'Length 4');
    expect(notifications, 1);

    s.addScore(15);
    expect(s.hud.score, 25);
    expect(notifications, 2);

    // Merge keeps previous fields.
    s.updateHud(progress: 0.5);
    expect(s.hud.score, 25);
    expect(s.hud.status, 'Length 4');
    expect(s.hud.progress, 0.5);
  });

  test('finish is idempotent and unpauses irrelevant', () {
    final s = GameSessionController(definition: _def({}));
    addTearDown(s.dispose);

    s.finish(won: true, score: 99, stats: {'length': 12});
    expect(s.isFinished, isTrue);
    expect(s.outcome!.score, 99);
    expect(s.outcome!.won, isTrue);

    s.finish(won: false, score: 1);
    expect(s.outcome!.score, 99, reason: 'second finish ignored');
    expect(s.outcome!.won, isTrue);
  });

  test('pause toggles notify once per change', () {
    final s = GameSessionController(definition: _def({}));
    addTearDown(s.dispose);
    var notifications = 0;
    s.addListener(() => notifications++);

    s.setPaused(true);
    s.setPaused(true);
    expect(s.isPaused, isTrue);
    expect(notifications, 1);
    s.setPaused(false);
    expect(notifications, 2);
  });

  test('support handlers: no handler means declined, grant invokes callback', () async {
    final s = GameSessionController(definition: _def({}));
    addTearDown(s.dispose);

    expect(await s.requestHint(), isFalse);
    expect(await s.requestContinue(), isFalse);

    var hints = 0;
    var lives = 0;
    s.onHintGranted = () => hints++;
    s.onExtraLifeGranted = () => lives++;
    s.attachSupportHandlers(
      hint: () async {
        s.grantHint();
        return true;
      },
      continueRequest: () async {
        s.grantExtraLife();
        return true;
      },
    );

    expect(await s.requestHint(), isTrue);
    expect(hints, 1);
    expect(await s.requestContinue(), isTrue);
    expect(lives, 1);
  });
}

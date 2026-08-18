/// Adaptive difficulty heuristic tests (offline, on-device).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:game/features/catalog/domain/game_definition.dart';
import 'package:game/features/gamification/adaptive_difficulty.dart';

void main() {
  test('no suggestion without at least 3 results', () {
    expect(AdaptiveDifficulty.suggest(const []), isNull);
    expect(AdaptiveDifficulty.suggest(const [3]), isNull);
    expect(AdaptiveDifficulty.suggest(const [2, 3]), isNull);
  });

  test('strong recent results suggest stepping up', () {
    expect(AdaptiveDifficulty.suggest(const [3, 3, 2]), Difficulty.hard);
    expect(AdaptiveDifficulty.suggest(const [2, 3, 3, 3]), Difficulty.hard);
  });

  test('middling results suggest medium', () {
    expect(AdaptiveDifficulty.suggest(const [1, 2, 1]), Difficulty.medium);
    expect(AdaptiveDifficulty.suggest(const [2, 2, 2]), Difficulty.medium);
  });

  test('weak results suggest easy', () {
    expect(AdaptiveDifficulty.suggest(const [0, 1, 0]), Difficulty.easy);
    expect(AdaptiveDifficulty.suggest(const [1, 1, 0, 0]), Difficulty.easy);
  });

  test('only the last 5 results count', () {
    // Ancient 0-stars, recent 3-stars -> step up.
    expect(
      AdaptiveDifficulty.suggest(const [0, 0, 0, 3, 3, 3]),
      Difficulty.hard,
    );
    // Ancient 3-stars, recent 0-stars -> step down.
    expect(
      AdaptiveDifficulty.suggest(const [3, 3, 3, 0, 0, 0]),
      Difficulty.easy,
    );
  });
}

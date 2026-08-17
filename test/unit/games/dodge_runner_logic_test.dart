import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/arcade/dodge_runner/dodge_runner_logic.dart';

DodgeRunnerLogic makeLogic({
  int lanes = 3,
  int targetSec = 60,
  int seed = 1,
  double speedPerSec = 0.5,
}) =>
    DodgeRunnerLogic(
      lanes: lanes,
      targetSec: targetSec,
      random: Random(seed),
    )..speedPerSec = speedPerSec;

void main() {
  group('lane switching', () {
    test('starts the player in a centre lane', () {
      expect(makeLogic(lanes: 3).playerLane, 1);
      expect(makeLogic(lanes: 4).playerLane, 2);
    });

    test('moves one lane at a time within the bounds', () {
      final logic = makeLogic(lanes: 3);
      expect(logic.moveLane(-1), isTrue);
      expect(logic.playerLane, 0);
      expect(logic.moveLane(-1), isFalse); // left edge
      expect(logic.playerLane, 0);
      expect(logic.moveLane(1), isTrue);
      expect(logic.moveLane(1), isTrue);
      expect(logic.playerLane, 2);
      expect(logic.moveLane(1), isFalse); // right edge
      expect(logic.playerLane, 2);
    });

    test('lane switching stops once the run is over', () {
      final logic = makeLogic(lanes: 3);
      logic.obstacles.add(DodgeObstacle(
        lane: logic.playerLane,
        colorIndex: 0,
        y: DodgeRunnerLogic.playerY,
      ));
      logic.advance(0.01);
      expect(logic.isDead, isTrue);
      expect(logic.moveLane(1), isFalse);
    });
  });

  group('obstacles', () {
    test('spawn over time and scroll down the board', () {
      final logic = makeLogic(targetSec: 120);
      for (var i = 0; i < 20; i++) {
        logic.advance(0.1); // 2 seconds
      }
      expect(logic.obstacles, isNotEmpty);
      for (final obstacle in logic.obstacles) {
        expect(obstacle.lane, inInclusiveRange(0, logic.lanes - 1));
        expect(obstacle.y, lessThanOrEqualTo(1.25));
      }
    });

    test('obstacles past the bottom edge are removed', () {
      final logic = makeLogic(targetSec: 60);
      logic.obstacles.add(DodgeObstacle(lane: 0, colorIndex: 0, y: 1.3));
      logic.advance(0.01);
      expect(logic.obstacles, isEmpty);
    });

    test('rows never block every lane (fair for every seed)', () {
      for (final lanes in [3, 4]) {
        for (var seed = 1; seed <= 8; seed++) {
          final logic = makeLogic(lanes: lanes, seed: seed, targetSec: 120);
          for (var step = 0; step < 600; step++) {
            logic.advance(0.05);
            if (logic.isOver) break;
            // Any obstacle defines a row band; collect lanes in that band.
            for (final base in logic.obstacles) {
              final blockedLanes = logic.obstacles
                  .where((o) => (o.y - base.y).abs() < 0.095)
                  .map((o) => o.lane)
                  .toSet();
              expect(blockedLanes.length, lessThan(lanes),
                  reason: 'lanes $lanes seed $seed step $step');
            }
          }
        }
      }
    });

    test('same-row obstacles always sit in distinct lanes', () {
      final logic = makeLogic(lanes: 4, seed: 3, targetSec: 120);
      for (var step = 0; step < 400; step++) {
        logic.advance(0.05);
        if (logic.isOver) break;
        final byRow = <int, Set<int>>{};
        for (final o in logic.obstacles) {
          byRow.putIfAbsent((o.y * 100).round(), () => <int>{}).add(o.lane);
        }
        for (final lanes in byRow.values) {
          expect(lanes.length, lessThanOrEqualTo(2));
        }
      }
    });

    test('is deterministic for a fixed seed', () {
      List<String> trace(int seed) {
        final logic = makeLogic(lanes: 4, seed: seed, targetSec: 120);
        final out = <String>[];
        for (var i = 0; i < 200; i++) {
          logic.advance(0.05);
          out.add(logic.obstacles.map((o) => '${o.lane}:${o.y}').join(','));
        }
        return out;
      }

      expect(trace(9), trace(9));
      expect(trace(9), isNot(trace(10)));
    });
  });

  group('collision and survival', () {
    test('an obstacle reaching the player lane kills', () {
      final logic = makeLogic(lanes: 3);
      expect(logic.playerLane, 1);
      logic.obstacles.add(DodgeObstacle(
        lane: 1,
        colorIndex: 0,
        y: DodgeRunnerLogic.playerY,
      ));
      expect(logic.collides, isTrue);
      logic.advance(0.01);
      expect(logic.isDead, isTrue);
      expect(logic.isOver, isTrue);
    });

    test('an obstacle in a neighbouring lane passes harmlessly', () {
      final logic = makeLogic(lanes: 3);
      logic.obstacles.add(DodgeObstacle(
        lane: 0,
        colorIndex: 0,
        y: DodgeRunnerLogic.playerY,
      ));
      logic.advance(0.05);
      expect(logic.isDead, isFalse);
    });

    test('clearNearPlayer empties only the lower half', () {
      final logic = makeLogic(lanes: 3);
      logic.obstacles
        ..add(DodgeObstacle(lane: 0, colorIndex: 0, y: 0.3))
        ..add(DodgeObstacle(lane: 1, colorIndex: 1, y: 0.5))
        ..add(DodgeObstacle(lane: 2, colorIndex: 2, y: 0.9));
      logic.clearNearPlayer();
      expect(logic.obstacles.length, 1);
      expect(logic.obstacles.single.y, 0.3);
    });

    test('revive clears the danger zone and resumes', () {
      final logic = makeLogic(lanes: 3);
      logic.obstacles.add(DodgeObstacle(
        lane: 1,
        colorIndex: 0,
        y: DodgeRunnerLogic.playerY,
      ));
      logic.advance(0.01);
      expect(logic.isDead, isTrue);
      logic.revive();
      expect(logic.isDead, isFalse);
      logic.advance(0.1);
      expect(logic.isDead, isFalse); // nothing left near the player
    });

    test('surviving the target time wins and reports survivedSec', () {
      final logic = makeLogic(targetSec: 2, speedPerSec: 0.01);
      var guard = 0;
      while (!logic.isOver && guard < 500) {
        logic.advance(0.05);
        guard += 1;
      }
      expect(logic.survived, isTrue);
      expect(logic.isDead, isFalse);
      expect(logic.survivedSec, 2);
      expect(logic.won || logic.survived, isTrue);
    });

    test('remainingSec counts down from the target', () {
      final logic = makeLogic(targetSec: 10);
      expect(logic.remainingSec, 10);
      logic.advance(2.5);
      expect(logic.remainingSec, 7); // 7.5s left, displayed floor-down
      logic.advance(20);
      expect(logic.remainingSec, 0);
      expect(logic.survived, isTrue);
    });
  });
}

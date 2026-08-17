import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/arcade/breakout/breakout_logic.dart';

BreakoutLogic makeLogic({
  int rows = 4,
  double speed = 240,
  double width = 400,
  double height = 560,
  int seed = 1,
}) =>
    BreakoutLogic(
      rows: rows,
      boardWidth: width,
      boardHeight: height,
      speedPxPerSec: speed,
      random: Random(seed),
    );

void main() {
  group('brick layout', () {
    test('creates one brick per row/column cell', () {
      for (final rows in [4, 6, 8]) {
        final logic = makeLogic(rows: rows);
        expect(logic.bricks.length, rows * logic.cols, reason: '$rows rows');
        expect(logic.bricksRemaining, rows * logic.cols);
        expect(logic.bricks.every((b) => b.alive), isTrue);
      }
    });

    test('lays bricks in one distinct band per row near the top', () {
      final logic = makeLogic(rows: 6);
      final tops = logic.bricks.map((b) => b.top).toSet();
      expect(tops.length, 6);
      for (final brick in logic.bricks) {
        expect(brick.top, greaterThan(0));
        expect(brick.bottom, lessThan(logic.boardHeight * 0.5));
        expect(brick.left, greaterThanOrEqualTo(0));
        expect(brick.right, lessThanOrEqualTo(logic.boardWidth));
        expect(brick.width, greaterThan(0));
      }
    });

    test('brick colours cycle through the piece palette', () {
      final logic = makeLogic(rows: 4);
      final indices = logic.bricks.map((b) => b.colorIndex).toSet();
      expect(indices.length, 4 * logic.cols);
    });
  });

  group('paddle', () {
    test('clamps the paddle inside the walls', () {
      final logic = makeLogic();
      logic.movePaddleTo(0);
      expect(logic.paddleX, logic.paddleWidth / 2);
      logic.movePaddleTo(logic.boardWidth * 2);
      expect(logic.paddleX, logic.boardWidth - logic.paddleWidth / 2);
    });

    test('the ball rides the paddle until launched', () {
      final logic = makeLogic();
      expect(logic.ballLaunched, isFalse);
      logic.movePaddleTo(120);
      expect(logic.ballX, 120);
      logic.launch();
      expect(logic.ballLaunched, isTrue);
      expect(logic.ballVY, lessThan(0)); // leaves upward
    });

    test('a centre hit bounces straight up', () {
      final logic = makeLogic();
      logic.launch();
      logic.ballX = logic.paddleX;
      logic.ballY = logic.paddleTop - logic.ballRadius - 1;
      logic.ballVX = 0;
      logic.ballVY = 200;
      expect(logic.advance(0.05), BreakoutStepPhase.playing);
      expect(logic.ballVY, lessThan(0));
      expect(logic.ballVX.abs(), lessThan(0.001));
    });

    test('bounce angle varies with the hit position', () {
      final probe = makeLogic();
      final half = probe.paddleWidth / 2;
      double bounceVXAt(double offset) {
        final logic = makeLogic();
        logic.launch();
        logic.ballX = logic.paddleX + offset;
        logic.ballY = logic.paddleTop - logic.ballRadius - 1;
        logic.ballVX = 0;
        logic.ballVY = 200;
        logic.advance(0.05);
        expect(logic.ballVY, lessThan(0));
        return logic.ballVX;
      }

      final leftVX = bounceVXAt(-half);
      final centreVX = bounceVXAt(0);
      final rightVX = bounceVXAt(half);
      expect(leftVX, lessThan(0));
      expect(centreVX.abs(), lessThan(0.001));
      expect(rightVX, greaterThan(0));
      // Edge hits stay within the 60-degree cap.
      final maxVX = sin(BreakoutLogic.maxBounceAngle) * probe.ballSpeed;
      expect(rightVX, lessThan(maxVX + 0.001));
      expect(leftVX.abs(), lessThan(maxVX + 0.001));
    });
  });

  group('brick collisions', () {
    test('a head-on hit kills the brick and reflects the ball downward', () {
      final logic = makeLogic(rows: 4);
      final brick = logic.bricks.first;
      logic.launch();
      logic.ballX = brick.left + brick.width / 2;
      logic.ballY = brick.bottom + logic.ballRadius + 0.5;
      logic.ballVX = 0;
      logic.ballVY = -200; // climbing into the brick
      expect(logic.advance(0.02), BreakoutStepPhase.playing);
      expect(brick.alive, isFalse);
      expect(logic.bricksRemaining, 4 * logic.cols - 1);
      expect(logic.score, BreakoutLogic.brickPoints);
      expect(logic.ballVY, greaterThan(0)); // pushed back down
    });

    test('a side hit reflects the ball horizontally', () {
      final logic = makeLogic(rows: 4);
      final brick = logic.bricks.first;
      logic.launch();
      // Sitting left of the brick's face, aligned with its mid-height.
      logic.ballX = brick.left - logic.ballRadius * 0.2;
      logic.ballY = brick.top + brick.height / 2;
      logic.ballVX = 200; // driving into the brick's left side
      logic.ballVY = 0;
      logic.advance(0.01);
      expect(brick.alive, isFalse);
      expect(logic.ballVX, lessThan(0)); // bounced back out
      expect(logic.score, BreakoutLogic.brickPoints);
    });

    test('clearing every brick reports the cleared phase', () {
      final logic = makeLogic(rows: 4);
      for (final brick in logic.bricks) {
        brick.alive = false;
      }
      expect(logic.advance(0.01), BreakoutStepPhase.cleared);
    });
  });

  group('lives and continues', () {
    test('dropping the ball costs a life and re-sticks the ball', () {
      final logic = makeLogic();
      logic.launch();
      logic.ballX = logic.boardWidth / 2;
      logic.ballY = logic.boardHeight + 40;
      logic.ballVY = 300;
      expect(logic.advance(0.05), BreakoutStepPhase.lifeLost);
      expect(logic.lives, 2);
      expect(logic.ballLaunched, isFalse);
      expect(logic.isDefeated, isFalse);
    });

    test('grantExtraLife restores a life', () {
      final logic = makeLogic();
      logic.lives = 0;
      expect(logic.isDefeated, isTrue);
      logic.grantExtraLife();
      expect(logic.lives, 1);
      expect(logic.isDefeated, isFalse);
    });

    test('speed scales with board width relative to the 400px baseline', () {
      final narrow = makeLogic(width: 200, speed: 240);
      final wide = makeLogic(width: 800, speed: 240);
      expect(narrow.ballSpeed, closeTo(120, 0.001));
      expect(wide.ballSpeed, closeTo(480, 0.001));
    });
  });
}

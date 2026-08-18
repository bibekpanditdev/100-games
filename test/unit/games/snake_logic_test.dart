import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:game/features/games/arcade/snake/snake_logic.dart';

/// Head-first body of a fresh size-16 snake heading right.
SnakeLogic freshLogic({int size = 16, bool wrap = false, int seed = 1}) =>
    SnakeLogic(size: size, wrap: wrap, random: Random(seed));

/// Explicit-state snake (used for collision edge cases).
SnakeLogic stagedLogic({
  int size = 16,
  bool wrap = false,
  SnakeDirection direction = SnakeDirection.down,
  required List<Point<int>> cells,
  Point<int> food = const Point<int>(10, 10),
}) =>
    SnakeLogic.withState(
      size: size,
      wrap: wrap,
      cells: cells,
      direction: direction,
      food: food,
      random: Random(1),
    );

void main() {
  group('movement', () {
    test('starts as a three-cell snake heading right in the middle', () {
      final logic = freshLogic();
      expect(logic.length, 3);
      expect(logic.head, const Point(5, 8));
      expect(logic.body[1], const Point(4, 8));
      expect(logic.body[2], const Point(3, 8));
      expect(logic.direction, SnakeDirection.right);
      expect(logic.dead, isFalse);
    });

    test('tick moves the head one cell and drops the tail', () {
      final logic = freshLogic();
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.head, const Point(6, 8));
      expect(logic.length, 3);
      expect(logic.body, contains(const Point(5, 8)));
      expect(logic.body, isNot(contains(const Point(3, 8))));
    });

    test('dies on the wall when wrap is off', () {
      final logic = stagedLogic(
        size: 12,
        wrap: false,
        direction: SnakeDirection.left,
        cells: const [Point(0, 6), Point(1, 6), Point(2, 6)],
      );
      expect(logic.tick(), SnakeTickResult.died);
      expect(logic.dead, isTrue);
      // A dead snake stays dead.
      expect(logic.tick(), SnakeTickResult.died);
    });

    test('wraps around the edge when wrap is on', () {
      final logic = stagedLogic(
        size: 12,
        wrap: true,
        direction: SnakeDirection.left,
        cells: const [Point(0, 6), Point(1, 6), Point(2, 6)],
      );
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.head, const Point(11, 6));
      expect(logic.dead, isFalse);
    });
  });

  group('self collision', () {
    test('moving onto the vacating tail tip is legal', () {
      final logic = stagedLogic(
        direction: SnakeDirection.down,
        cells: const [
          Point(5, 8),
          Point(4, 8),
          Point(3, 8),
          Point(3, 9),
          Point(4, 9),
          Point(5, 9), // tail tip — vacates this tick
        ],
      );
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.dead, isFalse);
      expect(logic.head, const Point(5, 9));
      expect(logic.length, 6);
    });

    test('moving into the body behind the tail kills', () {
      final logic = stagedLogic(
        direction: SnakeDirection.down,
        cells: const [
          Point(5, 8),
          Point(4, 8),
          Point(3, 8),
          Point(3, 9),
          Point(4, 9),
          Point(5, 9),
          Point(6, 9), // real tail — (5,9) stays blocked
        ],
      );
      expect(logic.tick(), SnakeTickResult.died);
      expect(logic.dead, isTrue);
    });
  });

  group('food', () {
    test('eating grows the snake, scores 10 and respawns food', () {
      final logic = stagedLogic(
        direction: SnakeDirection.right,
        cells: const [Point(5, 8), Point(4, 8), Point(3, 8)],
        food: const Point(6, 8),
      );
      expect(logic.tick(), SnakeTickResult.ate);
      expect(logic.head, const Point(6, 8));
      expect(logic.length, 4);
      expect(logic.score, SnakeLogic.foodPoints);
      expect(logic.body.contains(logic.food), isFalse);
    });

    test('food always spawns on a free cell', () {
      for (var seed = 0; seed < 10; seed++) {
        final logic = SnakeLogic(size: 20, wrap: true, random: Random(seed));
        final turns = [
          SnakeDirection.up,
          SnakeDirection.left,
          SnakeDirection.down,
          SnakeDirection.right,
        ];
        var turn = 0;
        for (var i = 0; i < 600; i++) {
          if (i % 4 == 0) {
            logic.queueTurn(turns[turn % 4]);
            turn += 1;
          }
          final result = logic.tick();
          if (result == SnakeTickResult.died) break;
          expect(logic.body.contains(logic.food), isFalse,
              reason: 'seed $seed tick $i');
        }
      }
    });
  });

  group('direction queue', () {
    test('ignores reversals and duplicates of the current direction', () {
      final logic = freshLogic(); // heading right
      logic.queueTurn(SnakeDirection.left); // reversal
      logic.queueTurn(SnakeDirection.right); // duplicate
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.direction, SnakeDirection.right);
      expect(logic.head, const Point(6, 8));
    });

    test('buffers a quick double turn so it never reverses', () {
      final logic = freshLogic(); // heading right at (5, 8)
      logic.queueTurn(SnakeDirection.up);
      logic.queueTurn(SnakeDirection.left);
      expect(logic.effectiveDirection, SnakeDirection.up);
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.direction, SnakeDirection.up);
      expect(logic.head, const Point(5, 7));
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.direction, SnakeDirection.left);
      expect(logic.head, const Point(4, 7));
      expect(logic.dead, isFalse);
    });

    test('rejects a turn that would reverse the queued direction', () {
      final logic = freshLogic();
      logic.queueTurn(SnakeDirection.up);
      logic.queueTurn(SnakeDirection.down); // opposite of the queued 'up'
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.direction, SnakeDirection.up);
    });

    test('caps the buffer at two turns', () {
      final logic = freshLogic();
      logic.queueTurn(SnakeDirection.up);
      logic.queueTurn(SnakeDirection.left);
      logic.queueTurn(SnakeDirection.up); // dropped — buffer is full
      logic.tick(); // up
      logic.tick(); // left
      expect(logic.tick(), SnakeTickResult.moved);
      expect(logic.direction, SnakeDirection.left); // still left, no third
      expect(logic.head, const Point(3, 7));
    });

    test('ignores turns once dead', () {
      final logic = stagedLogic(
        size: 12,
        wrap: false,
        direction: SnakeDirection.left,
        cells: const [Point(0, 6), Point(1, 6), Point(2, 6)],
      );
      expect(logic.tick(), SnakeTickResult.died);
      logic.queueTurn(SnakeDirection.right);
      expect(logic.effectiveDirection, SnakeDirection.left);
    });
  });

  group('revive', () {
    test('resets the snake but keeps the score', () {
      final logic = stagedLogic(
        direction: SnakeDirection.right,
        cells: const [Point(5, 8), Point(4, 8), Point(3, 8)],
        food: const Point(6, 8),
      );
      expect(logic.tick(), SnakeTickResult.ate);
      expect(logic.score, 10);
      // Ride into the top wall.
      logic.queueTurn(SnakeDirection.up);
      var guard = 0;
      while (!logic.dead && guard < 50) {
        logic.tick();
        guard += 1;
      }
      expect(logic.dead, isTrue);
      logic.revive();
      expect(logic.dead, isFalse);
      expect(logic.length, 3);
      expect(logic.head, const Point(5, 8));
      expect(logic.direction, SnakeDirection.right);
      expect(logic.score, 10);
      expect(logic.body.contains(logic.food), isFalse);
    });
  });
}

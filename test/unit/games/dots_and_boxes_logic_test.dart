import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/board/dots_and_boxes/dots_and_boxes_logic.dart';

const _h = true;
const _v = false;

DotsAndBoxesLogic make({int size = 2, int aiLevel = 3, int seed = 1}) =>
    DotsAndBoxesLogic(size: size, aiLevel: aiLevel, random: Random(seed));

void main() {
  group('edge claiming', () {
    test('edges are claimed once and bounded by the grid', () {
      final logic = make();
      const edge = (horizontal: _h, row: 0, col: 0);
      expect(logic.isDrawn(edge), isFalse);
      expect(logic.drawEdge(edge, DotsAndBoxesLogic.player), 0);
      expect(logic.isDrawn(edge), isTrue);
      expect(logic.edgeOwner[edge], DotsAndBoxesLogic.player);
      // Re-drawing is a no-op.
      expect(logic.drawEdge(edge, DotsAndBoxesLogic.cpu), 0);
      expect(logic.edgeOwner[edge], DotsAndBoxesLogic.player);
      // Out-of-range edges are rejected by validation.
      expect(logic.isValidEdge((horizontal: _h, row: 2, col: 0)), isFalse);
      expect(logic.isValidEdge((horizontal: _v, row: 0, col: 2)), isFalse);
      expect(logic.isValidEdge((horizontal: _h, row: -1, col: 0)), isFalse);
      expect(logic.drawnEdges.length, 1);
    });

    test('adjacent boxes and edge counts around a box', () {
      final logic = make();
      expect(logic.edgesDrawnAround(0, 0), 0);
      logic.drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player);
      logic.drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player);
      expect(logic.edgesDrawnAround(0, 0), 2);
      expect(logic.edgesDrawnAround(0, 1), 1);
      expect(logic.edgesDrawnAround(1, 0), 0);
      expect(
        logic.adjacentBoxes((horizontal: _h, row: 0, col: 0)),
        [0],
      );
      expect(
        logic.adjacentBoxes((horizontal: _v, row: 0, col: 1)),
        unorderedEquals([0, 1]),
      );
    });
  });

  group('box completion', () {
    test('completing a box claims it and grants another turn', () {
      final logic = make();
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 1, col: 0), DotsAndBoxesLogic.player);
      expect(logic.turn, DotsAndBoxesLogic.player);
      final completed = logic.playEdge((horizontal: _v, row: 0, col: 1));
      expect(completed, isTrue);
      expect(logic.playerBoxes, 1);
      expect(logic.boxOwner[0], DotsAndBoxesLogic.player);
      expect(logic.turn, DotsAndBoxesLogic.player,
          reason: 'completing a box grants another turn');
    });

    test('a line that completes nothing passes the turn', () {
      final logic = make();
      expect(logic.playEdge((horizontal: _h, row: 0, col: 0)), isTrue);
      expect(logic.turn, DotsAndBoxesLogic.cpu);
      // Player cannot move out of turn.
      expect(logic.playEdge((horizontal: _h, row: 0, col: 1)), isFalse);
      expect(logic.cpuMove(), isNotNull);
      expect(logic.turn, DotsAndBoxesLogic.player);
    });

    test('a shared edge can complete two boxes at once', () {
      final logic = make();
      // Three edges around box (0,0) ...
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 1, col: 0), DotsAndBoxesLogic.player)
        // ... and three around box (0,1), missing the same shared edge.
        ..drawEdge((horizontal: _h, row: 0, col: 1), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 1, col: 1), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 2), DotsAndBoxesLogic.player);
      final completed =
          logic.drawEdge((horizontal: _v, row: 0, col: 1), DotsAndBoxesLogic.player);
      expect(completed, 2);
      expect(logic.playerBoxes, 2);
      expect(logic.boxOwner[1], DotsAndBoxesLogic.player);
    });
  });

  group('scoring and game over', () {
    test('boxes are scored per owner and the game ends when all are claimed',
        () {
      final logic = make();
      expect(logic.totalBoxes, 4);
      expect(logic.isGameOver, isFalse);
      // Player claims box (0,0).
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 1, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 1), DotsAndBoxesLogic.player);
      // CPU claims box (0,1).
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 1), DotsAndBoxesLogic.cpu)
        ..drawEdge((horizontal: _h, row: 1, col: 1), DotsAndBoxesLogic.cpu)
        ..drawEdge((horizontal: _v, row: 0, col: 2), DotsAndBoxesLogic.cpu);
      // Player claims the whole bottom row via the shared verticals.
      logic
        ..drawEdge((horizontal: _h, row: 2, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 1, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 1, col: 1), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 1, col: 2), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 2, col: 1), DotsAndBoxesLogic.player);
      expect(logic.playerBoxes, 3);
      expect(logic.cpuBoxes, 1);
      expect(logic.claimedBoxes, 4);
      expect(logic.isGameOver, isTrue);
      expect(logic.availableEdges, isEmpty);
    });
  });

  group('CPU', () {
    test('level 3 takes a free box and keeps the turn', () {
      final logic = make(aiLevel: 3);
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _h, row: 1, col: 0), DotsAndBoxesLogic.player)
        ..turn = DotsAndBoxesLogic.cpu;
      final edge = logic.cpuMove();
      expect(edge, (horizontal: _v, row: 0, col: 1));
      expect(logic.cpuBoxes, 1);
      expect(logic.turn, DotsAndBoxesLogic.cpu, reason: 'extra turn after box');
    });

    test('level 3 never gifts a free box while a safe edge exists', () {
      for (final level in [2, 3]) {
        for (var seed = 0; seed < 40; seed++) {
          final logic = make(aiLevel: level, seed: seed);
          // Box (0,0) has two edges; drawing either remaining edge of that
          // box would hand the opponent the third side.
          logic
            ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
            ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player)
            ..turn = DotsAndBoxesLogic.cpu;
          final edge = logic.cpuMove();
          expect(edge, isNotNull);
          expect(logic.givesAwayBox(edge!), isFalse,
              reason: 'level $level seed $seed gifted a free box');
          expect(logic.cpuBoxes, 0);
        }
      }
    });

    test('givesAwayBox and completesBox report edge danger correctly', () {
      final logic = make();
      logic
        ..drawEdge((horizontal: _h, row: 0, col: 0), DotsAndBoxesLogic.player)
        ..drawEdge((horizontal: _v, row: 0, col: 0), DotsAndBoxesLogic.player);
      expect(logic.givesAwayBox((horizontal: _h, row: 1, col: 0)), isTrue);
      expect(logic.givesAwayBox((horizontal: _v, row: 0, col: 1)), isTrue);
      expect(logic.givesAwayBox((horizontal: _h, row: 0, col: 1)), isFalse);
      expect(logic.givesAwayBox((horizontal: _v, row: 2, col: 2)), isFalse);
      logic.drawEdge((horizontal: _h, row: 1, col: 0), DotsAndBoxesLogic.player);
      expect(logic.completesBox((horizontal: _v, row: 0, col: 1)), isTrue);
      expect(logic.completesBox((horizontal: _h, row: 2, col: 0)), isFalse);
    });
  });
}

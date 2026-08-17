import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/mind/pipes/pipes_logic.dart';

void main() {
  group('tile rotation math', () {
    test('quarter turns rotate compass bits clockwise', () {
      expect(PipesLogic.rotateMask(PipeDirs.n, 0), PipeDirs.n);
      expect(PipesLogic.rotateMask(PipeDirs.n, 1), PipeDirs.e);
      expect(PipesLogic.rotateMask(PipeDirs.n, 2), PipeDirs.s);
      expect(PipesLogic.rotateMask(PipeDirs.n, 3), PipeDirs.w);
      expect(PipesLogic.rotateMask(PipeDirs.n, 4), PipeDirs.n);
      expect(PipesLogic.rotateMask(PipeDirs.w, 1), PipeDirs.n);
    });

    test('composite masks rotate as a whole', () {
      const elbowNE = PipeDirs.n | PipeDirs.e;
      expect(PipesLogic.rotateMask(elbowNE, 1), PipeDirs.e | PipeDirs.s);
      const straightNS = PipeDirs.n | PipeDirs.s;
      expect(PipesLogic.rotateMask(straightNS, 1), PipeDirs.e | PipeDirs.w);
      expect(PipesLogic.rotateMask(straightNS, 2), straightNS);
      const cross = PipeDirs.n | PipeDirs.e | PipeDirs.s | PipeDirs.w;
      expect(PipesLogic.rotateMask(cross, 1), cross);
      expect(PipesLogic.rotateMask(cross, 3), cross);
    });

    test('opposite and count helpers', () {
      expect(PipeDirs.opposite(PipeDirs.n), PipeDirs.s);
      expect(PipeDirs.opposite(PipeDirs.e), PipeDirs.w);
      expect(PipeDirs.count(PipeDirs.n | PipeDirs.s), 2);
      expect(PipeDirs.count(15), 4);
      expect(PipeDirs.count(0), 0);
    });
  });

  group('generated boards', () {
    for (final size in [5, 6, 7]) {
      test('size $size scrambled board is always solvable', () {
        for (var seed = 0; seed < 15; seed++) {
          final logic = PipesLogic(size: size, random: Random(seed));
          expect(logic.endpoints.length, greaterThanOrEqualTo(2));
          // Rotating every tile back to its generated orientation is
          // always a valid solution — solvability by construction.
          logic.resetRotationsToSolved();
          expect(logic.isSolved, isTrue);
          expect(logic.liveEndpointCount, logic.endpoints.length);
          // The solved spanning tree feeds every cell from the source.
          expect(logic.computeLive().length, size * size);
          expect(logic.isLive(logic.source), isTrue);
        }
      });
    }

    test('scramble leaves a playable (not pre-solved) board', () {
      for (var seed = 0; seed < 20; seed++) {
        final logic = PipesLogic(size: 5, random: Random(100 + seed));
        expect(logic.isSolved, isFalse);
        expect(logic.rotations, 0); // scrambling never counts as moves
      }
    });
  });

  group('live-endpoint recomputation', () {
    test('twisting an end cap away kills it; twisting home revives it', () {
      final logic = PipesLogic(size: 5, random: Random(4));
      logic.resetRotationsToSolved();
      expect(logic.isSolved, isTrue);
      expect(logic.hintIndex(), isNull); // nothing is misrotated

      final endpoint = logic.endpoints.first;
      logic.rotateCell(endpoint);
      expect(logic.isSolved, isFalse);
      expect(logic.isLive(endpoint), isFalse);
      expect(logic.rotations, 1);

      // Three more clockwise taps bring it home.
      logic.rotateCell(endpoint);
      logic.rotateCell(endpoint);
      logic.rotateCell(endpoint);
      expect(logic.isSolved, isTrue);
      expect(logic.isLive(endpoint), isTrue);
      expect(logic.rotations, 4);
    });

    test('hintIndex finds a misrotated tile on a scrambled board', () {
      final logic = PipesLogic(size: 6, random: Random(8));
      expect(logic.isSolved, isFalse);
      final index = logic.hintIndex();
      expect(index, isNotNull);
      expect(logic.rotateToSolved(index!), isTrue);
      expect(logic.maskOf(index), logic.connectionsOf(index));
      // Hints do not count as player rotations.
      expect(logic.rotations, 0);
    });

    test('out-of-range rotations are rejected', () {
      final logic = PipesLogic(size: 5, random: Random(15));
      expect(logic.rotateCell(-1), isFalse);
      expect(logic.rotateCell(25), isFalse);
      expect(logic.rotateToSolved(99), isFalse);
      expect(logic.rotations, 0);
    });

    test('minRotationsToSolve is zero on the solved board and positive after', () {
      final logic = PipesLogic(size: 6, random: Random(2));
      logic.resetRotationsToSolved();
      expect(logic.minRotationsToSolve(), 0);
      final scrambled = PipesLogic(size: 6, random: Random(2));
      expect(scrambled.minRotationsToSolve(), greaterThan(0));
      // From a solved board, one clockwise tap needs 1 twist back for a
      // shape-symmetric tile and 3 for an asymmetric one (forward-only).
      final solved2 = PipesLogic(size: 5, random: Random(21));
      solved2.resetRotationsToSolved();
      solved2.rotateCell(0);
      expect(solved2.minRotationsToSolve(), inInclusiveRange(1, 3));
    });

    test('restoreRotations round-trips a saved board', () {
      final logic = PipesLogic(size: 5, random: Random(6));
      logic.rotateCell(3);
      logic.rotateCell(7);
      logic.rotateCell(7);
      final snapshot = logic.rotationSnapshot();
      final moves = logic.rotations;

      final copy = PipesLogic(size: 5, random: Random(6));
      expect(copy.restoreRotations(snapshot, moves: moves), isTrue);
      for (var i = 0; i < 25; i++) {
        expect(copy.maskOf(i), logic.maskOf(i));
      }
      expect(copy.isSolved, logic.isSolved);
      expect(copy.rotations, moves);

      // Malformed payloads are rejected without mutating the board.
      final before = copy.rotationSnapshot();
      expect(copy.restoreRotations([0, 1], moves: 0), isFalse);
      expect(copy.restoreRotations(List.filled(25, 9), moves: 0), isFalse);
      expect(copy.restoreRotations(List.filled(25, -1), moves: 0), isFalse);
      expect(copy.rotationSnapshot(), before);
    });
  });
}

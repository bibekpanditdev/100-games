import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/board/tic_tac_toe/tic_tac_toe_logic.dart';

/// Deep-copies a position so the exhaustive search can branch.
TicTacToeLogic cloneOf(TicTacToeLogic source) {
  final copy = TicTacToeLogic(aiLevel: source.aiLevel, random: Random(1))
    ..board.setAll(0, source.board)
    ..winner = source.winner;
  return copy;
}

void main() {
  group('win detection', () {
    test('every line of three is detected for both players', () {
      for (final line in TicTacToeLogic.lines) {
        for (final who in [TicTacToeLogic.player, TicTacToeLogic.cpu]) {
          final board = List<int>.filled(9, 0);
          for (final cell in line) {
            board[cell] = who;
          }
          expect(TicTacToeLogic.winnerOf(board), who,
              reason: 'line $line for player $who');
        }
      }
    });

    test('no winner on mixed or empty boards', () {
      expect(TicTacToeLogic.winnerOf(List<int>.filled(9, 0)), isNull);
      expect(
        TicTacToeLogic.winnerOf([
          1, 2, 1,
          2, 1, 2,
          2, 1, 2,
        ]),
        isNull,
      );
    });

    test('logic flags a win and its winning line', () {
      final logic = TicTacToeLogic(aiLevel: 1, random: Random(1))
        ..play(2)
        ..play(4)
        ..play(6);
      expect(logic.winner, TicTacToeLogic.player);
      expect(logic.winningLine(), contains(2));
      expect(logic.winningLine(), contains(4));
      expect(logic.winningLine(), contains(6));
      expect(logic.isGameOver, isTrue);
      // No moves after the game ends.
      expect(logic.play(0), isFalse);
      expect(logic.cpuMove(), isNull);
    });

    test('draw when the board fills with no line', () {
      final logic = TicTacToeLogic(aiLevel: 1, random: Random(1))
        ..board.setAll(0, [
          1, 2, 1,
          1, 2, 2,
          2, 1, 0,
        ]);
      expect(logic.play(8), isTrue);
      expect(logic.isDraw, isTrue);
      expect(logic.winner, isNull);
    });
  });

  group('medium CPU', () {
    test('takes an immediate win over a block', () {
      final logic = TicTacToeLogic(aiLevel: 2, random: Random(1))
        ..board.setAll(0, [
          2, 2, 0,
          1, 1, 0,
          0, 0, 0,
        ]);
      final move = logic.cpuMove();
      expect(move, 2, reason: 'must complete its own line first');
      expect(logic.winner, TicTacToeLogic.cpu);
    });

    test('blocks the player\u2019s immediate win', () {
      final logic = TicTacToeLogic(aiLevel: 2, random: Random(1))
        ..board.setAll(0, [
          1, 1, 0,
          0, 2, 0,
          0, 0, 0,
        ]);
      final move = logic.cpuMove();
      expect(move, 2, reason: 'must block the top row');
      expect(logic.winner, isNull);
    });
  });

  group('perfect CPU', () {
    test('never loses across every possible player line', () {
      var playerWins = 0;
      var draws = 0;
      var cpuWins = 0;
      void explore(TicTacToeLogic state) {
        if (state.isGameOver) {
          if (state.winner == TicTacToeLogic.cpu) {
            cpuWins += 1;
          } else if (state.winner == TicTacToeLogic.player) {
            playerWins += 1;
          } else {
            draws += 1;
          }
          return;
        }
        for (var i = 0; i < 9; i++) {
          if (state.board[i] != 0) continue;
          final next = cloneOf(state)..play(i);
          if (!next.isGameOver) next.cpuMove();
          explore(next);
        }
      }

      explore(TicTacToeLogic(aiLevel: 3, random: Random(1)));
      expect(cpuWins + draws + playerWins, greaterThan(0));
      expect(playerWins, 0,
          reason: 'the minimax CPU must be unbeatable');
      expect(draws, greaterThan(0), reason: 'perfect play should draw');
      expect(cpuWins, greaterThan(0),
          reason: 'perfect play punishes bad openings');
    });

    test('is deterministic for a given position', () {
      final board = [
        1, 0, 2,
        0, 2, 0,
        0, 0, 1,
      ];
      final moves = <int>{};
      for (var i = 0; i < 5; i++) {
        final logic = TicTacToeLogic(aiLevel: 3, random: Random(i))
          ..board.setAll(0, board);
        moves.add(logic.cpuMove()!);
      }
      expect(moves.length, 1);
    });

    test('bestMoveForPlayer defends a hanging threat', () {
      final logic = TicTacToeLogic(aiLevel: 3, random: Random(1))
        ..board.setAll(0, [
          1, 1, 0,
          0, 0, 0,
          0, 0, 0,
        ]);
      // The player already owns 0 and 1; the hint must finish the line.
      expect(logic.bestMoveForPlayer(), 2);
    });
  });
}

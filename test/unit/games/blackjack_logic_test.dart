import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:thousand_games/features/games/cards/blackjack/blackjack_logic.dart';

BlackjackCard c(int rank, BlackjackSuit suit) => BlackjackCard(rank: rank, suit: suit);

/// The shoe is consumed from the end, so reverse the intended deal order.
List<BlackjackCard> shoeFrom(List<BlackjackCard> dealOrder) =>
    dealOrder.reversed.toList();

void main() {
  group('hand values with soft aces', () {
    test('A+A counts 12', () {
      expect(
        BlackjackLogic.handValue([c(1, BlackjackSuit.spades), c(1, BlackjackSuit.hearts)]),
        12,
      );
    });

    test('A+K counts 21', () {
      expect(
        BlackjackLogic.handValue([c(1, BlackjackSuit.spades), c(13, BlackjackSuit.hearts)]),
        21,
      );
    });

    test('multiple aces downgrade only while busting', () {
      expect(
        BlackjackLogic.handValue([
          c(1, BlackjackSuit.spades),
          c(1, BlackjackSuit.hearts),
          c(1, BlackjackSuit.clubs),
          c(9, BlackjackSuit.diamonds),
        ]),
        12,
      );
      expect(
        BlackjackLogic.handValue([
          c(1, BlackjackSuit.spades),
          c(9, BlackjackSuit.hearts),
          c(13, BlackjackSuit.clubs),
        ]),
        20,
      );
    });

    test('face cards count ten and plain ranks count face value', () {
      expect(
        BlackjackLogic.handValue([c(13, BlackjackSuit.spades), c(12, BlackjackSuit.hearts)]),
        20,
      );
      expect(
        BlackjackLogic.handValue([c(5, BlackjackSuit.spades), c(4, BlackjackSuit.hearts)]),
        9,
      );
      expect(
        BlackjackLogic.handValue([
          c(13, BlackjackSuit.spades),
          c(12, BlackjackSuit.hearts),
          c(2, BlackjackSuit.clubs),
        ]),
        22,
      );
    });
  });

  group('blackjack payout', () {
    test('player blackjack pays 3:2 on a 10 chip bet', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(1, BlackjackSuit.spades), // player
          c(13, BlackjackSuit.spades), // player
          c(5, BlackjackSuit.hearts), // dealer
          c(9, BlackjackSuit.hearts), // dealer
        ]),
      )..startHand();
      expect(logic.result, BlackjackResult.playerBlackjack);
      expect(logic.chips, 115, reason: '100 - 10 bet + 10 back + 15 profit');
    });

    test('two blackjacks push', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(1, BlackjackSuit.spades),
          c(13, BlackjackSuit.spades),
          c(1, BlackjackSuit.hearts),
          c(13, BlackjackSuit.hearts),
        ]),
      )..startHand();
      expect(logic.result, BlackjackResult.push);
      expect(logic.chips, 100);
    });

    test('dealer blackjack beats a normal 20', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(13, BlackjackSuit.spades),
          c(12, BlackjackSuit.spades), // player 20
          c(1, BlackjackSuit.hearts),
          c(13, BlackjackSuit.hearts), // dealer blackjack
        ]),
      )..startHand();
      expect(logic.result, BlackjackResult.dealerWins);
      expect(logic.chips, 90);
    });
  });

  group('dealer play', () {
    test('dealer stands on hard 17', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(10, BlackjackSuit.spades),
          c(9, BlackjackSuit.spades), // player 19
          c(10, BlackjackSuit.hearts),
          c(7, BlackjackSuit.hearts), // dealer 17
        ]),
      )..startHand();
      logic.stand();
      expect(logic.dealer.length, 2, reason: '17 must not draw');
      expect(logic.result, BlackjackResult.playerWins);
      expect(logic.chips, 110);
    });

    test('dealer stands on soft 17 (A+6)', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(10, BlackjackSuit.spades),
          c(9, BlackjackSuit.spades), // player 19
          c(1, BlackjackSuit.hearts),
          c(6, BlackjackSuit.hearts), // dealer soft 17
        ]),
      )..startHand();
      logic.stand();
      expect(logic.dealer.length, 2, reason: 'soft 17 must not draw');
      expect(logic.result, BlackjackResult.playerWins);
    });

    test('dealer draws below 17', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(10, BlackjackSuit.spades),
          c(9, BlackjackSuit.spades), // player 19
          c(10, BlackjackSuit.hearts),
          c(6, BlackjackSuit.hearts), // dealer 16...
          c(5, BlackjackSuit.clubs), // ...draws to 21
        ]),
      )..startHand();
      logic.stand();
      expect(logic.dealer.length, 3);
      expect(BlackjackLogic.handValue(logic.dealer), 21);
      expect(logic.result, BlackjackResult.dealerWins);
    });

    test('equal totals push and return the bet', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(10, BlackjackSuit.spades),
          c(9, BlackjackSuit.spades),
          c(9, BlackjackSuit.hearts),
          c(10, BlackjackSuit.hearts),
        ]),
      )..startHand();
      logic.stand();
      expect(logic.result, BlackjackResult.push);
      expect(logic.chips, 100);
    });

    test('player bust settles immediately without dealer draws', () {
      final logic = BlackjackLogic(
        rounds: 3,
        random: Random(1),
        shoe: shoeFrom([
          c(13, BlackjackSuit.spades),
          c(12, BlackjackSuit.spades), // player 20
          c(6, BlackjackSuit.hearts),
          c(7, BlackjackSuit.hearts),
          c(5, BlackjackSuit.clubs), // hit → 25, bust
        ]),
      )..startHand();
      logic.hit();
      expect(BlackjackLogic.handValue(logic.player), 25);
      expect(logic.result, BlackjackResult.dealerWins);
      expect(logic.dealer.length, 2);
      expect(logic.chips, 90);
    });
  });

  group('session flow and reshuffling', () {
    test('nextHand advances and stops after the final round', () {
      final logic = BlackjackLogic(rounds: 2, random: Random(9))..startHand();
      expect(logic.currentHandNumber, 1);
      logic.stand();
      logic.nextHand();
      expect(logic.currentHandNumber, 2);
      expect(logic.handOver, isFalse);
      logic.stand();
      expect(logic.sessionOver, isTrue);
      logic.nextHand();
      expect(logic.handsPlayed, 2);
      expect(logic.player, isNotEmpty, reason: 'no new hand after the last');
    });

    test('reshuffle never deals a duplicate card within a hand', () {
      final tinyShoe = shoeFrom([
        c(5, BlackjackSuit.spades),
        c(6, BlackjackSuit.spades),
        c(7, BlackjackSuit.spades),
        c(8, BlackjackSuit.spades),
        c(9, BlackjackSuit.spades),
        c(10, BlackjackSuit.spades),
        c(11, BlackjackSuit.spades),
        c(12, BlackjackSuit.spades),
      ]);
      final logic = BlackjackLogic(
        rounds: 7,
        random: Random(42),
        shoe: tinyShoe,
      )..startHand();
      for (var hand = 0; hand < 7; hand++) {
        if (hand.isEven) logic.hit(); // vary hand sizes
        logic.stand();
        final seen = <BlackjackCard>{...logic.player, ...logic.dealer};
        expect(seen.length, logic.player.length + logic.dealer.length,
            reason: 'hand ${hand + 1} contains a duplicate card');
        logic.nextHand();
      }
      expect(logic.reshuffles, greaterThan(0), reason: 'never reshuffled');
      expect(logic.handsPlayed, 7);
    });
  });
}

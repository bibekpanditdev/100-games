/// Pure blackjack rules: a reshuffling shoe, hand values with soft aces,
/// dealer play (stands on all 17s), 3:2 blackjack payout and chip
/// accounting over a fixed number of hands.
///
/// Deterministic given a seeded [Random] (or an explicit shoe) — no Flutter
/// imports, so it can be unit-tested without pumping widgets.
library;

import 'dart:math';

/// The four suits.
enum BlackjackSuit { hearts, diamonds, spades, clubs }

/// One standard playing card.
class BlackjackCard {
  const BlackjackCard({required this.rank, required this.suit});

  /// 1..13 — ace..king. Aces count 1 or 11, face cards 10.
  final int rank;
  final BlackjackSuit suit;

  @override
  bool operator ==(Object other) =>
      other is BlackjackCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);

  @override
  String toString() => 'BlackjackCard($rank, ${suit.name})';
}

/// Settlement of one hand.
enum BlackjackResult { none, playerBlackjack, playerWins, dealerWins, push }

/// A fixed number of blackjack hands with a fixed per-hand bet.
class BlackjackLogic {
  /// Creates a session of [rounds] hands. Cards are dealt from the END of
  /// the [shoe] when supplied, otherwise from a shuffled fresh deck.
  BlackjackLogic({
    required this.rounds,
    required Random random,
    this.startingChips = 100,
    this.betPerHand = 10,
    List<BlackjackCard>? shoe,
  })  : assert(rounds >= 1, 'need at least one hand'),
        chips = startingChips,
        _shoe = shoe ?? (_buildDeck()..shuffle(random)),
        _random = random;

  final int rounds;
  final int startingChips;
  final int betPerHand;
  final Random _random;

  List<BlackjackCard> _shoe;

  /// Cards held by the player this hand.
  List<BlackjackCard> player = <BlackjackCard>[];

  /// Cards held by the dealer this hand. The widget hides the second card
  /// while the hand is running.
  List<BlackjackCard> dealer = <BlackjackCard>[];

  BlackjackResult result = BlackjackResult.none;

  int chips;
  int handsPlayed = 0;

  /// How many times the shoe was rebuilt mid-session (test visibility).
  int reshuffles = 0;

  int get currentHandNumber => handsPlayed + 1;
  bool get handOver => result != BlackjackResult.none;
  bool get sessionOver => handOver && handsPlayed + 1 >= rounds;

  static List<BlackjackCard> _buildDeck() => <BlackjackCard>[
        for (final suit in BlackjackSuit.values)
          for (var rank = 1; rank <= 13; rank++)
            BlackjackCard(rank: rank, suit: suit),
      ];

  /// Best hand value: aces count 11 and drop to 1 while busting.
  static int handValue(List<BlackjackCard> cards) {
    var total = 0;
    var aces = 0;
    for (final card in cards) {
      if (card.rank == 1) {
        aces += 1;
        total += 11;
      } else if (card.rank >= 10) {
        total += 10;
      } else {
        total += card.rank;
      }
    }
    while (total > 21 && aces > 0) {
      total -= 10;
      aces -= 1;
    }
    return total;
  }

  /// A two-card 21.
  static bool isBlackjack(List<BlackjackCard> cards) =>
      cards.length == 2 && handValue(cards) == 21;

  /// Deals a new hand: the bet is deducted up front and paid back (with
  /// winnings) at settlement.
  void startHand() {
    assert(
      player.isEmpty || result != BlackjackResult.none,
      'settle or call nextHand between hands, never redeal mid-hand',
    );
    player = <BlackjackCard>[];
    dealer = <BlackjackCard>[];
    result = BlackjackResult.none;
    chips -= betPerHand;
    player
      ..add(_draw())
      ..add(_draw());
    dealer
      ..add(_draw())
      ..add(_draw());
    if (isBlackjack(player) || isBlackjack(dealer)) _settle();
  }

  /// Player takes one more card. Busting settles the hand immediately.
  void hit() {
    if (handOver) return;
    player.add(_draw());
    if (handValue(player) > 21) _settle();
  }

  /// Player stops; the dealer draws while below 17 (stands on all 17s,
  /// soft ones included) and the hand is settled.
  void stand() {
    if (handOver) return;
    while (handValue(dealer) < 17) {
      dealer.add(_draw());
    }
    _settle();
  }

  /// Advances to the next hand if any remain.
  void nextHand() {
    if (!handOver) return;
    handsPlayed += 1;
    if (handsPlayed < rounds) startHand();
  }

  BlackjackCard _draw() {
    if (_shoe.length < 15) _reshuffle();
    return _shoe.removeLast();
  }

  /// Rebuilds the shoe from a fresh deck, excluding the cards currently on
  /// the table so no duplicate card can appear within a hand.
  void _reshuffle() {
    final table = {...player, ...dealer};
    _shoe = _buildDeck().where((card) => !table.contains(card)).toList()
      ..shuffle(_random);
    reshuffles += 1;
  }

  void _settle() {
    final pv = handValue(player);
    final dv = handValue(dealer);
    final playerBJ = isBlackjack(player);
    final dealerBJ = isBlackjack(dealer);
    if (playerBJ && dealerBJ) {
      result = BlackjackResult.push;
      chips += betPerHand;
    } else if (playerBJ) {
      // Blackjack pays 3:2 — bet 10 wins 15 profit.
      result = BlackjackResult.playerBlackjack;
      chips += betPerHand + betPerHand * 3 ~/ 2;
    } else if (dealerBJ || pv > 21) {
      result = BlackjackResult.dealerWins;
    } else if (dv > 21 || pv > dv) {
      result = BlackjackResult.playerWins;
      chips += betPerHand * 2;
    } else if (pv == dv) {
      result = BlackjackResult.push;
      chips += betPerHand;
    } else {
      result = BlackjackResult.dealerWins;
    }
  }
}

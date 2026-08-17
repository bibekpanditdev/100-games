/// Pure higher-or-lower rules: a fresh shuffled 52-card deck (no card is
/// drawn twice), ace-low..king-high comparison, lives, streak bonuses and
/// round counting.
///
/// Deterministic given a seeded [Random] — no Flutter imports, so it can be
/// unit-tested without pumping widgets.
library;

import 'dart:math';

/// The two bets the player can place on the next card.
enum HigherLowerChoice { higher, lower }

/// One standard playing card.
class HigherLowerCard {
  const HigherLowerCard({required this.rank, required this.suit});

  /// 1..13 — ace (low) .. king (high).
  final int rank;

  /// 0 hearts, 1 diamonds, 2 spades, 3 clubs.
  final int suit;

  @override
  bool operator ==(Object other) =>
      other is HigherLowerCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}

/// Outcome of one bet.
class HigherLowerGuessResult {
  const HigherLowerGuessResult({
    required this.correct,
    required this.nextCard,
    required this.pointsGained,
    required this.livesLeft,
    required this.streak,
  });

  /// Whether the next card matched the bet. An equal rank counts as wrong:
  /// it is neither higher nor lower.
  final bool correct;

  /// The card that was revealed by this guess (now the current card).
  final HigherLowerCard nextCard;

  /// Points awarded (100 per correct guess + 25 x prior streak, else 0).
  final int pointsGained;

  final int livesLeft;
  final int streak;
}

/// Higher-or-lower session state machine.
class HigherLowerLogic {
  /// Creates a session of [rounds] guesses with a shuffled fresh deck.
  HigherLowerLogic({
    required this.rounds,
    required Random random,
    this.startingLives = 3,
  })  : assert(rounds >= 1 && rounds <= 51, 'rounds must leave deck headroom'),
        lives = startingLives {
    _deck = _buildDeck()..shuffle(random);
    _current = _deck.removeLast();
    _revealed.add(_current);
  }

  final int rounds;
  final int startingLives;

  late final List<HigherLowerCard> _deck;
  late HigherLowerCard _current;

  int lives;
  int score = 0;
  int streak = 0;
  int round = 0;

  /// The face-up card the player is betting against.
  HigherLowerCard get currentCard => _current;

  bool get outOfLives => lives <= 0;
  bool get completedRounds => round >= rounds;
  bool get isOver => outOfLives || completedRounds;

  /// Cards already revealed this session (current card included) — all
  /// distinct because each draw removes from the shuffled deck.
  List<HigherLowerCard> get revealedCards => _revealed.toList();
  final List<HigherLowerCard> _revealed = <HigherLowerCard>[];

  static List<HigherLowerCard> _buildDeck() => <HigherLowerCard>[
        for (var suit = 0; suit < 4; suit++)
          for (var rank = 1; rank <= 13; rank++)
            HigherLowerCard(rank: rank, suit: suit),
      ];

  /// Places a bet on the next card and advances the round.
  HigherLowerGuessResult guess(HigherLowerChoice choice) {
    assert(!isOver, 'guess called after the session ended');
    final next = _deck.removeLast();
    round += 1;
    final correct = switch (choice) {
      HigherLowerChoice.higher => next.rank > _current.rank,
      HigherLowerChoice.lower => next.rank < _current.rank,
    };
    if (correct) {
      // The streak bonus uses the streak BEFORE this answer, so the first
      // correct guess earns 100 and each consecutive one adds 25 more.
      final points = 100 + 25 * streak;
      score += points;
      streak += 1;
    } else {
      lives -= 1;
      streak = 0;
    }
    _revealed.add(next);
    _current = next;
    return HigherLowerGuessResult(
      correct: correct,
      nextCard: next,
      pointsGained: correct ? 100 + 25 * (streak - 1) : 0,
      livesLeft: lives,
      streak: streak,
    );
  }

  /// Grants one extra life (paid continue).
  void revive() => lives += 1;
}

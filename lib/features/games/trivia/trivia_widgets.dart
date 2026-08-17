/// Passive trivia UI pieces: loading/error message, progress header, timer
/// bar and the question card. Interactive answer/feedback/hint widgets live
/// in `trivia_answer_button.dart`.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/palettes.dart';
import 'trivia_logic.dart';

/// Centered icon + message view used for loading, error and end states.
class TriviaMessageView extends StatelessWidget {
  const TriviaMessageView({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Question 4/10' header plus an optional streak chip.
class TriviaProgressHeader extends StatelessWidget {
  const TriviaProgressHeader({
    super.key,
    required this.current,
    required this.total,
    required this.streak,
    required this.palette,
  });

  final int current;

  final int total;

  /// Current answer streak; a chip is shown from 2 upward.
  final int streak;

  final GamePalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Question $current of $total',
            child: Text(
              'Question $current/$total',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        if (streak >= 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: palette.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Streak $streak',
              style: TextStyle(
                color: GamePalette.contrastOn(palette.accent),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Horizontal time-remaining bar shown on timed questions.
class TriviaTimerBar extends StatelessWidget {
  const TriviaTimerBar({
    super.key,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.palette,
  });

  final int secondsLeft;

  final int totalSeconds;

  final GamePalette palette;

  @override
  Widget build(BuildContext context) {
    final fraction = totalSeconds <= 0 ? 0.0 : (secondsLeft / totalSeconds).clamp(0.0, 1.0);
    return Semantics(
      label: '$secondsLeft of $totalSeconds seconds left',
      child: Row(
        children: [
          const Icon(Icons.timer, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              color: palette.accent,
              backgroundColor: palette.boardB,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              '${secondsLeft}s',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The large palette-accented card showing the current question.
class TriviaQuestionCard extends StatelessWidget {
  const TriviaQuestionCard({
    super.key,
    required this.question,
    required this.palette,
    this.compact = false,
  });

  final TriviaQuestion question;

  final GamePalette palette;

  /// Use smaller padding/text on narrow screens.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = GamePalette.contrastOn(palette.accent);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(palette.boardA, _titleCase(question.category)),
              _chip(palette.boardB, question.difficulty),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            question.prompt,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 22 : 28,
              height: 1.25,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  static String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

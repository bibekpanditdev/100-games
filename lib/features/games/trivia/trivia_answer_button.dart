/// Interactive trivia widgets: the answer button (with redundant color +
/// icon + letter state channels), the between-question feedback pill and the
/// 50/50 hint button.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/palettes.dart';
import 'trivia_logic.dart';

/// Semantic green used for correct answers (never the only signal — a check
/// icon and the letter chip always accompany it).
const Color kTriviaCorrectColor = Color(0xFF2E7D32);

/// Semantic red used for wrong picks (accompanied by a close icon).
const Color kTriviaWrongColor = Color(0xFFC62828);

/// Visual state of one answer option.
enum TriviaOptionState {
  /// Unanswered, tappable.
  neutral,

  /// Revealed correct answer (green + check icon).
  correct,

  /// The wrong option the player picked (red + close icon).
  wrong,

  /// Not picked, not correct — faded out after answering.
  dimmed,

  /// Removed by a 50/50 hint (not rendered).
  removed,
}

/// One of the four answer buttons. At least 48dp tall, letter-chipped with
/// the colour-blind-safe [kPieceColors] and announced to screen readers with
/// an explicit label describing its state.
class TriviaAnswerButton extends StatelessWidget {
  const TriviaAnswerButton({
    super.key,
    required this.optionIndex,
    required this.label,
    required this.state,
    required this.palette,
    required this.onTap,
  });

  final int optionIndex;

  final String label;

  final TriviaOptionState state;

  final GamePalette palette;

  final VoidCallback onTap;

  static const double minHeight = 56;

  static const List<String> _letters = ['A', 'B', 'C', 'D'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interactive = state == TriviaOptionState.neutral;
    final background = switch (state) {
      TriviaOptionState.correct => kTriviaCorrectColor,
      TriviaOptionState.wrong => kTriviaWrongColor,
      _ => palette.boardA,
    };
    final foreground = switch (state) {
      TriviaOptionState.neutral || TriviaOptionState.dimmed => theme.colorScheme.onSurface,
      _ => GamePalette.contrastOn(background),
    };
    final trailingIcon = switch (state) {
      TriviaOptionState.correct => Icons.check_circle,
      TriviaOptionState.wrong => Icons.cancel,
      _ => null,
    };
    final letter = _letters[optionIndex.clamp(0, _letters.length - 1)];
    final chipColor = kPieceColors[optionIndex % kPieceColors.length];
    final stateLabel = switch (state) {
      TriviaOptionState.correct => ', correct answer',
      TriviaOptionState.wrong => ', your answer, incorrect',
      _ => '',
    };

    return Semantics(
      button: true,
      enabled: interactive,
      label: 'Option $letter: $label$stateLabel',
      child: Opacity(
        opacity: state == TriviaOptionState.dimmed ? 0.45 : 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: interactive ? onTap : null,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
                      child: Text(
                        letter,
                        style: TextStyle(
                          color: GamePalette.contrastOn(chipColor),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: 8),
                      Icon(trailingIcon, color: foreground),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brief pill shown for 600ms between questions: 'Correct! +165' or the
/// incorrect/time-up variant.
class TriviaFeedbackView extends StatelessWidget {
  const TriviaFeedbackView({super.key, required this.result, required this.timedOut});

  final TriviaAnswerResult result;

  /// Distinguishes 'Time is up!' from a plain wrong pick.
  final bool timedOut;

  @override
  Widget build(BuildContext context) {
    final color = result.correct ? kTriviaCorrectColor : kTriviaWrongColor;
    final foreground = GamePalette.contrastOn(color);
    final icon = result.correct
        ? Icons.check_circle
        : (timedOut ? Icons.hourglass_bottom : Icons.cancel);
    final text = result.correct
        ? 'Correct! +${result.total} points'
        : (timedOut ? 'Time is up!' : 'Incorrect');
    return Align(
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Requests a 50/50 hint through the session support flow.
class TriviaHintButton extends StatelessWidget {
  const TriviaHintButton({super.key, required this.available, required this.onPressed});

  final bool available;

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton.icon(
        onPressed: available ? onPressed : null,
        icon: const Icon(Icons.lightbulb),
        label: const Text('50/50 Hint'),
      ),
    );
  }
}

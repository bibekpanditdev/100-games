/// Sudoku board + number-pad widgets (kept out of the engine file for
/// size). Both are pure functions of the state handed in by the engine.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/palettes.dart';
import '../common/grid_render.dart';
import 'sudoku_logic.dart';

/// The 9×9 board with bold 3×3 box separators.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    super.key,
    required this.logic,
    required this.selected,
    required this.onCellTap,
    required this.palette,
  });

  final SudokuLogic logic;
  final int? selected;
  final ValueChanged<int> onCellTap;
  final GamePalette palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extent = constraints.maxWidth / 9;
        final fontSize = (extent * 0.55).clamp(12.0, 30.0).toDouble();
        final notesSize = (extent * 0.24).clamp(6.0, 11.0).toDouble();
        return MindGridFrame(
          color: palette.boardB,
          padding: 4,
          child: Column(
            children: [
              for (var r = 0; r < 9; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < 9; c++)
                        Expanded(
                          child: _buildCell(r, c, fontSize, notesSize),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCell(int r, int c, double fontSize, double notesSize) {
    final index = r * 9 + c;
    final value = logic.valueAt(index);
    final isGiven = logic.isGiven(index);
    final wrong = logic.isMistake(index);
    final isSelected = selected == index;
    final fg = GamePalette.contrastOn(palette.boardA);

    Color bg;
    if (isSelected) {
      bg = palette.accent;
    } else if (isGiven) {
      bg = palette.boardB;
    } else {
      bg = palette.boardA;
    }
    var foreground = GamePalette.contrastOn(bg);
    if (!isGiven && !isSelected && value != 0 && !wrong) {
      // User entries get a per-digit colour; the digit itself is the
      // second (shape/number) channel.
      foreground = kPieceColors[(value - 1) % kPieceColors.length];
    }
    if (wrong) {
      foreground = kPieceColors[5]; // vermillion + ✗ overlay icon.
    }
    if (isSelected) {
      foreground = GamePalette.contrastOn(palette.accent);
    }

    final thick = GamePalette.contrastOn(palette.boardB).withAlpha(200);
    final border = Border(
      top: r % 3 == 0
          ? BorderSide(width: 2, color: thick)
          : const BorderSide(width: 0.5, color: Color(0x33808080)),
      left: c % 3 == 0
          ? BorderSide(width: 2, color: thick)
          : const BorderSide(width: 0.5, color: Color(0x33808080)),
      right: c == 8 ? BorderSide(width: 2, color: thick) : BorderSide.none,
      bottom: r == 8 ? BorderSide(width: 2, color: thick) : BorderSide.none,
    );

    final String? semantics;
    if (value != 0) {
      semantics = 'Row ${r + 1} column ${c + 1}, '
          '${isGiven ? 'given' : wrong ? 'wrong' : 'entry'} $value';
    } else {
      semantics = 'Row ${r + 1} column ${c + 1}, empty';
    }

    return MindGridCell(
      onTap: () => onCellTap(index),
      backgroundColor: bg,
      foregroundColor: foreground,
      border: border,
      borderRadius: 0,
      text: value == 0 ? null : '$value',
      textStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: isGiven ? FontWeight.w700 : FontWeight.w500,
        color: foreground,
        height: 1,
      ),
      notes: value == 0 ? logic.notes[index] : null,
      notesStyle: TextStyle(fontSize: notesSize, color: fg, height: 1),
      overlayIcon: wrong ? Icons.close : null,
      overlayColor: kPieceColors[5],
      semanticsLabel: semantics,
      margin: EdgeInsets.zero,
    );
  }
}

/// The number pad (1–9, erase, notes toggle) + hint button.
class SudokuControls extends StatelessWidget {
  const SudokuControls({
    super.key,
    required this.notesMode,
    required this.freeHints,
    required this.onDigit,
    required this.onErase,
    required this.onToggleNotes,
    required this.onHint,
    required this.palette,
    required this.enabled,
  });

  final bool notesMode;
  final int freeHints;
  final ValueChanged<int> onDigit;
  final VoidCallback onErase;
  final VoidCallback onToggleNotes;
  final VoidCallback onHint;
  final GamePalette palette;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var d = 1; d <= 9; d++)
                Semantics(
                  button: true,
                  label: 'Digit $d',
                  child: FilledButton.tonal(
                    onPressed: enabled ? () => onDigit(d) : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(56, 52),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: kPieceColors[(d - 1) % kPieceColors.length],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Semantics(
                button: true,
                label: notesMode
                    ? 'Notes mode on, tap to turn off'
                    : 'Turn on notes mode',
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? onToggleNotes : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                  ),
                  icon: Icon(
                    notesMode ? Icons.edit_off : Icons.edit_note,
                    color: notesMode ? palette.accent : null,
                  ),
                  label: Text(notesMode ? 'Notes on' : 'Notes'),
                ),
              ),
              Semantics(
                button: true,
                label: 'Erase cell',
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? onErase : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                  ),
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Erase'),
                ),
              ),
              Semantics(
                button: true,
                label: freeHints > 0
                    ? 'Hint, $freeHints free left'
                    : 'Get a hint',
                child: FilledButton.tonalIcon(
                  onPressed: enabled ? onHint : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(72, 48),
                  ),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(
                    freeHints > 0 ? 'Hint ($freeHints)' : 'Hint',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

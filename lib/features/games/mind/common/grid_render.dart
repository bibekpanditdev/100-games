/// Shared grid-cell primitives for the mind games (spec add-on §2 —
/// a common grid core reused by every mind engine board).
///
/// State is always communicated through colour AND text / icon / shape so
/// the boards remain readable for colour-blind players (WCAG / CVD
/// redundancy), matching the conventions of `palettes.dart`.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/palettes.dart';

/// A single bordered grid cell used by the mind-game boards.
///
/// Supports a main [text] or [icon] (with an [overlayIcon] corner mark such
/// as the Sudoku cross), a 3×3 candidate [notes] mini-grid, custom borders
/// and full tap / long-press handling with semantics.
class MindGridCell extends StatelessWidget {
  const MindGridCell({
    super.key,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.foregroundColor,
    this.border,
    this.borderRadius = 6,
    this.text,
    this.textStyle,
    this.icon,
    this.iconSize,
    this.overlayIcon,
    this.overlayColor,
    this.notes,
    this.notesStyle,
    this.semanticsLabel,
    this.margin = const EdgeInsets.all(1.5),
    this.child,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Cell background; text/icon colours default to [GamePalette.contrastOn].
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Optional explicit border (e.g. Sudoku's thick 3×3 box separators).
  final Border? border;
  final double borderRadius;

  final String? text;
  final TextStyle? textStyle;
  final IconData? icon;
  final double? iconSize;

  /// Small corner icon (e.g. `Icons.close` mistake mark).
  final IconData? overlayIcon;
  final Color? overlayColor;

  /// Candidate digits 1–9 rendered as a 3×3 mini-grid (Sudoku notes).
  final Set<int>? notes;
  final TextStyle? notesStyle;

  final String? semanticsLabel;
  final EdgeInsetsGeometry margin;

  /// Fully custom cell content (takes precedence over text/icon/notes).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white;
    final fg = foregroundColor ?? GamePalette.contrastOn(bg);
    Widget? content = child;
    if (content == null && text != null) {
      content = Text(
        text!,
        style: textStyle ??
            TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: fg,
              height: 1,
            ),
        textAlign: TextAlign.center,
        maxLines: 1,
      );
    }
    if (content == null && icon != null) {
      content = Icon(icon, color: fg, size: iconSize);
    }
    if (content == null && notes != null) {
      content = _NotesGrid(notes: notes!, style: notesStyle);
    }
    final overlay = overlayIcon == null
        ? null
        : Positioned(
            top: 1,
            right: 2,
            child: Icon(
              overlayIcon,
              size: 14,
              color: overlayColor ?? kPieceColors[5],
            ),
          );
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: margin,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: content),
              if (overlay != null) overlay,
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesGrid extends StatelessWidget {
  const _NotesGrid({required this.notes, required this.style});

  final Set<int> notes;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        children: [
          for (var row = 0; row < 3; row++)
            Expanded(
              child: Row(
                children: [
                  for (var col = 0; col < 3; col++)
                    Expanded(
                      child: Center(
                        child: Text(
                          _label(row, col),
                          style: style ??
                              const TextStyle(fontSize: 9, height: 1),
                          maxLines: 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _label(int row, int col) {
    final digit = row * 3 + col + 1;
    return notes.contains(digit) ? '$digit' : '';
  }
}

/// Rounded frame that wraps a mind-game board with the palette's board
/// colour — the calm, generous look shared by every mind game.
class MindGridFrame extends StatelessWidget {
  const MindGridFrame({
    super.key,
    required this.child,
    required this.color,
    this.padding = 8.0,
    this.radius = 14.0,
  });

  final Widget child;
  final Color color;
  final double padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.all(padding),
      child: child,
    );
  }
}

/// Sliding puzzle engine: order the numbered tiles 1..N using the blank
/// space. Every shuffle is solvable; hints auto-solve one tile step.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'sliding_puzzle_logic.dart';

/// Catalog engine for the `sliding_puzzle` template.
class SlidingPuzzleEngine implements GameEngine {
  const SlidingPuzzleEngine();

  @override
  String get templateId => 'sliding_puzzle';

  @override
  String get instructions =>
      'Slide tiles into the empty space until they read 1 through N. '
      'Tiles in line with the gap slide as a group, and fewer moves '
      'score higher.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) =>
      SlidingPuzzleGame(session: session);
}

/// The sliding puzzle gameplay screen for one session.
class SlidingPuzzleGame extends StatefulWidget {
  const SlidingPuzzleGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<SlidingPuzzleGame> createState() => _SlidingPuzzleGameState();
}

class _SlidingPuzzleGameState extends State<SlidingPuzzleGame> {
  late final SlidingPuzzle _puzzle;
  late final int _size;
  late final int _initialManhattan;

  Set<int> _flashValues = const <int>{};
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    final size = widget.session.config.getInt('size', 4);
    _size = size < 2 ? 2 : (size > 6 ? 6 : size);
    _puzzle = SlidingPuzzle(size: _size, random: Random());
    final startDistance = _puzzle.manhattan();
    _initialManhattan = startDistance < 1 ? 1 : startDistance;
    widget.session.onHintGranted = _applyHint;
    _pushHud();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  int get _score {
    final raw = _size * _size * 100 - _puzzle.moves * 5;
    return raw < 0 ? 0 : raw;
  }

  void _pushHud() {
    final ratio = 1 - _puzzle.manhattan() / _initialManhattan;
    widget.session.updateHud(
      score: _score,
      status: 'Moves ${_puzzle.moves}',
      detail: 'Size ${_size}x$_size',
      progress: ratio < 0 ? 0.0 : (ratio > 1 ? 1.0 : ratio),
    );
  }

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  void _onTileTap(int index) {
    if (!_interactive) return;
    final moved = _puzzle.slideFrom(index);
    if (moved.isEmpty) return;
    AudioService.I.sfx(SfxKeys.place);
    _flashMoved(moved);
    _pushHud();
    setState(() {});
    if (_puzzle.isSolved) {
      AudioService.I.sfx(SfxKeys.solved);
      widget.session.finish(
        won: true,
        score: _score,
        stats: {'moves': _puzzle.moves, 'size': _size},
      );
    }
  }

  Future<void> _requestHint() async {
    // The shell applies the hint via onHintGranted after payment.
    await widget.session.requestHint();
  }

  void _applyHint() {
    if (widget.session.isFinished) return;
    final hint = _puzzle.hintIndex();
    if (hint < 0) return;
    final moved = _puzzle.slideFrom(hint);
    if (moved.isEmpty) return;
    AudioService.I.sfx(SfxKeys.hint);
    _flashMoved(moved);
    _pushHud();
    setState(() {});
    if (_puzzle.isSolved) {
      AudioService.I.sfx(SfxKeys.solved);
      widget.session.finish(
        won: true,
        score: _score,
        stats: {'moves': _puzzle.moves, 'size': _size},
      );
    }
  }

  void _flashMoved(List<int> tileValues) {
    _flashTimer?.cancel();
    setState(() => _flashValues = tileValues.toSet());
    _flashTimer = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _flashValues = const <int>{});
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_hintButton()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    return Semantics(
      label: 'Sliding puzzle board, $_size by $_size',
      child: Container(
        decoration: BoxDecoration(
          color: palette.boardA,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.biggest.shortestSide / _size;
            return Column(
              children: [
                for (var r = 0; r < _size; r++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var c = 0; c < _size; c++)
                          Expanded(
                            child: _buildTile(r, c, cellSize),
                          ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTile(int r, int c, double cellSize) {
    final palette = widget.session.palette;
    final index = r * _size + c;
    final tile = _puzzle.tileAtFlat(index);
    final flash = _flashValues.contains(tile);
    if (tile == 0) {
      return Semantics(
        label: 'Empty space row ${r + 1} column ${c + 1}',
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.boardB,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    final tileColor = kPieceColors[tile % kPieceColors.length];
    return Semantics(
      button: true,
      label: 'Slide tile $tile',
      child: GestureDetector(
        onTap: () => _onTileTap(index),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(8),
            border: flash ? Border.all(color: palette.accent, width: 3) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$tile',
            style: TextStyle(
              color: GamePalette.contrastOn(tileColor),
              fontSize: cellSize * 0.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hintButton() {
    return Semantics(
      button: true,
      label: 'Get a hint',
      child: FilledButton.tonalIcon(
        onPressed: _interactive ? _requestHint : null,
        style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Hint'),
      ),
    );
  }
}

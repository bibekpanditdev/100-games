/// Minesweeper engine — tap to reveal, long-press (or flag mode) to flag.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'minesweeper_logic.dart';

class MinesweeperEngine implements GameEngine {
  const MinesweeperEngine();

  @override
  String get templateId => 'minesweeper';

  @override
  String get instructions =>
      'Reveal every safe cell without tapping a mine. The numbers show how '
      'many mines touch a cell. Long-press (or flag mode) to mark suspects — '
      'your first tap is always safe.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => MinesweeperGame(session: session);
}

class MinesweeperGame extends StatefulWidget {
  const MinesweeperGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<MinesweeperGame> createState() => _MinesweeperGameState();
}

class _MinesweeperGameState extends State<MinesweeperGame> {
  late MinesweeperLogic _logic;
  late int _size;
  bool _flagMode = false;
  int _score = 0;
  int _seconds = 0;
  Timer? _timer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    _size = cfg.getInt('size', 10).clamp(6, 14);
    final mines = cfg.getInt('mines', 20).clamp(3, _size * _size - 10);
    _logic = MinesweeperLogic(size: _size, mineCount: mines, random: _sessionRandom());
    widget.session.updateHud(score: 0, status: 'Mines $mines', detail: 'Time 0');
    _startTimer();
  }

  Random _sessionRandom() {
    // Seed from the definition id so every variant plays differently but
    // reproducibly.
    var seed = widget.session.definition.id.hashCode;
    if (seed < 0) seed = -seed;
    return Random(seed & 0x7FFFFFFF);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (widget.session.isPaused || _finished) return;
      _seconds++;
      _pushHud();
    });
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _score,
      status: 'Mines ${_logic.mineCount - _logic.flaggedCount}',
      detail: 'Time $_seconds',
    );
  }

  void _onTap(int x, int y) {
    if (_finished || widget.session.isPaused) return;
    if (_flagMode) {
      if (_logic.toggleFlag(x, y)) AudioService.I.sfx(SfxKeys.place);
      setState(() {});
      return;
    }
    final count = _logic.reveal(x, y);
    if (count == 0) return;
    if (_logic.hitMine) {
      HapticFeedback.vibrate();
      AudioService.I.sfx(SfxKeys.hit);
      setState(() {});
      _finish(won: false);
      return;
    }
    _score += count * 10;
    AudioService.I.sfx(SfxKeys.place);
    setState(() {});
    _pushHud();
    if (_logic.won) {
      _score += 200;
      AudioService.I.sfx(SfxKeys.solved);
      _finish(won: true);
    }
  }

  void _onLongPress(int x, int y) {
    if (_finished || widget.session.isPaused) return;
    if (_logic.toggleFlag(x, y)) {
      AudioService.I.sfx(SfxKeys.place);
      setState(() {});
      _pushHud();
    }
  }

  void _finish({required bool won}) {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
    widget.session.finish(
      won: won,
      score: _score,
      stats: {'revealed': _logic.revealedCount},
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    final theme = Theme.of(context);
    final cellEdge = kPieceColors;

    return LayoutBuilder(builder: (context, constraints) {
      final boardSize = constraints.biggest.shortestSide;
      final cell = boardSize / _size;
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.touch_app), label: Text('Dig')),
                    ButtonSegment(value: true, icon: Icon(Icons.flag), label: Text('Flag')),
                  ],
                  selected: {_flagMode},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    setState(() => _flagMode = s.first);
                  },
                ),
              ),
            ],
          ),
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _size),
              itemCount: _size * _size,
              itemBuilder: (context, index) {
                final x = index % _size;
                final y = index ~/ _size;
                return _cell(theme, palette, cellEdge, x, y, cell);
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _cell(ThemeData theme, GamePalette palette, List<Color> colors, int x, int y, double cell) {
    final state = _logic.stateOf(x, y);
    final revealed = state == MsCellState.revealed;
    final flagged = state == MsCellState.flagged;
    final mine = _logic.isMine(x, y);
    final adj = _logic.adjacentMines(x, y);

    Color background;
    Widget content;
    if (revealed) {
      if (mine) {
        background = theme.colorScheme.errorContainer;
        content = Icon(Icons.close, size: cell * 0.6, color: theme.colorScheme.onErrorContainer);
      } else if (adj > 0) {
        background = palette.boardA;
        content = Text(
          '$adj',
          style: TextStyle(
            fontSize: cell * 0.5,
            fontWeight: FontWeight.w800,
            // Number colors are paired with the digit itself (not color-only).
            color: colors[(adj - 1) % colors.length],
          ),
        );
      } else {
        background = palette.boardA;
        content = const SizedBox.shrink();
      }
    } else {
      background = palette.boardB;
      content = flagged
          ? Icon(Icons.flag, size: cell * 0.55, color: GamePalette.contrastOn(palette.boardB))
          : const SizedBox.shrink();
    }

    return Semantics(
      label: revealed
          ? (mine ? 'Mine' : (adj > 0 ? '$adj mines nearby' : 'Empty'))
          : (flagged ? 'Flagged cell' : 'Hidden cell'),
      child: GestureDetector(
        onTap: () => _onTap(x, y),
        onLongPress: () => _onLongPress(x, y),
        child: Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(4),
            border: revealed ? null : Border.fromBorderSide(
              BorderSide(color: GamePalette.contrastOn(palette.boardB).withOpacity(0.15)),
            ),
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}

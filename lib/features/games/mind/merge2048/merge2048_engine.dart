/// 2048 merge engine — swipe or arrows to reach the target tile.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'merge2048_logic.dart';

class Merge2048Engine implements GameEngine {
  const Merge2048Engine();

  @override
  String get templateId => 'merge2048';

  @override
  String get instructions =>
      'Swipe (or use the arrows) to slide tiles. Equal tiles merge and '
      'double — reach the target tile before the board jams.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => Merge2048Game(session: session);
}

class Merge2048Game extends StatefulWidget {
  const Merge2048Game({super.key, required this.session});

  final GameSessionController session;

  @override
  State<Merge2048Game> createState() => _Merge2048GameState();
}

class _Merge2048GameState extends State<Merge2048Game> {
  late Merge2048Logic _logic;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final target = widget.session.config.getInt('target', 2048);
    var seed = widget.session.definition.id.hashCode;
    if (seed < 0) seed = -seed;
    _logic = Merge2048Logic(random: Random(seed & 0x7FFFFFFF))
      ..winTile = target
      ..start();
    _pushHud();
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _logic.score,
      status: 'Best ${_logic.bestTile}',
      detail: 'Target ${_logic.winTile}',
    );
  }

  void _move(MoveDirection dir) {
    if (_finished || widget.session.isPaused) return;
    final gained = _logic.move(dir);
    if (gained == 0 && !_logic.gameOver && !_logic.won) return;
    HapticFeedback.lightImpact();
    AudioService.I.sfx(SfxKeys.place);
    if (_logic.consumeBigMerge()) {
      AudioService.I.sfx(SfxKeys.powerup);
    }
    setState(() {});
    _pushHud();
    if (_logic.won) {
      _finish(won: true);
    } else if (_logic.gameOver) {
      _finish(won: false);
    }
  }

  void _finish({required bool won}) {
    if (_finished) return;
    _finished = true;
    widget.session.finish(
      won: won,
      score: _logic.score,
      stats: {'bestTile': _logic.bestTile},
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    return LayoutBuilder(builder: (context, constraints) {
      final boardSize = constraints.biggest.shortestSide;
      final cell = boardSize / _logic.size;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: boardSize,
            height: boardSize,
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -40) {
                  _move(MoveDirection.left);
                } else if ((d.primaryVelocity ?? 0) > 40) {
                  _move(MoveDirection.right);
                }
              },
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) < -40) {
                  _move(MoveDirection.up);
                } else if ((d.primaryVelocity ?? 0) > 40) {
                  _move(MoveDirection.down);
                }
              },
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _logic.size,
                ),
                itemCount: _logic.size * _logic.size,
                itemBuilder: (context, index) {
                  final x = index % _logic.size;
                  final y = index ~/ _logic.size;
                  return _tile(palette, _logic.tileAt(x, y), cell);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _arrowBtn(Icons.arrow_left, () => _move(MoveDirection.left)),
              Column(
                children: [
                  _arrowBtn(Icons.arrow_drop_up, () => _move(MoveDirection.up)),
                  _arrowBtn(Icons.arrow_drop_down, () => _move(MoveDirection.down)),
                ],
              ),
              _arrowBtn(Icons.arrow_right, () => _move(MoveDirection.right)),
            ],
          ),
        ],
      );
    });
  }

  Widget _arrowBtn(IconData icon, VoidCallback onTap) => SizedBox(
        width: 56,
        height: 48,
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 32),
          tooltip: 'Move',
        ),
      );

  Widget _tile(GamePalette palette, int value, double cell) {
    final theme = Theme.of(context);
    if (value == 0) {
      return Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: palette.boardA.withOpacity(0.5),
          borderRadius: BorderRadius.circular(6),
        ),
      );
    }
    // Tile color cycles the CVD-safe palette by log2 — the big printed
    // number is the primary channel, color is secondary.
    final tier = (log(value) / log(2)).round();
    final color = kPieceColors[tier % kPieceColors.length];
    final fg = GamePalette.contrastOn(color);
    return Container(
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: cell * (value >= 1024 ? 0.26 : value >= 128 ? 0.3 : 0.38),
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

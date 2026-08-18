/// 2048 merge engine — swipe or arrows to reach the target tile.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
      'Swipe, use arrows, or TILT your device to slide tiles. Equal tiles merge and '
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
  StreamSubscription? _accelerometerSub;
  DateTime _lastMoveTime = DateTime.now();

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
    _initSensors();
  }

  void _initSensors() {
    // "Screen tock senses" — adding accelerometer support for tilt-to-move.
    _accelerometerSub = accelerometerEventStream().listen((event) {
      if (_finished || widget.session.isPaused) return;
      
      final now = DateTime.now();
      if (now.difference(_lastMoveTime).inMilliseconds < 400) return;

      const threshold = 4.5;
      if (event.x < -threshold) {
        _move(MoveDirection.right);
        _lastMoveTime = now;
      } else if (event.x > threshold) {
        _move(MoveDirection.left);
        _lastMoveTime = now;
      } else if (event.y < -threshold) {
        _move(MoveDirection.up); // Note: sensor Y depends on orientation, but usually -Y is forward tilt
        _lastMoveTime = now;
      } else if (event.y > threshold) {
        _move(MoveDirection.down);
        _lastMoveTime = now;
      }
    });
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    super.dispose();
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
    
    // Haptics and sound for sensory feedback
    HapticFeedback.mediumImpact(); 
    AudioService.I.sfx(SfxKeys.place);
    if (_logic.consumeBigMerge()) {
      AudioService.I.sfx(SfxKeys.powerup);
    }
    
    if (mounted) setState(() {});
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
    _accelerometerSub?.cancel();
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
      final boardSize = constraints.biggest.shortestSide * 0.95;
      final cell = boardSize / _logic.size;
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // The Board with animations
          Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: palette.boardA.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.boardA, width: 2),
            ),
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
                  final value = _logic.tileAt(x, y);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: _tile(palette, value, cell, key: ValueKey('tile_${x}_${y}_$value')),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Tilt Indicator / Senses Help
          Text(
            'TILT TO MOVE',
            style: TextStyle(
              color: palette.foreground.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 12,
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

  Widget _arrowBtn(IconData icon, VoidCallback onTap) => Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.session.palette.boardA.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onTap,
          icon: Icon(icon, size: 32, color: widget.session.palette.foreground),
          tooltip: 'Move',
        ),
      );

  Widget _tile(GamePalette palette, int value, double cell, {Key? key}) {
    if (value == 0) {
      return Container(
        key: key,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: palette.boardA.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }
    
    final tier = (log(value) / log(2)).round();
    final color = kPieceColors[tier % kPieceColors.length];
    final fg = GamePalette.contrastOn(color);
    
    return Container(
      key: key,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: TextStyle(
          fontSize: cell * (value >= 1024 ? 0.26 : value >= 128 ? 0.3 : 0.38),
          fontWeight: FontWeight.w900,
          color: fg,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.3), offset: const Offset(1, 1), blurRadius: 1),
          ],
        ),
      ),
    );
  }
}

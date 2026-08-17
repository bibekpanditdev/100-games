/// Maze engine — swipe or D-pad from the entrance to the flag before the
/// timer empties; paid hints flash the next three steps of the shortest
/// path. Full save/resume through [GameSessionController].
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'maze_logic.dart';

/// Catalog engine for the `maze` template.
class MazeEngine implements GameEngine {
  const MazeEngine();

  @override
  String get templateId => 'maze';

  @override
  String get instructions =>
      'Walk the winding corridors from the top-left entrance to the '
      'bottom-right flag before the timer runs out. Swipe the maze or use '
      'the pad to move — a hint briefly flashes your next few steps.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => MazeGame(session: session);
}

/// The Maze gameplay screen for one session.
class MazeGame extends StatefulWidget {
  const MazeGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<MazeGame> createState() => _MazeGameState();
}

class _MazeGameState extends State<MazeGame> {
  static const Duration _hintFlash = Duration(milliseconds: 1500);

  late MazeLogic _logic;
  late int _seed;
  late int _size;
  late int _totalSec;
  int _secondsLeft = 0;
  int _playerX = 0;
  int _playerY = 0;
  int _steps = 0;
  List<(int, int)>? _hintCells;
  Timer? _timer;
  Timer? _hintTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    var size = cfg.getInt('size', 15).clamp(9, 25);
    if (size % 2 == 0) size -= 1; // Wall grids are built for odd sizes.
    _size = size;
    _totalSec = cfg.getInt('timeSec', 180).clamp(60, 600);
    final restored = widget.session.restoredState;
    if (restored != null &&
        restored['seed'] is num &&
        restored['px'] is num &&
        restored['py'] is num) {
      var rSize = _toInt(restored['size'], _size);
      if (rSize < 9) {
        rSize = 9;
      } else if (rSize > 25) {
        rSize = 25;
      }
      if (rSize % 2 == 0) rSize -= 1;
      _size = rSize;
      _seed = (restored['seed'] as num).toInt().abs() & 0x7FFFFFFF;
      _logic = MazeLogic(size: _size, random: Random(_seed));
      _playerX = _toInt(restored['px'], 0).clamp(0, _size - 1);
      _playerY = _toInt(restored['py'], 0).clamp(0, _size - 1);
      _steps = max(0, _toInt(restored['steps'], 0));
      _secondsLeft = _toInt(restored['secondsLeft'], _totalSec)
          .clamp(1, _totalSec);
    } else {
      _seed = Random().nextInt(0x7FFFFFFF);
      _logic = MazeLogic(size: _size, random: Random(_seed));
      _playerX = 0;
      _playerY = 0;
      _steps = 0;
      _secondsLeft = _totalSec;
      _save();
    }
    widget.session.onHintGranted = _grantHint;
    widget.session.addListener(_onSessionChanged);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pushHud();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _timer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  static int _toInt(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  bool get _interactive =>
      !_finished &&
      !widget.session.isPaused &&
      !widget.session.isFinished;

  void _onSessionChanged() {
    if (widget.session.isFinished) {
      _timer?.cancel();
      _hintTimer?.cancel();
    } else if (widget.session.isPaused) {
      _save();
    }
  }

  void _tick() {
    if (!mounted || !_interactive) return;
    _secondsLeft -= 1;
    if (_secondsLeft <= 0) {
      _secondsLeft = 0;
      _pushHud();
      _timeout();
      return;
    }
    if (_secondsLeft % 15 == 0) _save();
    _pushHud();
  }

  void _pushHud() {
    widget.session.updateHud(
      score: 0,
      status: 'Time ${_secondsLeft}s',
      detail: 'Steps $_steps',
      progress: _totalSec == 0 ? null : 1 - _secondsLeft / _totalSec,
    );
  }

  void _move(int dx, int dy) {
    if (!_interactive) return;
    if (!_logic.isOpen(_playerX, _playerY, _playerX + dx, _playerY + dy)) {
      AudioService.I.sfx(SfxKeys.uiError);
      return;
    }
    _playerX += dx;
    _playerY += dy;
    _steps += 1;
    _hintCells = null; // A flash is stale once the player moves.
    AudioService.I.sfx(SfxKeys.place);
    _pushHud();
    setState(() {});
    _save();
    _checkWin();
  }

  void _onSwipe(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond;
    if (v.distance < 120) return;
    if (v.dx.abs() > v.dy.abs()) {
      _move(v.dx > 0 ? 1 : -1, 0);
    } else {
      _move(0, v.dy > 0 ? 1 : -1);
    }
  }

  void _checkWin() {
    if (_finished || (_playerX != _logic.exit.$1 || _playerY != _logic.exit.$2)) {
      return;
    }
    _finished = true;
    _timer?.cancel();
    _hintTimer?.cancel();
    AudioService.I.sfx(SfxKeys.solved);
    widget.session.finish(
      won: true,
      score: 500 + _secondsLeft * 2,
      stats: {'steps': _steps, 'secondsLeft': _secondsLeft},
    );
  }

  void _timeout() {
    if (_finished || widget.session.isFinished) return;
    _finished = true;
    _timer?.cancel();
    _hintTimer?.cancel();
    AudioService.I.sfx(SfxKeys.lose);
    widget.session.finish(
      won: false,
      score: 0,
      stats: {'steps': _steps},
    );
  }

  Future<void> _onHintPressed() async {
    if (!_interactive) return;
    // Payment is resolved by the shell; the board only reacts inside
    // [_grantHint]. A false return simply means the request was declined.
    await widget.session.requestHint();
  }

  /// Shell-invoked hint (payment already granted): flash the next three
  /// cells of the shortest path to the exit.
  void _grantHint() {
    if (!_interactive) return;
    final path = _logic.solvePath(from: (_playerX, _playerY));
    if (path.length < 2) return;
    _hintCells = path.sublist(1, path.length < 4 ? path.length : 4);
    AudioService.I.sfx(SfxKeys.hint);
    _hintTimer?.cancel();
    _hintTimer = Timer(_hintFlash, () {
      if (!mounted) return;
      setState(() => _hintCells = null);
    });
    setState(() {});
  }

  void _save() {
    widget.session.saveState(<String, dynamic>{
      'seed': _seed,
      'size': _size,
      'px': _playerX,
      'py': _playerY,
      'steps': _steps,
      'secondsLeft': _secondsLeft,
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    label: 'Maze, $_size by $_size. You are at row '
                        '${_playerY + 1}, column ${_playerX + 1}. The exit '
                        'is at the bottom right.',
                    child: GestureDetector(
                      onPanEnd: _onSwipe,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CustomPaint(
                          painter: _MazePainter(
                            logic: _logic,
                            playerX: _playerX,
                            playerY: _playerY,
                            hintCells: _hintCells,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _DPad(onMove: _move, enabled: _interactive),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Semantics(
              label: 'Hint',
              button: true,
              child: OutlinedButton.icon(
                onPressed: _interactive ? _onHintPressed : null,
                icon: const Icon(Icons.lightbulb),
                label: const Text('Hint'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DPad extends StatelessWidget {
  const _DPad({required this.onMove, required this.enabled});

  final void Function(int dx, int dy) onMove;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget pad(int dx, int dy, IconData icon, String label) => Semantics(
          label: label,
          button: true,
          child: SizedBox(
            width: 56, // Past the 48dp minimum touch target.
            height: 56,
            child: IconButton.filledTonal(
              onPressed: enabled ? () => onMove(dx, dy) : null,
              icon: Icon(icon),
              tooltip: label,
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          pad(0, -1, Icons.arrow_upward, 'Move up'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              pad(-1, 0, Icons.arrow_back, 'Move left'),
              pad(0, 1, Icons.arrow_downward, 'Move down'),
              pad(1, 0, Icons.arrow_forward, 'Move right'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MazePainter extends CustomPainter {
  const _MazePainter({
    required this.logic,
    required this.playerX,
    required this.playerY,
    required this.hintCells,
    required this.palette,
  });

  final MazeLogic logic;
  final int playerX;
  final int playerY;
  final List<(int, int)>? hintCells;
  final GamePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final dim = logic.wallDim;
    final cell = side / dim;

    // Corridor floor.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = palette.boardA,
    );

    // Solid rock.
    final wallPaint = Paint()
      ..color = GamePalette.contrastOn(palette.boardA).withOpacity(0.85);
    for (var wy = 0; wy < dim; wy++) {
      for (var wx = 0; wx < dim; wx++) {
        if (logic.isWall(wx, wy)) {
          canvas.drawRect(
            Rect.fromLTWH(wx * cell, wy * cell, cell + 0.5, cell + 0.5),
            wallPaint,
          );
        }
      }
    }

    // Hint flash: sky-blue dots on the next steps.
    final hints = hintCells;
    if (hints != null) {
      final hintPaint = Paint()..color = kPieceColors[4].withOpacity(0.9);
      for (final (hx, hy) in hints) {
        canvas.drawCircle(
          Offset((hx * 2 + 1.5) * cell, (hy * 2 + 1.5) * cell),
          cell * 0.55,
          hintPaint,
        );
      }
    }

    // Exit: green square with a contrasting flag block (shape + colour).
    final exit = logic.exit;
    final exitRect = Rect.fromLTWH(
      (exit.$1 * 2 + 1) * cell + cell * 0.3,
      (exit.$2 * 2 + 1) * cell + cell * 0.3,
      cell * 1.4,
      cell * 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(exitRect, Radius.circular(cell * 0.3)),
      Paint()..color = kPieceColors[2],
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        exitRect.deflate(cell * 0.45),
        Radius.circular(cell * 0.1),
      ),
      Paint()..color = GamePalette.contrastOn(kPieceColors[2]),
    );

    // Player: accent circle with a contrasting core.
    final playerCenter =
        Offset((playerX * 2 + 1.5) * cell, (playerY * 2 + 1.5) * cell);
    canvas.drawCircle(
      playerCenter,
      cell * 0.85,
      Paint()..color = palette.accent,
    );
    canvas.drawCircle(
      playerCenter,
      cell * 0.35,
      Paint()..color = GamePalette.contrastOn(palette.accent),
    );
  }

  @override
  bool shouldRepaint(_MazePainter oldDelegate) =>
      !identical(oldDelegate.logic, logic) ||
      oldDelegate.playerX != playerX ||
      oldDelegate.playerY != playerY ||
      !identical(oldDelegate.hintCells, hintCells);
}

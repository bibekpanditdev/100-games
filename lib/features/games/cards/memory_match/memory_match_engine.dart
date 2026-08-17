/// Memory match engine: flip two cards at a time and remember where the
/// pairs are. Fewer moves and less time mean a higher score; a paid hint
/// briefly peeks at the whole board.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import 'memory_match_cards.dart';
import 'memory_match_logic.dart';

/// Catalog engine for the `memory_match` template.
class MemoryMatchEngine implements GameEngine {
  const MemoryMatchEngine();

  @override
  String get templateId => 'memory_match';

  @override
  String get instructions =>
      'Flip two cards at a time and remember where the matching pairs are. '
      'Match every pair in as few moves and as little time as you can — '
      'a hint briefly reveals the whole board.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => MemoryMatchGame(session: session);
}

/// The memory-match gameplay screen for one session.
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  static const _columns = 4;
  static const _mismatchReveal = Duration(milliseconds: 900);

  late final MemoryLogic _logic;
  late final int _peekSec;
  late final int _rows;

  int _seconds = 0;
  bool _peeking = false;
  Timer? _secondsTimer;
  _PausableTimer? _mismatchTimer;
  _PausableTimer? _peekTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    var pairs = _bounded(cfg.getInt('pairs', 8), 4, 26);
    if (pairs.isOdd) pairs -= 1; // keep the 4-column grid rectangular
    _peekSec = _bounded(cfg.getInt('peekSec', 2), 1, 5);
    _rows = (pairs * 2) ~/ _columns;
    _logic = MemoryLogic(pairs: pairs, random: Random());
    widget.session.onHintGranted = _applyHint;
    widget.session.addListener(_onSessionChanged);
    _secondsTimer = Timer.periodic(const Duration(seconds: 1), _onSecondTick);
    _pushHud();
  }

  @override
  void dispose() {
    _secondsTimer?.cancel();
    _mismatchTimer?.cancel();
    _peekTimer?.cancel();
    super.dispose();
  }

  static int _bounded(int value, int min, int max) =>
      value < min ? min : (value > max ? max : value);

  bool get _interactive =>
      !widget.session.isPaused &&
      !widget.session.isFinished &&
      !_peeking &&
      !_logic.isLocked &&
      !_logic.isWon;

  void _onSessionChanged() {
    final session = widget.session;
    if (session.isFinished) {
      _secondsTimer?.cancel();
      _mismatchTimer?.cancel();
      _peekTimer?.cancel();
    } else if (session.isPaused) {
      _mismatchTimer?.pause();
      _peekTimer?.pause();
    } else {
      _mismatchTimer?.resume();
      _peekTimer?.resume();
    }
    if (mounted) setState(() {});
  }

  void _onSecondTick(Timer _) {
    if (widget.session.isPaused || widget.session.isFinished || _logic.isWon) {
      return;
    }
    _seconds += 1;
    _pushHud();
  }

  int get _score {
    final raw = 1000 - _logic.moves * 20 - _seconds * 5;
    return raw < 0 ? 0 : raw;
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _score,
      status: 'Moves ${_logic.moves}',
      detail: 'Pairs ${_logic.matchedPairs}/${_logic.pairCount}',
      progress: _logic.matchedPairs / _logic.pairCount,
    );
  }

  void _onCardTap(int index) {
    if (!_interactive) return;
    switch (_logic.flip(index)) {
      case MemoryFlipResult.ignored:
        break;
      case MemoryFlipResult.firstCard:
        AudioService.I.sfx(SfxKeys.flip);
        HapticFeedback.selectionClick();
      case MemoryFlipResult.matched:
        AudioService.I.sfx(SfxKeys.matchFound);
        HapticFeedback.mediumImpact();
        _pushHud();
        if (_logic.isWon) {
          _secondsTimer?.cancel();
          AudioService.I.sfx(SfxKeys.win);
          widget.session.finish(
            won: true,
            score: _score,
            stats: {'moves': _logic.moves, 'seconds': _seconds},
          );
        }
      case MemoryFlipResult.mismatched:
        AudioService.I.sfx(SfxKeys.mismatch);
        HapticFeedback.lightImpact();
        _pushHud();
        _mismatchTimer?.cancel();
        _mismatchTimer = _PausableTimer(
          duration: _mismatchReveal,
          callback: _resolveMismatch,
        )..start();
    }
    if (mounted) setState(() {});
  }

  void _resolveMismatch() {
    _logic.resolveMismatch();
    _pushHud();
    if (mounted) setState(() {});
  }

  Future<void> _requestHint() async {
    // The shell applies the hint via onHintGranted after payment; a false
    // return just means the request was declined.
    await widget.session.requestHint();
  }

  void _applyHint() {
    final session = widget.session;
    if (session.isPaused || session.isFinished || _logic.isWon) return;
    _peekTimer?.cancel();
    _peeking = true;
    if (mounted) setState(() {});
    _peekTimer = _PausableTimer(
      duration: Duration(seconds: _peekSec),
      callback: () {
        _peeking = false;
        if (mounted) setState(() {});
      },
    )..start();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: _columns / _rows,
                child: _buildGrid(),
              ),
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

  Widget _buildGrid() {
    final palette = widget.session.palette;
    return Semantics(
      label: 'Memory board with ${_logic.pairCount} hidden pairs',
      child: Container(
        decoration: BoxDecoration(
          color: palette.boardB,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            for (var r = 0; r < _rows; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < _columns; c++)
                      Expanded(child: _buildCell(r, c)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final palette = widget.session.palette;
    final index = r * _columns + c;
    final card = _logic.cardAt(index);
    final state = _logic.stateAt(index);
    final revealed = _peeking || state != MemoryCardState.faceDown;
    final mismatch = _logic.pendingMismatch?.contains(index) ?? false;
    return Semantics(
      button: true,
      label: revealed
          ? 'Card ${rankLabel(card.rank)} of ${suitName(card.suit)}'
          : 'Hidden card row ${r + 1} column ${c + 1}',
      child: GestureDetector(
        onTap: () => _onCardTap(index),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: state == MemoryCardState.matched ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: revealed
                ? MemoryCardFace(rank: card.rank, suit: card.suit)
                : MemoryCardBack(
                    color: palette.accent,
                    highlighted: mismatch,
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

/// A [Timer] that survives session pauses: it tracks elapsed time with a
/// stopwatch and re-arms itself with the remaining duration on resume.
class _PausableTimer {
  _PausableTimer({required this.duration, required this.callback});

  final Duration duration;
  final VoidCallback callback;
  final Stopwatch _watch = Stopwatch();
  Timer? _timer;

  void start() {
    _watch
      ..reset()
      ..start();
    _timer = Timer(duration, _fire);
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    _watch.stop();
  }

  void resume() {
    if (_timer != null || _watch.elapsed >= duration) return;
    _watch.start();
    _timer = Timer(duration - _watch.elapsed, _fire);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _watch.stop();
  }

  void _fire() {
    _timer = null;
    _watch.stop();
    callback();
  }
}

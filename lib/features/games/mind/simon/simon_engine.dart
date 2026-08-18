/// Simon engine — classic four-pad sequence recall. Playback flashes pads
/// with tone1..tone4 at the configured pace (pausing pauses it mid-flash),
/// then the player repeats the sequence. Wrong pad offers one continue via
/// the session (revive replays the same sequence); reaching length 15 wins.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../core/utils/formatters.dart';
import 'simon_logic.dart';

class SimonEngine implements GameEngine {
  const SimonEngine();

  @override
  String get templateId => 'simon';

  @override
  String get instructions =>
      'Watch the pads flash, then tap them back in the same order. Every '
      'correct sequence adds one more step — a wrong tap ends the run, and '
      'reaching 15 steps beats the game.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => true;

  @override
  Widget build(GameSessionController session) => SimonGame(session: session);
}

enum _SimonPhase { idle, playback, input, continuePrompt }

class SimonGame extends StatefulWidget {
  const SimonGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<SimonGame> createState() => _SimonGameState();
}

class _SimonGameState extends State<SimonGame> {
  static const int _roundCap = 15;
  static final List<Color> _padColors = [
    kPieceColors[0],
    kPieceColors[1],
    kPieceColors[2],
    kPieceColors[3],
  ];
  static const List<IconData> _padIcons = [
    Icons.circle,
    Icons.square,
    Icons.change_history,
    Icons.star,
  ];
  static const List<String> _tones = [
    SfxKeys.tone1,
    SfxKeys.tone2,
    SfxKeys.tone3,
    SfxKeys.tone4,
  ];

  late SimonLogic _logic;
  _SimonPhase _phase = _SimonPhase.idle;
  int? _activePad;
  int _score = 0;
  int _stepMs = 550;
  bool _disposed = false;
  bool _continueInFlight = false;

  GameSessionController get _session => widget.session;

  @override
  void initState() {
    super.initState();
    final cfg = _session.config;
    _stepMs = cfg.getInt('stepMs', 550).clamp(250, 1500).toInt();
    final startLength = cfg.getInt('startLength', 3).clamp(1, 6).toInt();
    _logic = SimonLogic(
      startLength: startLength,
      roundCap: _roundCap,
      // Seeded from the definition id: same variant, same sequence growth
      // order — fully offline and reproducible.
      random: Random(stableHash(_session.definition.id)),
    );
    // The shell invokes this after a continue was granted (before
    // requestContinue resolves true) — revive immediately.
    _session.onExtraLifeGranted = _onExtraLife;
    WidgetsBinding.instance.addPostFrameCallback((_) => _nextRound());
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get _alive => !_disposed && mounted && !_session.isFinished;

  Future<void> _nextRound() async {
    if (!_alive) return;
    _logic.beginRound();
    _phase = _SimonPhase.playback;
    _pushHud();
    setState(() {});
    await _playSequence();
    if (!_alive) return;
    _phase = _SimonPhase.input;
    _pushHud();
    setState(() {});
  }

  Future<void> _playSequence() async {
    final onMs = max(180, (_stepMs * 0.55).toInt());
    for (final pad in _logic.sequence) {
      await _delayMs(max(120, _stepMs - onMs));
      if (!_alive) return;
      await _flashPad(pad, onMs);
      if (!_alive) return;
    }
  }

  Future<void> _flashPad(int pad, int ms) async {
    if (!_alive) return;
    setState(() => _activePad = pad);
    unawaited(AudioService.I.sfx(_tones[pad]));
    await _delayMs(ms);
    if (!mounted || _disposed) return;
    setState(() => _activePad = null);
  }

  /// Pause-aware delay: counts down only while the session runs, so a pause
  /// freezes playback mid-flash (the pad stays lit) and mid-gap.
  Future<void> _delayMs(int ms) async {
    var remaining = ms;
    while (remaining > 0 && _alive) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (!_alive) return;
      if (!_session.isPaused) remaining -= 25;
    }
  }

  void _pushHud() {
    _session.updateHud(
      score: _score,
      status: 'Length ${_logic.length}',
      detail: switch (_phase) {
        _SimonPhase.playback => 'Watch',
        _SimonPhase.input => 'Your turn',
        _SimonPhase.continuePrompt => 'Continue?',
        _SimonPhase.idle => 'Get ready',
      },
    );
  }

  Future<void> _onPadTap(int pad) async {
    if (_phase != _SimonPhase.input ||
        _session.isPaused ||
        _continueInFlight ||
        !_alive) {
      return;
    }
    final onMs = max(180, (_stepMs * 0.5).toInt());
    await _flashPad(pad, onMs);
    if (!_alive) return;
    switch (_logic.input(pad)) {
      case SimonInputResult.advance:
        return;
      case SimonInputResult.ignored:
        return;
      case SimonInputResult.roundComplete:
        _score += 100 * _logic.length;
        _pushHud();
        if (_logic.isCapRound) {
          _finish(won: true, capBonus: true);
          return;
        }
        AudioService.I.sfx(SfxKeys.correct);
        await _delayMs(650);
        if (!_alive) return;
        await _nextRound();
      case SimonInputResult.wrong:
        await _onWrongInput();
    }
  }

  Future<void> _onWrongInput() async {
    AudioService.I.sfx(SfxKeys.wrong);
    HapticFeedback.heavyImpact();
    _phase = _SimonPhase.continuePrompt;
    _pushHud();
    setState(() {});
    // Ask BEFORE finishing; a declined (offline / no ad) request finishes
    // the run. When true is returned, onExtraLifeGranted has already run
    // and revived the player.
    _continueInFlight = true;
    final granted = await _session.requestContinue();
    _continueInFlight = false;
    if (!_alive) return;
    if (!granted) {
      _finish(won: false);
      return;
    }
    // Defensive revive in case a shell granted the continue without firing
    // the callback.
    if (_phase != _SimonPhase.input) _onExtraLife();
  }

  void _onExtraLife() {
    if (!_alive) return;
    _logic.revive();
    _phase = _SimonPhase.input;
    AudioService.I.sfx(SfxKeys.hint);
    _pushHud();
    setState(() {});
  }

  void _finish({required bool won, bool capBonus = false}) {
    if (_session.isFinished) return;
    if (capBonus) {
      _score += 1000;
      AudioService.I.sfx(SfxKeys.win);
    } else if (won) {
      AudioService.I.sfx(SfxKeys.win);
    } else {
      AudioService.I.sfx(SfxKeys.lose);
    }
    _pushHud();
    _session.finish(
      won: won,
      score: _score,
      stats: {'length': _logic.length},
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) => AspectRatio(
            aspectRatio: 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Semantics(
                label: 'Simon board, four coloured pads. '
                    '${_phase == _SimonPhase.playback ? 'Watch the sequence' : 'Repeat the sequence'}, '
                    'length ${_logic.length}.',
                child: Column(
                  children: [
                    for (var r = 0; r < 2; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < 2; c++)
                              Expanded(child: _pad(r * 2 + c, constraints)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pad(int index, BoxConstraints constraints) {
    final palette = _session.palette;
    final color = _padColors[index];
    final flashing = _activePad == index;
    final enabled = _phase == _SimonPhase.input &&
        !_session.isPaused &&
        !_session.isFinished &&
        !_continueInFlight;
    final radius = constraints.biggest.shortestSide * 0.06;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Pad ${index + 1}, ${_padName(index)}',
        child: GestureDetector(
          onTap: enabled ? () => _onPadTap(index) : null,
          child: AnimatedContainer(
            duration: Duration(milliseconds: flashing ? 40 : 160),
            decoration: BoxDecoration(
              color: flashing ? color : palette.boardB.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: color, width: flashing ? 0 : 6),
            ),
            child: Icon(
              _padIcons[index],
              size: 56,
              color: flashing
                  ? GamePalette.contrastOn(color)
                  : color,
            ),
          ),
        ),
      ),
    );
  }

  static String _padName(int index) => switch (index) {
        0 => 'blue circle',
        1 => 'orange square',
        2 => 'green triangle',
        _ => 'purple star',
      };
}

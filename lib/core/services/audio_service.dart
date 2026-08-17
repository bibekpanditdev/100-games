/// Centralized offline audio system (add-on spec: Sound & Audio).
///
/// ONE singleton every engine and screen calls into — engines never manage
/// their own players:
///   AudioService.I.sfx('correct');
///   AudioService.I.playBgm('mind_loop');
///   AudioService.I.updateSettings(soundOn: ..., musicOn: ..., ...);
///
/// * All assets are bundled WAVs under assets/audio/ — zero network.
/// * Short SFX are preloaded via AudioCache for low latency; overlapping
///   rapid-fire SFX are supported (each play gets its own player).
/// * BGM loops with a ~250 ms volume crossfade when switching or muting.
/// * Every method fails silently — audio can never crash or block gameplay.
/// * Respects Android silent/vibrate mode via respectSilence.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract final class SfxKeys {
  // UI
  static const uiTap = 'ui_tap';
  static const uiToggle = 'ui_toggle';
  static const uiError = 'ui_error';
  static const uiTransition = 'ui_transition';
  // Rewards
  static const unlock = 'unlock';
  static const coin = 'coin';
  static const levelup = 'levelup';
  static const streak = 'streak';
  static const challenge = 'challenge';
  // Generic game events
  static const correct = 'correct';
  static const wrong = 'wrong';
  static const place = 'place';
  static const flip = 'flip';
  static const matchFound = 'match_found';
  static const mismatch = 'mismatch';
  static const win = 'win';
  static const lose = 'lose';
  static const hint = 'hint';
  // Sequence tones
  static const tone1 = 'tone1';
  static const tone2 = 'tone2';
  static const tone3 = 'tone3';
  static const tone4 = 'tone4';
  // Word
  static const letter = 'letter';
  static const wordFound = 'word_found';
  // Cards
  static const deal = 'deal';
  static const shuffle = 'shuffle';
  // Arcade
  static const hit = 'hit';
  static const jump = 'jump';
  static const die = 'die';
  static const powerup = 'powerup';
  static const tick = 'tick';
  // Spatial
  static const pickup = 'pickup';
  static const snap = 'snap';
  static const rotate = 'rotate';
  static const solved = 'solved';
}

class AudioService {
  AudioService._();

  static final AudioService I = AudioService._();

  static const List<String> _sfxKeys = [
    'ui_tap', 'ui_toggle', 'ui_error', 'ui_transition', 'unlock', 'coin',
    'levelup', 'streak', 'challenge', 'correct', 'wrong', 'place', 'flip',
    'match_found', 'mismatch', 'win', 'lose', 'hint', 'tone1', 'tone2',
    'tone3', 'tone4', 'letter', 'word_found', 'deal', 'shuffle', 'hit',
    'jump', 'die', 'powerup', 'tick', 'pickup', 'snap', 'rotate', 'solved',
  ];

  final AudioCache _cache = AudioCache(prefix: 'audio/sfx/');
  final AudioPlayer _bgm = AudioPlayer(playerId: 'tg_bgm');

  bool _initialized = false;
  bool _soundOn = true;
  bool _musicOn = true;
  double _sfxVolume = 0.8;
  double _musicVolume = 0.6;
  double _currentBgmVolume = 0.0;

  String? _targetTrack;
  Timer? _fadeTimer;

  bool get musicOn => _musicOn;

  /// Preloads SFX clips and configures the audio context. Fire-and-forget
  /// from main(); failures just mean silence, never errors.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          respectSilence: true,
          stayAwake: false,
        ).build(),
      );
    } catch (_) {}
    try {
      await _cache.loadAll([for (final k in _sfxKeys) '$k.wav']);
    } catch (e) {
      debugPrint('SFX preload skipped: $e');
    }
    if (_musicOn) {
      unawaited(playBgm('menu_loop'));
    }
  }

  /// Pushed from the settings controller whenever audio settings change —
  /// applies instantly, no restart needed.
  void updateSettings({
    required bool soundOn,
    required bool musicOn,
    required double sfxVolume,
    required double musicVolume,
  }) {
    _soundOn = soundOn;
    _sfxVolume = sfxVolume.clamp(0.0, 1.0);
    _musicVolume = musicVolume.clamp(0.0, 1.0);

    final wasMusicOn = _musicOn;
    _musicOn = musicOn;
    if (!musicOn && wasMusicOn) {
      _fadeOutBgm();
    } else if (musicOn && !wasMusicOn && _targetTrack != null) {
      unawaited(_startBgm(_targetTrack!));
    } else if (musicOn) {
      // Live volume change while playing.
      _currentBgmVolume = _musicVolume;
      unawaited(_bgm.setVolume(_musicVolume));
    }
  }

  /// Plays a short effect. Never throws; no-ops when muted or not loaded.
  Future<void> sfx(String key) async {
    if (!_initialized || !_soundOn || !_sfxKeys.contains(key)) return;
    try {
      final player = AudioPlayer();
      await player.play(
        AssetSource('audio/sfx/$key.wav'),
        volume: _sfxVolume,
        mode: PlayerMode.lowLatency,
      );
    } catch (_) {}
  }

  /// Switches background music with a short crossfade. Repeated calls with
  /// the same track are ignored.
  Future<void> playBgm(String track) async {
    if (!_initialized) return;
    if (_targetTrack == track && _musicOn) return;
    _targetTrack = track;
    if (!_musicOn) return;
    await _startBgm(track);
  }

  Future<void> _startBgm(String track) async {
    try {
      _cancelFade();
      await _bgm.stop();
      await _bgm.setReleaseMode(ReleaseMode.loop);
      await _bgm.setSourceAsset('audio/bgm/$track.wav');
      _currentBgmVolume = 0.0;
      await _bgm.setVolume(0);
      await _bgm.resume();
      await _fadeInBgm();
    } catch (_) {
      // Missing/failed audio is never fatal.
    }
  }

  /// Smoothly silences BGM (muting must not cut with a pop).
  Future<void> _fadeOutBgm() async {
    _cancelFade();
    var v = _currentBgmVolume;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 30), (t) async {
      v -= 0.12;
      if (v <= 0.01) {
        t.cancel();
        _currentBgmVolume = 0.0;
        await _bgm.pause();
      } else {
        _currentBgmVolume = v;
        try {
          await _bgm.setVolume(v);
        } catch (_) {}
      }
    });
  }

  Future<void> _fadeInBgm() async {
    _cancelFade();
    var v = 0.0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 30), (t) async {
      v += 0.08;
      if (v >= _musicVolume) {
        t.cancel();
        v = _musicVolume;
      }
      _currentBgmVolume = v;
      try {
        await _bgm.setVolume(v);
      } catch (_) {}
    });
  }

  void _cancelFade() {
    _fadeTimer?.cancel();
    _fadeTimer = null;
  }

  /// Called from the game shell: picks the category-flavoured in-game loop.
  static String bgmForCategory(String categoryName) => switch (categoryName) {
        'mind' => 'mind_loop',
        'arcade' => 'arcade_loop',
        _ => 'game_loop',
      };
}

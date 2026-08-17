/// Haptic + sound feedback helpers, respecting the user's settings.
/// Sound goes through the centralized [AudioService]; haptics use the
/// platform channel. All calls are cheap and safe to sprinkle across UI.
library;

import 'package:flutter/services.dart';

import 'audio_service.dart';

abstract final class AppFeedback {
  static bool _hapticsOn = true;
  static bool _soundOn = true;

  /// Called once at startup and whenever settings change.
  static void configure({required bool hapticsOn, required bool soundOn}) {
    _hapticsOn = hapticsOn;
    _soundOn = soundOn;
  }

  static void tap() {
    if (_hapticsOn) HapticFeedback.lightImpact();
    if (_soundOn) AudioService.I.sfx(SfxKeys.uiTap);
  }

  static void toggle() {
    if (_hapticsOn) HapticFeedback.lightImpact();
    if (_soundOn) AudioService.I.sfx(SfxKeys.uiToggle);
  }

  static void transition() {
    if (_soundOn) AudioService.I.sfx(SfxKeys.uiTransition);
  }

  static void success() {
    if (_hapticsOn) HapticFeedback.mediumImpact();
    if (_soundOn) AudioService.I.sfx(SfxKeys.correct);
  }

  static void error() {
    if (_hapticsOn) HapticFeedback.vibrate();
    if (_soundOn) AudioService.I.sfx(SfxKeys.uiError);
  }

  static void win() {
    if (_hapticsOn) HapticFeedback.heavyImpact();
    if (_soundOn) AudioService.I.sfx(SfxKeys.win);
  }

  static void lose() {
    if (_hapticsOn) HapticFeedback.vibrate();
    if (_soundOn) AudioService.I.sfx(SfxKeys.lose);
  }

  static void coin() {
    if (_soundOn) AudioService.I.sfx(SfxKeys.coin);
  }

  static void unlock() {
    if (_soundOn) AudioService.I.sfx(SfxKeys.unlock);
  }
}

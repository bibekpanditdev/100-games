/// User settings persisted in the Hive `settings` box.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._box);

  final Box _box;

  bool get soundOn => _box.get('soundOn', defaultValue: true) as bool;
  bool get musicOn => _box.get('musicOn', defaultValue: true) as bool;
  bool get hapticsOn => _box.get('hapticsOn', defaultValue: true) as bool;
  bool get reducedMotion => _box.get('reducedMotion', defaultValue: false) as bool;

  /// 0.0..1.0 — moderate defaults, not full blast (add-on spec §4).
  double get sfxVolume => (_box.get('sfxVolume', defaultValue: 0.8) as num).toDouble();
  double get musicVolume => (_box.get('musicVolume', defaultValue: 0.6) as num).toDouble();

  ThemeMode get themeMode => switch (_box.get('themeMode', defaultValue: 'system') as String) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void setSound(bool v) => _set('soundOn', v);
  void setMusic(bool v) => _set('musicOn', v);
  void setHaptics(bool v) => _set('hapticsOn', v);
  void setReducedMotion(bool v) => _set('reducedMotion', v);
  void setSfxVolume(double v) => _set('sfxVolume', v.clamp(0.0, 1.0));
  void setMusicVolume(double v) => _set('musicVolume', v.clamp(0.0, 1.0));

  void setThemeMode(ThemeMode mode) => _set(
        'themeMode',
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      );

  void _set(String key, Object value) {
    _box.put(key, value);
    notifyListeners();
  }

  Future<void> resetSettings() async {
    await _box.clear();
    notifyListeners();
  }
}

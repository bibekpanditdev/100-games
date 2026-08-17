/// Root MaterialApp — light/dark themes, settings-reactive theme mode.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing.dart';
import 'core/services/audio_service.dart';
import 'core/services/feedback.dart';
import 'core/theme/app_theme.dart';
import 'features/catalog/presentation/catalog_providers.dart';
import 'features/settings/settings_controller.dart';

class ThousandGamesApp extends ConsumerWidget {
  const ThousandGamesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    MotionSettings.reduced = settings.reducedMotion;
    AppFeedback.configure(hapticsOn: settings.hapticsOn, soundOn: settings.soundOn);
    AudioService.I.updateSettings(
      soundOn: settings.soundOn,
      musicOn: settings.musicOn,
      sfxVolume: settings.sfxVolume,
      musicVolume: settings.musicVolume,
    );

    return MaterialApp(
      title: '1000+ Games',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: settings.themeMode,
      initialRoute: Routes.splash,
      onGenerateRoute: onGenerateRoute,
    );
  }
}

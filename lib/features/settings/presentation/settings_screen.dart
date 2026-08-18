/// Settings screen: gameplay toggles, appearance, optional Google Play
/// Games sign-in, destructive progress reset and about (spec §7).
///
/// Taps go through [AppFeedback.tap] (configure is wired through
/// [settingsProvider] in `app.dart`, so toggles take effect immediately).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feedback.dart';
import '../../../core/services/play_games_service.dart';
import '../../../shared/widgets/app_dialogs.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../achievements/presentation/achievements_screen.dart'
    show achievementStatesProvider;
import '../../catalog/presentation/catalog_providers.dart';
import '../../leaderboards/presentation/leaderboards_screen.dart'
    show topScoresProvider;
import '../settings_controller.dart';

/// All user-facing preferences, grouped into sections.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Mirrors [PlayGamesService.signedIn] so sign-in attempts update the tile.
  bool _pgSignedIn = PlayGamesService.instance.signedIn;

  /// Signs in (or, when already signed in, opens the native leaderboard UI).
  /// [PlayGamesService] never throws — offline devices get a snackbar.
  Future<void> _handlePlayGamesTap() async {
    AppFeedback.tap();
    if (PlayGamesService.instance.signedIn) {
      await PlayGamesService.instance.showLeaderboards();
      return;
    }
    try {
      final signedIn = await PlayGamesService.instance.signIn();
      if (!mounted) return;
      setState(() => _pgSignedIn = signedIn);
      _snack(
        signedIn
            ? 'Signed in to Google Play Games'
            : 'Sign-in unavailable offline',
      );
    } catch (_) {
      if (mounted) _snack('Sign-in unavailable offline');
    }
  }

  /// Destructive reset of every local store, behind a confirm dialog.
  Future<void> _resetProgress() async {
    AppFeedback.tap();
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: 'Reset all progress?',
      message: 'This permanently clears coins, streaks, scores and '
          'achievements on this device.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    await ref.read(progressProvider).resetAll();
    await ref.read(scoresRepoProvider).resetAll();
    await ref.read(achievementsServiceProvider).resetAll();
    ref
      ..invalidate(achievementStatesProvider)
      ..invalidate(topScoresProvider)
      ..invalidate(gameBestProvider);

    if (!mounted) return;
    AppFeedback.success();
    _snack('Progress reset');
  }

  void _setThemeMode(ThemeMode? mode) {
    if (mode == null) return;
    AppFeedback.tap();
    ref.read(settingsProvider).setThemeMode(mode);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SectionHeader(title: 'Gameplay'),
          _settingSwitch(
            title: 'Sound effects',
            value: settings.soundOn,
            onToggle: settings.setSound,
          ),
          _settingSwitch(
            title: 'Music',
            subtitle: 'Looping background music per screen and category',
            value: settings.musicOn,
            onToggle: settings.setMusic,
          ),
          _volumeSlider(
            title: 'Sound effects volume',
            icon: Icons.volume_up,
            value: settings.sfxVolume,
            onChanged: settings.setSfxVolume,
          ),
          _volumeSlider(
            title: 'Music volume',
            icon: Icons.music_note,
            value: settings.musicVolume,
            onChanged: settings.setMusicVolume,
          ),
          _settingSwitch(
            title: 'Haptics',
            value: settings.hapticsOn,
            onToggle: settings.setHaptics,
          ),
          _settingSwitch(
            title: 'Reduce motion',
            subtitle: 'Reduces animations and confetti',
            value: settings.reducedMotion,
            onToggle: settings.setReducedMotion,
          ),
          const SectionHeader(title: 'Appearance'),
          _themeOption(
            ThemeMode.system,
            'System',
            Icons.brightness_auto_outlined,
            settings,
          ),
          _themeOption(
            ThemeMode.light,
            'Light',
            Icons.light_mode_outlined,
            settings,
          ),
          _themeOption(
            ThemeMode.dark,
            'Dark',
            Icons.dark_mode_outlined,
            settings,
          ),
          const SectionHeader(title: 'Google Play Games'),
          Semantics(
            button: true,
            label: _pgSignedIn
                ? 'Google Play Games, signed in'
                : 'Google Play Games, not signed in',
            child: ListTile(
              leading: Icon(
                _pgSignedIn
                    ? Icons.cloud_done_outlined
                    : Icons.sports_esports_outlined,
                color: _pgSignedIn ? scheme.primary : null,
              ),
              title: Text(_pgSignedIn ? 'Signed in' : 'Sign in'),
              subtitle: Text(
                _pgSignedIn
                    ? 'Leaderboards sync when online'
                    : 'Optional — syncs leaderboards when online',
              ),
              trailing: _pgSignedIn
                  ? const Icon(Icons.check_circle_outline)
                  : const Icon(Icons.chevron_right),
              onTap: _handlePlayGamesTap,
            ),
          ),
          const SectionHeader(title: 'Data'),
          ListTile(
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text(
              'Reset all progress',
              style: TextStyle(color: scheme.error),
            ),
            subtitle: const Text(
              'Clears coins, streaks, scores and achievements',
            ),
            onTap: _resetProgress,
          ),
          const SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.videogame_asset_outlined),
            title: Text('1000+ Games'),
            subtitle: Text('Version 1.0.0'),
          ),
          const ListTile(
            leading: Icon(Icons.flutter_dash),
            title: Text('Made with Flutter'),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('All games work fully offline'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Material 3 switch tile (min height well above the 48dp target).
  Widget _settingSwitch({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (next) {
        AppFeedback.tap();
        onToggle(next);
      },
    );
  }

  Widget _themeOption(
    ThemeMode mode,
    String label,
    IconData icon,
    SettingsController settings,
  ) {
    return RadioListTile<ThemeMode>(
      value: mode,
      groupValue: settings.themeMode,
      onChanged: _setThemeMode,
      secondary: Icon(icon),
      title: Text(label),
    );
  }

  /// Volume row: icon + slider with a live percentage label. Applies
  /// instantly via the settings controller → AudioService bridge.
  Widget _volumeSlider({
    required String title,
    required IconData icon,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    return Semantics(
      label: title,
      value: '${(value * 100).round()} percent',
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: SizedBox(
          width: 160,
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: value,
                  divisions: 10,
                  label: '${(value * 100).round()}%',
                  onChanged: onChanged,
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '${(value * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

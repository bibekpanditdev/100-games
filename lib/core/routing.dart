/// Central route table with fade-through transitions (Material motion).
/// Honors the reduced-motion setting by switching to instant transitions.
library;

import 'package:flutter/material.dart';

import '../features/catalog/presentation/browse_screen.dart';
import '../features/catalog/presentation/home_screen.dart';
import '../features/catalog/domain/game_definition.dart';
import '../features/game_player/game_player_screen.dart';
import '../features/game_player/results_payload.dart';
import '../features/game_player/results_screen.dart';
import '../features/leaderboards/presentation/leaderboards_screen.dart';
import '../features/achievements/presentation/achievements_screen.dart';
import '../features/mind/presentation/brain_dashboard_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../shared/splash_screen.dart';

abstract final class Routes {
  static const String splash = '/';
  static const String home = '/home';
  static const String browse = '/browse';
  static const String game = '/game';
  static const String results = '/results';
  static const String leaderboards = '/leaderboards';
  static const String achievements = '/achievements';
  static const String settings = '/settings';
  static const String brain = '/brain';
}

/// Set from main()/settings so transitions can honor reduced motion.
class MotionSettings {
  MotionSettings._();
  static bool reduced = false;
}

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  RoutePageBuilder builder;
  switch (settings.name) {
    case Routes.splash:
      builder = (_, __, ___) => const SplashScreen();
    case Routes.home:
      builder = (_, __, ___) => const HomeScreen();
    case Routes.browse:
      final args = settings.arguments;
      builder = (_, __, ___) => BrowseScreen(
        initialCategory: args is GameCategory ? args : null,
        initialQuery: args is String ? args : '',
      );
    case Routes.game:
      builder = (_, __, ___) => GamePlayerScreen(gameId: settings.arguments! as String);
    case Routes.results:
      builder = (_, __, ___) =>
          ResultsScreen(payload: settings.arguments! as ResultsPayload);
    case Routes.leaderboards:
      builder = (_, __, ___) => const LeaderboardsScreen();
    case Routes.achievements:
      builder = (_, __, ___) => const AchievementsScreen();
    case Routes.settings:
      builder = (_, __, ___) => const SettingsScreen();
    case Routes.brain:
      builder = (_, __, ___) => const BrainDashboardScreen();
    default:
      builder = (_, __, ___) => const SplashScreen();
  }
  return _fadeThrough(builder, settings);
}

PageRoute<T> _fadeThrough<T>(RoutePageBuilder builder, RouteSettings settings) {
  final duration = MotionSettings.reduced
      ? const Duration(milliseconds: 80)
      : const Duration(milliseconds: 300);
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: builder,
    transitionsBuilder: (_, animation, __, child) {
      if (MotionSettings.reduced) return child;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

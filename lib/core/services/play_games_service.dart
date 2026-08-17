/// Optional Google Play Games Services wrapper (`games_services` package).
///
/// Signing in is strictly opt-in (Settings screen). Every call is
/// exception-safe and returns false/null when offline, not signed in, or the
/// service is unavailable — the app is fully playable without any of this.
library;

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

class PlayGamesService {
  PlayGamesService._();

  static final PlayGamesService instance = PlayGamesService._();

  bool _signedIn = false;

  bool get signedIn => _signedIn;

  Future<bool> signIn() async {
    if (_signedIn) return true;
    try {
      final ok = await GamesServices.signIn();
      _signedIn = ok?.toLowerCase() == 'true';
    } catch (e) {
      debugPrint('Play Games sign-in failed: $e');
      _signedIn = false;
    }
    return _signedIn;
  }

  /// Leaderboard UI (achievements UI: [showAchievements]).
  Future<void> showLeaderboards() async {
    if (!_signedIn) return;
    try {
      await GamesServices.showLeaderboards();
    } catch (_) {}
  }

  Future<void> showAchievements() async {
    if (!_signedIn) return;
    try {
      await GamesServices.showAchievements();
    } catch (_) {}
  }

  /// Fire-and-forget score sync. Call opportunistically after recording a
  /// local score; failures are silently ignored and local data is the
  /// source of truth.
  Future<void> submitScore({required String leaderboardId, required int score}) async {
    if (!_signedIn) return;
    try {
      await GamesServices.submitScore(
        score: Score(
          androidLeaderboardID: leaderboardId,
          iOSLeaderboardID: leaderboardId,
          value: score,
        ),
      );
    } catch (_) {}
  }

  Future<void> unlockAchievement({required String achievementId}) async {
    if (!_signedIn) return;
    try {
      await GamesServices.unlock(
        achievement: Achievement(
          androidID: achievementId,
          iOSID: achievementId,
        ),
      );
    } catch (_) {}
  }
}

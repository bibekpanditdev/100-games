/// Player progress kept in the Hive `progress` box: coin balance, daily
/// streak, recently played games, play counts and the interstitial
/// frequency-cap counter. All offline, all instant.
library;

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/utils/formatters.dart';

class ProgressController extends ChangeNotifier {
  ProgressController(this._box);

  final Box _box;

  static const int hintCost = 150;
  static const int extraLifeCost = 250;

  int get coins => _box.get('coins', defaultValue: 0) as int;
  int get coinsEarnedTotal => _box.get('coinsEarnedTotal', defaultValue: 0) as int;
  int get streakDays => _box.get('streakDays', defaultValue: 0) as int;
  String? get lastPlayDay => _box.get('lastPlayDay') as String?;

  Map<String, int> get lastPlayed =>
      Map<String, int>.from(_box.get('lastPlayed', defaultValue: {}) as Map);

  Map<String, int> get playCounts =>
      Map<String, int>.from(_box.get('playCounts', defaultValue: {}) as Map);

  int playCountOf(String gameId) => playCounts[gameId] ?? 0;

  bool get canAffordHint => coins >= hintCost;
  bool get canAffordExtraLife => coins >= extraLifeCost;

  void earnCoins(int amount) {
    if (amount <= 0) return;
    _box.put('coins', coins + amount);
    _box.put('coinsEarnedTotal', coinsEarnedTotal + amount);
    notifyListeners();
  }

  /// Returns false when the balance is insufficient.
  bool spendCoins(int amount) {
    if (coins < amount) return false;
    _box.put('coins', coins - amount);
    notifyListeners();
    return true;
  }

  void recordPlay(String gameId) {
    final last = lastPlayed;
    last[gameId] = DateTime.now().millisecondsSinceEpoch;
    _box.put('lastPlayed', last);

    final counts = playCounts;
    counts[gameId] = (counts[gameId] ?? 0) + 1;
    _box.put('playCounts', counts);

    notifyListeners();
  }

  // ---- Adaptive difficulty history (add-on spec §3) ---------------------

  /// Last few star results per engine template, most recent last:
  /// `{'snake': [2, 3, 1]}`. Kept to the 5 most recent entries.
  Map<String, List<int>> get starsByTemplate => Map<String, List<int>>.from(
        (_box.get('starsByTemplate', defaultValue: {}) as Map).map(
          (k, v) => MapEntry(k.toString(), List<int>.from(v as List)),
        ),
      );

  List<int> recentStarsFor(String template) => starsByTemplate[template] ?? const [];

  /// Records a finished session's stars for adaptive difficulty.
  void recordResultForAdaptive(String template, int stars) {
    final map = starsByTemplate;
    final list = [...(map[template] ?? <int>[]), stars];
    map[template] = list.length > 5 ? list.sublist(list.length - 5) : list;
    _box.put('starsByTemplate', map);
  }

  /// Suggested difficulty for a template from recent results:
  /// avg stars >= 2.4 -> hard, >= 1.4 -> medium, else easy. Null when there
  /// isn't enough history yet (fewer than 3 results).
  String? suggestedDifficulty(String template) {
    final list = recentStarsFor(template);
    if (list.length < 3) return null;
    final avg = list.reduce((a, b) => a + b) / list.length;
    if (avg >= 2.4) return 'hard';
    if (avg >= 1.4) return 'medium';
    return 'easy';
  }

  /// Call once per day (any play). Returns the current streak after update.
  /// [now] is injectable for tests.
  int touchDailyStreak({DateTime? now}) {
    final t = now ?? DateTime.now();
    final today = dayKey(t);
    final last = lastPlayDay;
    if (last == today) return streakDays;
    final continued = last != null && last == previousDayKey(today);
    final updated = continued ? streakDays + 1 : 1;
    _box.put('streakDays', updated);
    _box.put('lastPlayDay', today);
    notifyListeners();
    return updated;
  }

  // ---- Interstitial frequency cap (see README monetization section) ----

  /// Returns true when an interstitial may be shown now (every 3rd game exit
  /// and at least 2 minutes since the last one).
  bool shouldShowInterstitial() {
    final count = _box.get('interstitialCount', defaultValue: 0) as int;
    final lastMs = _box.get('lastInterstitialMs', defaultValue: 0) as int;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastMs;
    return count >= 3 && elapsed > 120000;
  }

  void noteGameExit() {
    _box.put('interstitialCount', (_box.get('interstitialCount', defaultValue: 0) as int) + 1);
  }

  void noteInterstitialShown() {
    _box.put('interstitialCount', 0);
    _box.put('lastInterstitialMs', DateTime.now().millisecondsSinceEpoch);
  }

  /// "Remove Ads" / reset progress.
  Future<void> resetAll() async {
    await _box.clear();
    notifyListeners();
  }
}

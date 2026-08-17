/// AdMob wrapper. EVERY method fails gracefully: offline, SDK missing or ad
/// load failures degrade to "no ad" and never block or crash gameplay.
///
/// Frequency policy (spec §4):
///  * Banner on Home + Browse (see [BannerAdSlot]).
///  * Interstitial between game sessions — every 3rd exit, min 2 min apart
///    (counter lives in ProgressController).
///  * Rewarded video for hints / extra lives (shell payment flow).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_units.dart';

class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  bool _initialized = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// True when the SDK initialized successfully (requires network at least
  /// once; offline first launch just means no ads — gameplay unaffected).
  bool get available => _initialized;

  /// Non-blocking, exception-safe init. Called once from main().
  Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _preloadInterstitial();
    } catch (e) {
      debugPrint('Ads init skipped: $e');
    }
  }

  /// Creates a loaded banner for [BannerAdSlot]; null when unavailable.
  Future<BannerAd?> createBanner() async {
    if (!_initialized) return null;
    final completer = Completer<BannerAd?>();
    try {
      BannerAd? banner;
      banner = BannerAd(
        adUnitId: AdUnits.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!completer.isCompleted) completer.complete(banner);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
      await banner.load();
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  void _preloadInterstitial() {
    if (!_initialized) return;
    try {
      InterstitialAd.load(
        adUnitId: AdUnits.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (error) => _interstitial = null,
        ),
      );
    } catch (_) {}
  }

  /// Shows the preloaded interstitial (or skips silently). Invokes [onDone]
  /// always, so navigation never depends on ads.
  Future<void> showInterstitial(VoidCallback onDone) async {
    final ad = _interstitial;
    _interstitial = null;
    _preloadInterstitial();
    if (ad == null) {
      onDone();
      return;
    }
    var closed = false;
    void finish() {
      if (closed) return;
      closed = true;
      onDone();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        finish();
      },
    );
    try {
      await ad.show();
      // Safety net if callbacks never fire.
      Timer(const Duration(seconds: 15), finish);
    } catch (_) {
      ad.dispose();
      finish();
    }
  }

  /// Rewarded-video payment flow. Resolves true ONLY when the user earned
  /// the reward. Any failure (offline, no fill, timeout) resolves false —
  /// callers treat that as "payment declined", never an error.
  Future<bool> showRewarded() async {
    if (!_initialized) return false;
    final loaded = await _loadRewarded();
    if (loaded == null) return false;

    final earned = Completer<bool>();
    var rewardEarned = false;
    var dismissed = false;

    loaded.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        dismissed = true;
        if (!earned.isCompleted) earned.complete(rewardEarned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!earned.isCompleted) earned.complete(false);
      },
    );

    try {
      await loaded.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          rewardEarned = true;
        },
      );
      Timer(const Duration(seconds: 20), () {
        if (!earned.isCompleted) earned.complete(rewardEarned);
      });
      return earned.future;
    } catch (_) {
      if (!earned.isCompleted && !dismissed) return false;
      return earned.future;
    } finally {
      _rewarded = null;
    }
  }

  Future<RewardedAd?> _loadRewarded() async {
    if (_rewarded != null) return _rewarded;
    final completer = Completer<RewardedAd?>();
    try {
      await RewardedAd.load(
        adUnitId: AdUnits.rewarded,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            if (!completer.isCompleted) completer.complete(ad);
          },
          onAdFailedToLoad: (error) {
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }
}

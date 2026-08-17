/// AdMob unit ids.
///
/// These are Google's official TEST units — they always serve test ads and
/// are safe during development. Replace the `_production` values with your
/// real AdMob unit ids before releasing (see README § Monetization); the
/// app automatically picks the production ids in release builds.
library;

import 'package:flutter/foundation.dart';

abstract final class AdUnits {
  // Google AdMob sample/test unit ids.
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // TODO(release): fill in real unit ids before publishing.
  static const String _productionBanner = 'ca-app-pub-0000000000000000/0000000000';
  static const String _productionInterstitial = 'ca-app-pub-0000000000000000/0000000000';
  static const String _productionRewarded = 'ca-app-pub-0000000000000000/0000000000';

  static bool get _useTestUnits => kDebugMode || _productionBanner.contains('0000000000000000');

  static String get banner => _useTestUnits ? _testBanner : _productionBanner;
  static String get interstitial => _useTestUnits ? _testInterstitial : _productionInterstitial;
  static String get rewarded => _useTestUnits ? _testRewarded : _productionRewarded;
}

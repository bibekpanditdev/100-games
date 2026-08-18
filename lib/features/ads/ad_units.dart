/// AdMob unit ids.
///
/// PRODUCTION READY: Using real publisher and unit IDs.
library;

abstract final class AdUnits {
  // Google AdMob sample/test unit ids.
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  // REAL PRODUCTION UNITS - Provided by user.
  static const String _productionBanner = 'ca-app-pub-4281139286593999/1013390223';
  static const String _productionInterstitial = 'ca-app-pub-4281139286593999/5316110661';
  static const String _productionRewarded = 'ca-app-pub-4281139286593999/8911956347';

  /// Determines whether to use test or production units.
  /// Set to false to force real ads immediately.
  static bool get _useTestUnits => false;

  static String get banner => _useTestUnits ? _testBanner : _productionBanner;
  static String get interstitial => _useTestUnits ? _testInterstitial : _productionInterstitial;
  static String get rewarded => _useTestUnits ? _testRewarded : _productionRewarded;
}

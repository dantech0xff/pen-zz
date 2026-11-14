import 'dart:io' show Platform;

/// Ad unit ids. Real ids come from `--dart-define` (or `--dart-define-from-file`, see
/// keys.example.json); a missing or empty id falls back to Google's test ads, which are safe
/// to tap but earn nothing. See docs/kiem-tien.md.
abstract final class AdIds {
  static const _bannerAndroid = String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const _interstitialAndroid = String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const _rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _bannerIos = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _interstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const _rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');

  static String _or(String id, String testId) => id.isEmpty ? testId : id;

  static String get banner => Platform.isIOS
      ? _or(_bannerIos, 'ca-app-pub-3940256099942544/2435281174')
      : _or(_bannerAndroid, 'ca-app-pub-3940256099942544/9214589741');

  static String get interstitial => Platform.isIOS
      ? _or(_interstitialIos, 'ca-app-pub-3940256099942544/4411468910')
      : _or(_interstitialAndroid, 'ca-app-pub-3940256099942544/1033173712');

  static String get rewarded => Platform.isIOS
      ? _or(_rewardedIos, 'ca-app-pub-3940256099942544/1712485313')
      : _or(_rewardedAndroid, 'ca-app-pub-3940256099942544/5224354917');
}

import 'dart:io' show Platform;

/// Ad unit ids. Real ids come from `--dart-define`; without them the build uses Google's test
/// ads, which are safe to tap but earn nothing. See docs/kiem-tien.md.
abstract final class AdIds {
  static const _bannerAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/9214589741',
  );
  static const _interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const _rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const _bannerIos = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/2435281174',
  );
  static const _interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );
  static const _rewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );

  static String get banner => Platform.isIOS ? _bannerIos : _bannerAndroid;
  static String get interstitial => Platform.isIOS ? _interstitialIos : _interstitialAndroid;
  static String get rewarded => Platform.isIOS ? _rewardedIos : _rewardedAndroid;
}

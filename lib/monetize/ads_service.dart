import 'package:flutter/widgets.dart';

/// Ads as the game sees them. The AdMob version runs on Android and iOS; [NoAds] is used on
/// the web build and in tests.
abstract class AdsService extends ChangeNotifier {
  /// True once consent allows ads and the SDK is ready.
  bool get available;

  /// A rewarded ad is loaded and can be shown now.
  bool get rewardedReady;

  /// The privacy message asks for a settings entry to change consent.
  bool get privacyOptionsRequired;

  /// Gathers consent, starts the SDK and preloads ads.
  Future<void> init();

  /// Shows a rewarded ad. Completes with true once the reward is earned.
  Future<bool> showRewarded();

  /// Shows an interstitial if one is loaded. Completes with true when it was shown.
  Future<bool> showInterstitial();

  Future<void> showPrivacyOptions();

  /// An anchored banner as wide as the screen; empty until an ad loads.
  Widget banner();
}

class NoAds extends AdsService {
  @override
  bool get available => false;

  @override
  bool get rewardedReady => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget banner() => const SizedBox.shrink();
}

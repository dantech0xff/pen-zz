import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ads_service.dart';

/// AdMob ads behind Google's consent message (UMP). Ads load only once consent allows them.
class AdMobAds extends AdsService {
  bool _available = false, _privacy = false, _started = false, _showing = false;
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  int _rewardedFails = 0, _interstitialFails = 0;
  Timer? _rewardedRetry, _interstitialRetry;

  @override
  bool get available => _available;

  @override
  bool get rewardedReady => _available && !_showing && _rewarded != null;

  @override
  bool get privacyOptionsRequired => _privacy;

  @override
  Future<void> init() async {
    if (_started) return;
    _started = true;
    await _gatherConsent();
    await _startIfAllowed();
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(tagForUnderAgeOfConsent: false),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  Future<void> _startIfAllowed() async {
    final info = ConsentInformation.instance;
    _privacy = await info.getPrivacyOptionsRequirementStatus() == PrivacyOptionsRequirementStatus.required;
    if (!_available && await info.canRequestAds()) {
      // The game is for players aged 13 and over: no ads rated above Teen.
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.t),
      );
      await MobileAds.instance.initialize();
      _available = true;
      _loadRewarded();
      _loadInterstitial();
    }
    notifyListeners();
  }

  static Duration _backoff(int fails) => Duration(seconds: math.min(300, 15 << math.min(fails - 1, 5)));

  void _loadRewarded() {
    _rewardedRetry?.cancel();
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedFails = 0;
          notifyListeners();
        },
        onAdFailedToLoad: (_) => _rewardedRetry = Timer(_backoff(++_rewardedFails), _loadRewarded),
      ),
    );
  }

  void _loadInterstitial() {
    _interstitialRetry?.cancel();
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialFails = 0;
        },
        onAdFailedToLoad: (_) => _interstitialRetry = Timer(_backoff(++_interstitialFails), _loadInterstitial),
      ),
    );
  }

  /// Shows a full-screen ad and waits until it is closed. Returns whether it appeared.
  ///
  /// If the SDK never reports the ad on screen (for example when no activity is attached),
  /// it gives up after a few seconds so ads keep working and the player can move on.
  Future<bool> _present<T extends AdWithoutView>(
    T ad,
    void Function(FullScreenContentCallback<T> callback) attach,
    Future<void> Function() show,
  ) async {
    final appeared = Completer<bool>(), closed = Completer<void>();
    void finish(Ad a) {
      a.dispose();
      if (!appeared.isCompleted) appeared.complete(false);
      if (!closed.isCompleted) closed.complete();
    }

    attach(
      FullScreenContentCallback<T>(
        onAdShowedFullScreenContent: (_) {
          if (!appeared.isCompleted) appeared.complete(true);
        },
        onAdDismissedFullScreenContent: finish,
        onAdFailedToShowFullScreenContent: (a, _) => finish(a),
      ),
    );
    _showing = true;
    notifyListeners();
    try {
      await show();
      final shown = await appeared.future.timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (shown) {
        await closed.future;
      } else {
        ad.dispose();
      }
      return shown;
    } catch (_) {
      ad.dispose();
      return false;
    } finally {
      _showing = false;
      notifyListeners();
    }
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (!_available || _showing || ad == null) return false;
    _rewarded = null;
    var earned = false;
    try {
      await _present<RewardedAd>(
        ad,
        (c) => ad.fullScreenContentCallback = c,
        () => ad.show(onUserEarnedReward: (_, _) => earned = true),
      );
    } finally {
      _loadRewarded();
    }
    return earned;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (!_available || _showing || ad == null) return false;
    _interstitial = null;
    try {
      return await _present<InterstitialAd>(ad, (c) => ad.fullScreenContentCallback = c, ad.show);
    } finally {
      _loadInterstitial();
    }
  }

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    await _startIfAllowed();
  }

  @override
  Widget banner() => _available ? const _AnchoredBanner() : const SizedBox.shrink();

  @override
  void dispose() {
    _rewardedRetry?.cancel();
    _interstitialRetry?.cancel();
    _rewarded?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}

/// A banner across the bottom of the screen. Taller adaptive sizes fall back to 320×50 so the
/// lobby keeps its room.
class _AnchoredBanner extends StatefulWidget {
  const _AnchoredBanner();

  @override
  State<_AnchoredBanner> createState() => _AnchoredBannerState();
}

class _AnchoredBannerState extends State<_AnchoredBanner> {
  static const double _maxHeight = 90;
  BannerAd? _ad;
  bool _loaded = false;
  int? _width;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final w = MediaQuery.sizeOf(context).width.truncate();
    if (w != _width) {
      _width = w;
      _load(w);
    }
  }

  Future<void> _load(int width) async {
    final adaptive = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted) return;
    final AdSize size = adaptive != null && adaptive.height <= _maxHeight ? adaptive : AdSize.banner;
    _ad?.dispose();
    setState(() => _loaded = false);
    _ad = BannerAd(
      size: size,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}

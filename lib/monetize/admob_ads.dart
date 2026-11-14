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

  /// Disposes a full-screen ad and completes [closed] when it is closed or fails to show.
  FullScreenContentCallback<T> _closer<T extends Ad>(Completer<void> closed) => FullScreenContentCallback<T>(
    onAdDismissedFullScreenContent: (ad) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete();
    },
    onAdFailedToShowFullScreenContent: (ad, _) {
      ad.dispose();
      if (!closed.isCompleted) closed.complete();
    },
  );

  Future<void> _whileShowing(Future<void> Function() run) async {
    _showing = true;
    notifyListeners();
    try {
      await run();
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
    final closed = Completer<void>();
    var earned = false;
    ad.fullScreenContentCallback = _closer<RewardedAd>(closed);
    await _whileShowing(() async {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      await closed.future;
    });
    _loadRewarded();
    return earned;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (!_available || _showing || ad == null) return false;
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = _closer<InterstitialAd>(closed);
    await _whileShowing(() async {
      await ad.show();
      await closed.future;
    });
    _loadInterstitial();
    return true;
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

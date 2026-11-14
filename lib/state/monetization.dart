import 'package:flutter/widgets.dart';

import '../core/mathx.dart';
import '../core/store_catalog.dart';
import '../monetize/ads_service.dart';
import '../monetize/store_service.dart';
import 'game_controller.dart';

/// Ties ads and the store to the player's progress and applies the pacing rules in [AdRules].
class Monetization extends ChangeNotifier {
  Monetization({required this.game, required this.ads, required this.store, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    ads.addListener(notifyListeners);
    // A session starts as if an ad had just closed, so a restart never brings an
    // interstitial sooner than the usual gap.
    _lastFullScreenAd = _clock();
  }

  /// No ads and no store: the web build and widget tests.
  factory Monetization.none(GameController game) => Monetization(game: game, ads: NoAds(), store: const NoStore());

  final GameController game;
  final AdsService ads;
  final StoreService store;
  final DateTime Function() _clock;

  Map<String, String> _prices = const {};
  bool _loadingPrices = false;
  String? _busy;
  late DateTime _lastFullScreenAd;
  final Set<MatchReward> _doubled = {};

  /// Starts consent and the ad SDK, then the store. Call once the first frame is up, because
  /// the consent message needs a screen to show on.
  Future<void> init() async {
    await Future.wait([ads.init(), _initStore()]);
    notifyListeners();
  }

  Future<void> _initStore() async {
    if (store is NoStore) return;
    await store.init(_apply);
    await refreshPrices();
  }

  int _apply(StoreSnapshot snap, {DateTime? purchaseTime}) {
    final coins = game.applyStore(snap, purchaseTime: purchaseTime);
    notifyListeners();
    return coins;
  }

  /// Ties purchases to the player's account (see [StoreService.identify]).
  Future<void> identify(String uid) async {
    final snap = await store.identify(uid);
    if (snap != null) _apply(snap);
  }

  /// This build has ads or a store at all: false on the web build, which shows neither.
  bool get enabled => ads is! NoAds || store is! NoStore;

  // ---------------- ads ----------------

  bool get showBanner => ads.available && !game.save.noAds;

  /// Rewarded "x2" on a finished match: once per match, only when the match paid something.
  bool canDouble(MatchReward r) => ads.available && r.coins > 0 && !_doubled.contains(r);

  bool doubled(MatchReward r) => _doubled.contains(r);

  /// Rewarded ads count as full-screen ads, so an interstitial never follows one straight away.
  Future<bool> _watchRewarded() async {
    final earned = await ads.showRewarded();
    _lastFullScreenAd = _clock();
    return earned;
  }

  /// Shows a rewarded ad and, if it was watched, pays the match reward again.
  Future<bool> doubleReward(MatchReward r) async {
    if (!canDouble(r) || !await _watchRewarded()) return false;
    _doubled.add(r);
    game.addBonus(coins: r.coins, xp: r.xp);
    notifyListeners();
    return true;
  }

  int get freeCoinsLeft {
    final s = game.save;
    final used = s.adDay == dayKey(_clock()) ? s.adCoinsUsed : 0;
    return (AdRules.freeCoinsPerDay - used).clamp(0, AdRules.freeCoinsPerDay);
  }

  int get freeCoinsAmount => AdRules.freeCoins(game.save.stage);

  /// Shows a rewarded ad for free coins. Returns the coins given, or 0.
  Future<int> claimFreeCoins() async {
    if (!ads.available || freeCoinsLeft <= 0 || !await _watchRewarded()) return 0;
    final coins = freeCoinsAmount;
    game.creditAdCoins(dayKey(_clock()), coins);
    notifyListeners();
    return coins;
  }

  bool get interstitialDue {
    final s = game.save;
    if (!ads.available || s.noAds || s.stage < AdRules.interstitialFromStage) return false;
    if (s.matchesSinceAd < AdRules.interstitialEvery) return false;
    return _clock().difference(_lastFullScreenAd) >= AdRules.interstitialGap;
  }

  /// Call when the player leaves a result card; shows an interstitial when one is due.
  Future<void> afterMatch() async {
    if (!interstitialDue || !await ads.showInterstitial()) return;
    _lastFullScreenAd = _clock();
    game.resetAdCounter();
  }

  // ---------------- store ----------------

  bool get storeReady => store.available;

  String get storeUnavailableReason => store.unavailableReason;

  String? priceOf(StoreProductDef p) => _prices[p.id];

  /// The store answered with prices. False after starting offline, until [refreshPrices] works.
  bool get pricesLoaded => _prices.isNotEmpty;

  /// Fetches prices again while some are missing, for example after starting offline.
  Future<void> refreshPrices() async {
    if (!store.available || _loadingPrices || _prices.length == storeProducts.length) return;
    _loadingPrices = true;
    try {
      final fresh = await store.prices([for (final p in storeProducts) p.id]);
      if (fresh.isNotEmpty) _prices = fresh;
    } finally {
      _loadingPrices = false;
      notifyListeners();
    }
  }

  /// The product being bought right now, if any.
  String? get busy => _busy;

  bool owned(StoreProductDef p) {
    if (p.kind == ProductKind.consumable) return false;
    if (p.entitlement == Ent.noAds) return game.save.noAds;
    if (p.coins > 0 && game.save.creditedPacks.contains(p.id)) return true;
    return p.items.isNotEmpty && p.items.every(game.owns);
  }

  /// Buys [p]. Returns a message for the player, or null when there is nothing to say.
  Future<String?> buy(StoreProductDef p) async {
    if (_busy != null) return null;
    _busy = p.id;
    notifyListeners();
    try {
      switch (await store.buy(p.id)) {
        case PurchaseDone(:final snapshot, :final purchaseTime):
          final coins = _apply(snapshot, purchaseTime: purchaseTime);
          if (p.kind == ProductKind.consumable) {
            return coins > 0
                ? 'Đã nhận ${fmtNum(coins)} xu. Cảm ơn bạn!'
                : 'Đã thanh toán. Xu sẽ được cộng ngay khi cửa hàng xác nhận giao dịch.';
          }
          return snapshot.entitlements.contains(p.entitlement)
              ? 'Đã mua ${p.title.toLowerCase()}. Cảm ơn bạn!'
              : 'Đã thanh toán nhưng cửa hàng chưa xác nhận. Vài phút nữa hãy bấm "Khôi phục giao dịch"; '
                    'nếu vẫn chưa có, hãy liên hệ hỗ trợ.';
        case PurchaseCancelled():
          return null;
        case PurchasePending():
          return 'Giao dịch đang chờ thanh toán. Đồ sẽ tự về khi cửa hàng xác nhận.';
        case PurchaseFailed(:final message):
          return message;
      }
    } finally {
      _busy = null;
      notifyListeners();
    }
  }

  /// Restores one-time purchases. Returns a message for the player, or null while another
  /// purchase or restore is still running.
  Future<String?> restore() async {
    if (_busy != null) return null;
    _busy = 'restore';
    notifyListeners();
    try {
      final snap = await store.restore();
      if (snap == null) return 'Không khôi phục được. Kiểm tra mạng rồi thử lại.';
      _apply(snap);
      return snap.entitlements.isEmpty ? 'Không tìm thấy giao dịch nào để khôi phục.' : 'Đã khôi phục giao dịch.';
    } finally {
      _busy = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    ads.removeListener(notifyListeners);
    super.dispose();
  }
}

class MonetizationScope extends InheritedNotifier<Monetization> {
  const MonetizationScope({super.key, required Monetization monetization, required super.child})
    : super(notifier: monetization);

  static Monetization of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MonetizationScope>()!.notifier!;

  static Monetization read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MonetizationScope>()!.notifier!;
}

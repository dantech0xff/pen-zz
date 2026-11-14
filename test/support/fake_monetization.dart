import 'package:flutter/widgets.dart';
import 'package:pen_zz/core/store_catalog.dart';
import 'package:pen_zz/monetize/ads_service.dart';
import 'package:pen_zz/monetize/store_service.dart';

/// Ads that always load; [banner] is as tall as the tallest banner the game accepts.
class FakeAds extends AdsService {
  /// Whether the player watches rewarded ads to the end.
  bool watch = true;
  int interstitials = 0;

  @override
  bool get available => true;

  @override
  bool get rewardedReady => true;

  /// Whether Google's consent message asks for a privacy settings entry (EEA and UK).
  bool privacy = false;

  @override
  bool get privacyOptionsRequired => privacy;

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded() async => watch;

  @override
  Future<bool> showInterstitial() async {
    interstitials++;
    return true;
  }

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget banner() => const SizedBox(key: Key('test-banner'), width: 320, height: 90);
}

/// A store that behaves like RevenueCat: the history lists RevenueCat's own ids, and every
/// snapshot carries the store server's clock. (The real purchase result also carries the
/// store's order id, which never matches the history, so the game ignores it.)
class FakeStore implements StoreService {
  Set<String> entitlements = {};
  final List<StoreTx> history = [];
  void Function(StoreSnapshot snapshot)? listener;

  /// The store server's clock; each purchase moves it on a minute.
  DateTime now = DateTime.utc(2026, 11, 14, 10);
  int _n = 0;

  /// Starts without an answer from the store, as when the game opens offline.
  bool silentInit = false;

  StoreSnapshot get snapshot => StoreSnapshot(Set.of(entitlements), transactions: List.of(history), serverTime: now);

  @override
  bool get available => true;

  @override
  String get unavailableReason => '';

  @override
  Future<void> init(void Function(StoreSnapshot snapshot) onUpdate) async {
    listener = onUpdate;
    if (!silentInit) onUpdate(snapshot);
  }

  @override
  Future<Map<String, String>> prices(List<String> productIds) async => {for (final id in productIds) id: '25.000 ₫'};

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final p = productById(productId)!;
    now = now.add(const Duration(minutes: 1));
    history.add(StoreTx('rc_${++_n}', productId, now));
    if (p.entitlement != null) entitlements.add(p.entitlement!);
    return PurchaseDone(snapshot, purchaseTime: now);
  }

  @override
  Future<StoreSnapshot?> restore() async => snapshot;
}

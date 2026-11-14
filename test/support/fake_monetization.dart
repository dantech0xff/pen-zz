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

  @override
  bool get privacyOptionsRequired => false;

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

/// A store that remembers purchases like RevenueCat does: entitlements plus a history.
class FakeStore implements StoreService {
  Set<String> entitlements = {};
  final List<StoreTx> history = [];
  void Function(StoreSnapshot snapshot)? listener;
  DateTime now = DateTime(2026, 11, 14, 10);
  int _n = 0;

  StoreSnapshot get snapshot => StoreSnapshot(Set.of(entitlements), List.of(history));

  @override
  bool get available => true;

  @override
  String get unavailableReason => '';

  @override
  Future<void> init(void Function(StoreSnapshot snapshot) onUpdate) async {
    listener = onUpdate;
    onUpdate(snapshot);
  }

  @override
  Future<Map<String, String>> prices(List<String> productIds) async => {for (final id in productIds) id: '25.000 ₫'};

  @override
  Future<PurchaseOutcome> buy(String productId) async {
    final p = productById(productId)!;
    final tx = StoreTx('tx-${++_n}', productId, now);
    history.add(tx);
    if (p.entitlement != null) entitlements.add(p.entitlement!);
    return PurchaseDone(tx.id, snapshot);
  }

  @override
  Future<StoreSnapshot?> restore() async => snapshot;
}

import 'package:flutter/widgets.dart';
import 'package:pen_zz/core/store_catalog.dart';
import 'package:pen_zz/monetize/ads_service.dart';
import 'package:pen_zz/monetize/cloud_service.dart';
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

  /// Account ids the game signed the store in with, in order.
  final List<String> identities = [];

  @override
  Future<StoreSnapshot?> identify(String appUserId) async {
    identities.add(appUserId);
    return snapshot;
  }
}

/// A cloud with accounts and one saved document per account, like Firestore.
class FakeCloud extends CloudService {
  FakeCloud({this.online = true, this.idPrefix = 'anon'});

  /// The server is reachable.
  bool online;

  /// Start of the anonymous ids this install gets, so two installs never share one.
  final String idPrefix;

  /// Saved documents by player id.
  final Map<String, String> docs = {};

  /// Player id that owns a Google account, by account name.
  final Map<String, String> googleOwners = {};

  /// Google account the player picks in the next [linkGoogle].
  String googleAccount = 'ban@example.com';

  String? _uid;
  String? _google;
  int _next = 0;
  int uploads = 0;

  @override
  bool get available => true;

  @override
  String? get uid => _uid;

  @override
  bool get linked => _google != null;

  @override
  String? get accountName => _google;

  void _needOnline() {
    if (!online) throw StateError('offline');
  }

  @override
  Future<void> init() async {
    if (_uid != null) return;
    _needOnline();
    _uid = '$idPrefix-${++_next}';
    notifyListeners();
  }

  @override
  Future<String?> download() async {
    _needOnline();
    return docs[_uid];
  }

  @override
  Future<void> upload(String json) async {
    _needOnline();
    docs[_uid!] = json;
    uploads++;
  }

  @override
  Future<LinkOutcome> linkGoogle() async {
    if (!online || _uid == null) return const LinkFailed('offline');
    final owner = googleOwners[googleAccount];
    _google = googleAccount;
    if (owner != null && owner != _uid) {
      _uid = owner;
      notifyListeners();
      return const LinkedSwitched();
    }
    googleOwners[googleAccount] = _uid!;
    notifyListeners();
    return const LinkedSame();
  }

  @override
  Future<bool> deleteAccount() async {
    if (!online || _uid == null) return false;
    docs.remove(_uid);
    googleOwners.removeWhere((_, owner) => owner == _uid);
    _google = null;
    _uid = '$idPrefix-${++_next}';
    notifyListeners();
    return true;
  }
}

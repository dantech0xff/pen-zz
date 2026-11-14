import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:pen_zz/core/save_data.dart';
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
  /// Entitlements per store account (App User ID); '' is the anonymous account. Like
  /// RevenueCat, purchases stay with the account they were made on.
  final Map<String, Set<String>> accounts = {'': {}};

  /// The store account the game is signed in with.
  String account = '';

  Set<String> get entitlements => accounts.putIfAbsent(account, () => {});
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
    account = appUserId;
    return snapshot;
  }
}

/// A cloud with accounts and one document per account, like Firestore with its offline copy
/// switched off: reads come from the server, writes are transactions on a revision, and
/// nothing works offline.
class FakeCloud extends CloudService {
  FakeCloud({this.online = true, this.idPrefix = 'anon', Map<String, CloudDoc>? docs}) : docs = docs ?? {};

  /// The server is reachable.
  bool online;

  /// Start of the anonymous ids this install gets, so two installs never share one.
  final String idPrefix;

  /// Documents by player id (shared between "phones" when the same map is passed in).
  final Map<String, CloudDoc> docs;

  /// Player id that owns a Google account, by account name.
  final Map<String, String> googleOwners = {};

  /// Google account the player picks in the next [linkGoogle].
  String googleAccount = 'ban@example.com';

  /// When set, [download] waits for it (a slow network).
  Completer<void>? downloadGate;

  String? _uid;
  String? _google;
  int _next = 0;
  int uploads = 0, conflicts = 0;

  @override
  bool get available => true;

  @override
  bool get canLink => true;

  @override
  String? get uid => _uid;

  @override
  bool get linked => _google != null;

  @override
  String? get accountName => _google;

  void _needOnline() {
    if (!online) throw StateError('offline');
  }

  /// Another phone of the same player saves [save] to the cloud.
  void otherPhoneWrites(String uid, SaveData save) {
    final now = docs[uid];
    docs[uid] = CloudDoc(jsonEncode(save.toJson()), (now?.rev ?? 0) + 1);
  }

  @override
  Future<void> init() async {
    if (_uid != null) return;
    _needOnline();
    _uid = '$idPrefix-${++_next}';
    notifyListeners();
  }

  @override
  Future<CloudDoc?> download() async {
    final gate = downloadGate;
    if (gate != null) await gate.future;
    _needOnline();
    return docs[_uid];
  }

  @override
  Future<int> upload(String json, int rev) async {
    _needOnline();
    final now = docs[_uid];
    if ((now?.rev ?? 0) != rev) {
      conflicts++;
      throw CloudConflict(now ?? const CloudDoc(null, 0));
    }
    docs[_uid!] = CloudDoc(json, rev + 1);
    uploads++;
    return rev + 1;
  }

  @override
  Future<LinkOutcome> linkGoogle() async {
    if (!online || _uid == null) return const LinkFailed('offline');
    final owner = googleOwners[googleAccount];
    _google = googleAccount;
    if (owner != null && owner != _uid) {
      docs.remove(_uid); // the abandoned anonymous account's copy
      _uid = owner;
      notifyListeners();
      return const LinkedSwitched();
    }
    googleOwners[googleAccount] = _uid!;
    notifyListeners();
    return const LinkedSame();
  }

  @override
  Future<DeleteResult> deleteAccount() async {
    if (!online || _uid == null) return DeleteResult.failed;
    docs.remove(_uid);
    googleOwners.removeWhere((_, owner) => owner == _uid);
    _google = null;
    _uid = '$idPrefix-${++_next}';
    notifyListeners();
    return DeleteResult.deleted;
  }
}

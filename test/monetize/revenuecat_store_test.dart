// Drives the real RevenueCatStore through a mocked `purchases_flutter` method channel whose
// payloads follow what purchases-hybrid-common 20.9.0 sends:
//  - CustomerInfo.nonSubscriptionTransactions[].transactionIdentifier is RevenueCat's own id;
//  - the purchase result's transaction.transactionIdentifier is the store's order id (GPA.…),
//    which never appears in the history.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/store_catalog.dart';
import 'package:pen_zz/monetize/ads_service.dart';
import 'package:pen_zz/monetize/revenuecat_store.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:pen_zz/state/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

const channel = MethodChannel('purchases_flutter');

Map<String, Object?> customerInfo(List<Map<String, Object?>> nonSubs, String requestDate) => {
  'entitlements': {'all': <String, Object?>{}, 'active': <String, Object?>{}, 'verification': 'NOT_REQUESTED'},
  'allPurchaseDates': <String, Object?>{},
  'activeSubscriptions': <Object?>[],
  'allPurchasedProductIdentifiers': <Object?>[],
  'nonSubscriptionTransactions': nonSubs,
  'firstSeen': '2026-11-14T09:00:00.000Z',
  'originalAppUserId': r'$RCAnonymousID:test',
  'allExpirationDates': <String, Object?>{},
  'requestDate': requestDate,
};

Map<String, Object?> rcTx(String id, String product, String date) => {
  'transactionIdentifier': id,
  'revenueCatId': id,
  'productIdentifier': product,
  'productId': product,
  'purchaseDate': date,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// A RevenueCat backend whose history starts with [old] purchases from another install.
  /// Calls the game made to the SDK, in order (method name and arguments).
  final calls = <MethodCall>[];

  Future<(GameController, Monetization, List<Map<String, Object?>>)> start({
    List<Map<String, Object?>> old = const [],
    String? accountBeforeStart,
  }) async {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    final g = GameController();
    await g.load();
    final history = [...old];
    var clock = DateTime.utc(2026, 11, 14, 10);
    String now() => clock.toIso8601String();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'logIn':
          return {'customerInfo': customerInfo(history, now()), 'created': false};
        case 'syncPurchasesForResult':
          return customerInfo(history, now());
        case 'getCustomerInfo':
        case 'restorePurchases':
          return customerInfo(history, now());
        case 'getProductInfo':
          return [
            for (final id in (call.arguments as Map)['productIdentifiers'] as List)
              {
                'identifier': id,
                'description': '',
                'title': id,
                'price': 25000,
                'priceString': '25.000 ₫',
                'currencyCode': 'VND',
                'productCategory': 'NON_SUBSCRIPTION',
              },
          ];
        case 'purchaseProduct':
          clock = clock.add(const Duration(minutes: 1));
          final pid = (call.arguments as Map)['productIdentifier'] as String;
          history.add(rcTx('rc_${history.length + 1}', pid, now()));
          return {
            'customerInfo': customerInfo(history, now()),
            'transaction': {
              'transactionIdentifier': 'GPA.3345-0000-0000-${history.length}',
              'productIdentifier': pid,
              'purchaseDate': now(),
              'purchaseDateMillis': clock.millisecondsSinceEpoch,
            },
          };
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final m = Monetization(game: g, ads: NoAds(), store: RevenueCatStore('goog_test'));
    if (accountBeforeStart != null) await m.identify(accountBeforeStart);
    await m.init();
    return (g, m, history);
  }

  Future<void> pushCustomerInfo(List<Map<String, Object?>> history) async {
    const codec = StandardMethodCodec();
    await messenger.handlePlatformMessage(
      channel.name,
      codec.encodeMethodCall(
        MethodCall('Purchases-CustomerInfoUpdated', customerInfo(history, '2026-11-14T11:00:00Z')),
      ),
      (_) {},
    );
  }

  test('a coin pack is paid once although the result and the history use different ids', () async {
    final (g, m, history) = await start();
    expect(m.storeReady, isTrue);
    expect(m.priceOf(productById('pz_coins_1000')!), '25.000 ₫');
    expect(await m.buy(productById('pz_coins_1000')!), 'Đã nhận 1.000 xu. Cảm ơn bạn!');
    expect(g.save.coins, 1000);
    await pushCustomerInfo(history);
    await m.restore();
    expect(g.save.coins, 1000);
    expect(g.save.creditedTx, {'rc_1': 1000});
  });

  test('coin packs from before the first contact with the store are not paid', () async {
    final (g, _, _) = await start(old: [rcTx('rc_old', 'pz_coins_9000', '2026-01-02T08:00:00.000Z')]);
    expect(g.save.coins, 0);
    expect(g.save.storeSince, greaterThan(0));
  });

  test('the store signs in with the player id, before or after it starts', () async {
    final (_, m, _) = await start(accountBeforeStart: 'uid-early');
    final setup = calls.firstWhere((c) => c.method == 'setupPurchases');
    expect((setup.arguments as Map)['appUserId'], 'uid-early');

    await m.identify('uid-later');
    final login = calls.lastWhere((c) => c.method == 'logIn');
    expect((login.arguments as Map)['appUserID'], 'uid-later');
    expect(
      calls.map((c) => c.method),
      contains('syncPurchasesForResult'),
      reason: 'switching between two signed-in players brings this phone\'s purchases along',
    );
  });

  test('signing in once from the anonymous store account needs no sync', () async {
    final (_, m, _) = await start();
    await m.identify('uid-1');
    expect(calls.map((c) => c.method), contains('logIn'));
    expect(calls.map((c) => c.method), isNot(contains('syncPurchasesForResult')));
  });
}

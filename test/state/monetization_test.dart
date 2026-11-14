import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/battle/battle.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/levels.dart';
import 'package:pen_zz/core/save_data.dart';
import 'package:pen_zz/core/store_catalog.dart';
import 'package:pen_zz/monetize/store_service.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:pen_zz/state/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_monetization.dart';

Future<GameController> freshGame() async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController();
  await g.load();
  return g;
}

MatchStats twoNil() => MatchStats()..roundsWon = 2;

StoreProductDef product(String id) => productById(id)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rewarded ads', () {
    test('a watched ad doubles a match reward once', () async {
      final g = await freshGame();
      final m = Monetization(game: g, ads: FakeAds(), store: const NoStore());
      final r = g.finishMatch(stageOpponent(1), true, twoNil());
      final coins = g.save.coins;
      expect(m.canDouble(r), isTrue);
      expect(await m.doubleReward(r), isTrue);
      expect(g.save.coins, coins + r.coins);
      expect(m.canDouble(r), isFalse);
      expect(await m.doubleReward(r), isFalse);
      expect(g.save.coins, coins + r.coins);
    });

    test('closing the ad early gives nothing and keeps the offer', () async {
      final g = await freshGame();
      final ads = FakeAds()..watch = false;
      final m = Monetization(game: g, ads: ads, store: const NoStore());
      final r = g.finishMatch(stageOpponent(1), true, twoNil());
      final coins = g.save.coins;
      expect(await m.doubleReward(r), isFalse);
      expect(g.save.coins, coins);
      expect(m.canDouble(r), isTrue);
    });

    test('free coins: three views a day, again the next day', () async {
      final g = await freshGame();
      var now = DateTime(2026, 11, 14, 9);
      final m = Monetization(game: g, ads: FakeAds(), store: const NoStore(), clock: () => now);
      for (var i = 0; i < AdRules.freeCoinsPerDay; i++) {
        expect(await m.claimFreeCoins(), AdRules.freeCoins(0));
      }
      expect(m.freeCoinsLeft, 0);
      expect(await m.claimFreeCoins(), 0);
      expect(g.save.coins, AdRules.freeCoinsPerDay * AdRules.freeCoins(0));
      now = DateTime(2026, 11, 15, 8);
      expect(m.freeCoinsLeft, AdRules.freeCoinsPerDay);
      expect(await m.claimFreeCoins(), greaterThan(0));
    });
  });

  group('interstitials', () {
    test('wait for stage 3, then every 3 matches and at least 150 s apart', () async {
      final g = await freshGame();
      final ads = FakeAds();
      var now = DateTime(2026, 11, 14, 9);
      final m = Monetization(game: g, ads: ads, store: const NoStore(), clock: () => now);
      for (var i = 0; i < 3; i++) {
        g.finishMatch(practiceOpponent(1), false, MatchStats());
      }
      expect(m.interstitialDue, isFalse, reason: 'not before stage 3 is cleared');

      g.save.stage = 3;
      expect(m.interstitialDue, isFalse, reason: 'a session starts as if an ad had just closed');
      now = now.add(const Duration(seconds: 151));
      expect(m.interstitialDue, isTrue);
      await m.afterMatch();
      expect(ads.interstitials, 1);
      expect(m.interstitialDue, isFalse);

      for (var i = 0; i < 3; i++) {
        g.finishMatch(practiceOpponent(1), false, MatchStats());
      }
      now = now.add(const Duration(seconds: 60));
      expect(m.interstitialDue, isFalse, reason: 'too soon after the last one');
      now = now.add(const Duration(seconds: 91));
      expect(m.interstitialDue, isTrue);
    });

    test('a rewarded ad pushes the next interstitial back', () async {
      final g = await freshGame();
      var now = DateTime(2026, 11, 14, 9);
      final m = Monetization(game: g, ads: FakeAds(), store: const NoStore(), clock: () => now);
      g.save.stage = 10;
      g.save.matchesSinceAd = 10;
      now = now.add(const Duration(seconds: 151));
      expect(m.interstitialDue, isTrue);
      await m.claimFreeCoins();
      expect(m.interstitialDue, isFalse);
      now = now.add(const Duration(seconds: 151));
      expect(m.interstitialDue, isTrue);
    });

    test('remove ads turns off the banner and interstitials but keeps rewarded ads', () async {
      final g = await freshGame();
      var now = DateTime(2026, 11, 14, 9);
      final m = Monetization(game: g, ads: FakeAds(), store: FakeStore(), clock: () => now);
      await m.init();
      g.save.stage = 10;
      g.save.matchesSinceAd = 10;
      now = now.add(const Duration(seconds: 151));
      expect(m.showBanner, isTrue);
      expect(m.interstitialDue, isTrue);

      expect(await m.buy(product('pz_remove_ads')), isNotNull);
      expect(g.save.noAds, isTrue);
      expect(m.owned(product('pz_remove_ads')), isTrue);
      expect(m.showBanner, isFalse);
      expect(m.interstitialDue, isFalse);
      final r = g.finishMatch(stageOpponent(1), true, twoNil());
      expect(m.canDouble(r), isTrue);
    });
  });

  group('store', () {
    test('a coin pack is credited once per transaction', () async {
      final g = await freshGame();
      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      await m.buy(product('pz_coins_1000'));
      expect(g.save.coins, 1000);
      store.listener!(store.snapshot);
      await m.restore();
      expect(g.save.coins, 1000, reason: 'the same transaction is never paid twice');
      await m.buy(product('pz_coins_1000'));
      expect(g.save.coins, 2000);
    });

    test('coin packs bought on an older install are not credited again', () async {
      final g = await freshGame();
      final store = FakeStore()..history.add(StoreTx('old', 'pz_coins_9000', DateTime(2025, 1, 2)));
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      expect(g.save.coins, 0);
    });

    test('more than a hundred coin packs are still never paid twice', () async {
      final g = await freshGame();
      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      for (var i = 0; i < 120; i++) {
        await m.buy(product('pz_coins_1000'));
      }
      store.listener!(store.snapshot);
      await m.restore();
      expect(g.save.coins, 120 * 1000);
    });

    test('a wrong device clock does not decide which coin packs count', () async {
      final g = await freshGame();
      final store = FakeStore();
      // The phone runs an hour fast; the cut-off comes from the store's clock instead.
      final m = Monetization(
        game: g,
        ads: FakeAds(),
        store: store,
        clock: () => store.now.add(const Duration(hours: 1)),
      );
      await m.init();
      store.history.add(StoreTx('cleared', 'pz_coins_3500', store.now.add(const Duration(minutes: 20))));
      store.listener!(store.snapshot);
      expect(g.save.coins, 3500);
    });

    test('a purchase made before the store ever answered still counts', () async {
      final g = await freshGame();
      final store = FakeStore()..silentInit = true;
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      expect(g.save.storeSince, 0);
      expect(await m.buy(product('pz_coins_1000')), 'Đã nhận 1.000 xu. Cảm ơn bạn!');
      expect(g.save.coins, 1000);
    });

    test('a pending payment that clears later is credited', () async {
      final g = await freshGame();
      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      store.history.add(StoreTx('later', 'pz_coins_3500', store.now.add(const Duration(minutes: 5))));
      store.listener!(store.snapshot);
      expect(g.save.coins, 3500);
    });

    test('the starter pack pays its coins once and survives a progress reset', () async {
      final g = await freshGame();
      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      await m.buy(product('pz_starter_pack'));
      expect(g.save.coins, 2000);
      expect(g.owns('nhu-ngoc'), isTrue);
      expect(m.owned(product('pz_starter_pack')), isTrue);
      store.listener!(store.snapshot);
      expect(g.save.coins, 2000);

      await g.resetProgress();
      expect(g.save.coins, 0);
      expect(g.owns('nhu-ngoc'), isTrue, reason: 'bought items stay after a reset');
      store.listener!(store.snapshot);
      expect(g.save.coins, 0, reason: 'the starter coins are not paid again');
    });

    test('exclusive items are not sold for coins', () async {
      final g = await freshGame();
      g.save.coins = 1000000;
      expect(g.buyOrEquip(Slot.hat, 'vuong-mien-ngoc'), isFalse);
      expect(g.save.coins, 1000000);

      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      await m.buy(product('pz_set_royal'));
      expect(m.owned(product('pz_set_royal')), isTrue);
      expect(g.buyOrEquip(Slot.hat, 'vuong-mien-ngoc'), isTrue);
      expect(g.save.eq[Slot.hat], 'vuong-mien-ngoc');
    });

    test('purchases survive a save round trip', () async {
      final g = await freshGame();
      final store = FakeStore();
      final m = Monetization(game: g, ads: FakeAds(), store: store, clock: () => store.now);
      await m.init();
      await m.buy(product('pz_remove_ads'));
      await m.buy(product('pz_coins_1000'));
      final back = SaveData.fromJson(jsonDecode(jsonEncode(g.save.toJson())));
      expect(back.noAds, isTrue);
      expect(back.creditedTx, containsPair('rc_2', 1000));
      expect(back.storeSince, g.save.storeSince);
    });
  });

  test('every exclusive item belongs to a product, and bots never wear one', () {
    final exclusive = [
      for (final it in itemIndex.values)
        if (it.exclusive) it.id,
    ];
    expect(exclusive, hasLength(7));
    for (final id in exclusive) {
      expect(productForItem(id), isNotNull, reason: id);
    }
    for (var stage = 1; stage <= levelCount; stage++) {
      for (final id in stageOpponent(stage).eq.values) {
        expect(itemIndex[id]?.exclusive ?? false, isFalse, reason: 'stage $stage wears $id');
      }
    }
  });
}

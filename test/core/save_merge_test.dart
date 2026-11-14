import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/save_data.dart';
import 'package:pen_zz/core/save_merge.dart';

const uid = 'player-1';

SaveData save({int stage = 0, int lvl = 1, int xp = 0, int coins = 0, int epoch = 0, String account = uid}) =>
    SaveData(stage: stage, lvl: lvl, xp: xp, coins: coins, epoch: epoch, account: account);

SaveData merge(SaveData local, SaveData cloud) => mergeSaves(local, cloud, uid: uid);

void main() {
  test('the save that cleared more stages wins, then the higher level', () {
    final phone = save(stage: 12, lvl: 7, coins: 300), cloud = save(stage: 30, lvl: 15, coins: 50);
    expect(merge(phone, cloud).stage, 30);
    expect(merge(phone, cloud).coins, 50, reason: 'coins earned in play follow the chosen save');
    expect(merge(cloud, phone).stage, 30);
    expect(merge(save(stage: 5, lvl: 3), save(stage: 5, lvl: 6)).lvl, 6);
  });

  test('a fresh install takes the cloud save and joins the account', () {
    final merged = merge(SaveData(), save(stage: 44, lvl: 21, coins: 900));
    expect(merged.stage, 44);
    expect(merged.coins, 900);
    expect(merged.account, uid);
  });

  test('within one account a newer reset wins even with less progress', () {
    final oldPhone = save(stage: 60, lvl: 30), resetCloud = save(stage: 2, lvl: 2, epoch: 1);
    expect(merge(oldPhone, resetCloud).stage, 2);
    expect(merge(oldPhone, resetCloud).epoch, 1);
    final resetPhone = save(stage: 2, lvl: 2, epoch: 1), oldCloud = save(stage: 60, lvl: 30);
    expect(merge(resetPhone, oldCloud).stage, 2);
  });

  test('a reset never decides between saves of different accounts', () {
    // The account was reset long ago and is at stage 5; a new phone got to stage 30 before
    // it was linked. The further save wins and keeps the account's own epoch.
    final newPhone = save(stage: 30, lvl: 12, account: 'anon-new');
    final account = save(stage: 5, lvl: 3, epoch: 1);
    final m1 = merge(newPhone, account);
    expect(m1.stage, 30);
    expect(m1.epoch, 1);
    expect(m1.account, uid);

    // A reset on an unlinked phone cannot wipe the account's progress when it links.
    final resetNewPhone = save(epoch: 1, account: 'anon-new');
    final m2 = merge(resetNewPhone, save(stage: 80, lvl: 35));
    expect(m2.stage, 80);
    expect(m2.epoch, 0, reason: 'the account keeps its epoch, so its other phones are not reset');
  });

  test('coin packs bought on either save are kept, and none is paid twice', () {
    final phone = save(stage: 3, coins: 1000)..creditedTx.addAll({'rc_1': 1000});
    final cloud = save(stage: 9, coins: 4500)..creditedTx.addAll({'rc_1': 1000, 'rc_2': 3500});
    expect(merge(phone, cloud).coins, 4500, reason: 'both purchases are already in the cloud save');

    final offlineBuy = save(stage: 3, coins: 9000)..creditedTx.addAll({'rc_9': 9000});
    final m2 = merge(offlineBuy, cloud);
    expect(m2.stage, 9);
    expect(m2.coins, 4500 + 9000, reason: 'the purchase only the phone knew about is added once');
    expect(m2.creditedTx.keys, containsAll(['rc_1', 'rc_2', 'rc_9']));
    expect(merge(m2, cloud).coins, m2.coins, reason: 'merging again changes nothing');
  });

  test('the starter pack pays its coins once across both saves', () {
    final phone = save(stage: 1, coins: 2000)..creditedPacks.add('pz_starter_pack');
    final cloud = save(stage: 8, coins: 100);
    expect(merge(phone, cloud).coins, 2100);
    final both = save(stage: 8, coins: 2100)..creditedPacks.add('pz_starter_pack');
    expect(merge(phone, both).coins, 2100);
  });

  test('exclusive items and remove ads carry over; coin-bought items follow the chosen save', () {
    final phone = save(stage: 1)
      ..noAds = true
      ..owned.addAll(['vuong-mien-ngoc', 'non-la']);
    final merged = merge(phone, save(stage: 20));
    expect(merged.noAds, isTrue);
    expect(merged.owned, contains('vuong-mien-ngoc'));
    expect(merged.owned, isNot(contains('non-la')));
    expect(itemIndex['vuong-mien-ngoc']!.exclusive, isTrue);
  });

  test('merging never gives extra free-coin views, and keeps this phone\'s settings', () {
    final phone = save(stage: 1)
      ..adDay = 20261114
      ..adCoinsUsed = 3
      ..sound = false;
    final cloud = save(stage: 9)
      ..adDay = 20261114
      ..adCoinsUsed = 1
      ..sound = true;
    final merged = merge(phone, cloud);
    expect(merged.adCoinsUsed, 3);
    expect(merged.sound, isFalse);
  });

  test('the first contact with the store is the earlier of the two', () {
    final phone = save()..storeSince = 2000, cloud = save(stage: 4)..storeSince = 1000;
    expect(merge(phone, cloud).storeSince, 1000);
    expect(merge(SaveData(), cloud).storeSince, 1000);
  });

  test('a ledger saved as a plain list still stops a second payment', () {
    final s = SaveData.fromJson({
      'coins': 1000,
      'creditedTx': ['rc_1'],
    });
    expect(s.creditedTx, {'rc_1': 0});
    final merged = merge(save(stage: 9, coins: 50), s..account = uid);
    expect(merged.coins, 50, reason: 'a ledger entry without an amount adds no coins');
  });
}

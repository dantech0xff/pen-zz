import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/save_data.dart';
import 'package:pen_zz/core/save_merge.dart';

SaveData save({int stage = 0, int lvl = 1, int xp = 0, int coins = 0, int epoch = 0}) =>
    SaveData(stage: stage, lvl: lvl, xp: xp, coins: coins, epoch: epoch);

void main() {
  test('the save that cleared more stages wins, then the higher level', () {
    final phone = save(stage: 12, lvl: 7, coins: 300), cloud = save(stage: 30, lvl: 15, coins: 50);
    expect(mergeSaves(phone, cloud).stage, 30);
    expect(mergeSaves(phone, cloud).coins, 50, reason: 'coins earned in play follow the chosen save');
    expect(mergeSaves(cloud, phone).stage, 30);
    expect(mergeSaves(save(stage: 5, lvl: 3), save(stage: 5, lvl: 6)).lvl, 6);
  });

  test('a fresh install takes the cloud save', () {
    final merged = mergeSaves(SaveData(), save(stage: 44, lvl: 21, coins: 900));
    expect(merged.stage, 44);
    expect(merged.coins, 900);
  });

  test('a newer reset wins even with less progress', () {
    final oldPhone = save(stage: 60, lvl: 30), resetCloud = save(stage: 2, lvl: 2, epoch: 1);
    expect(mergeSaves(oldPhone, resetCloud).stage, 2);
    expect(mergeSaves(resetCloud, oldPhone).stage, 2);
  });

  test('coin packs bought on either save are kept, and none is paid twice', () {
    final phone = save(stage: 3, coins: 1000)..creditedTx.addAll({'rc_1': 1000});
    final cloud = save(stage: 9, coins: 4500)..creditedTx.addAll({'rc_1': 1000, 'rc_2': 3500});
    final merged = mergeSaves(phone, cloud);
    expect(merged.coins, 4500, reason: 'both purchases are already in the cloud save');

    final offlineBuy = save(stage: 3, coins: 9000)..creditedTx.addAll({'rc_9': 9000});
    final m2 = mergeSaves(offlineBuy, cloud);
    expect(m2.stage, 9);
    expect(m2.coins, 4500 + 9000, reason: 'the purchase only the phone knew about is added once');
    expect(m2.creditedTx.keys, containsAll(['rc_1', 'rc_2', 'rc_9']));
    expect(mergeSaves(m2, cloud).coins, m2.coins, reason: 'merging again changes nothing');
  });

  test('the starter pack pays its coins once across both saves', () {
    final phone = save(stage: 1, coins: 2000)..creditedPacks.add('pz_starter_pack');
    final cloud = save(stage: 8, coins: 100);
    expect(mergeSaves(phone, cloud).coins, 2100);
    final both = save(stage: 8, coins: 2100)..creditedPacks.add('pz_starter_pack');
    expect(mergeSaves(phone, both).coins, 2100);
  });

  test('exclusive items and remove ads carry over; coin-bought items follow the chosen save', () {
    final phone = save(stage: 1)
      ..noAds = true
      ..owned.addAll(['vuong-mien-ngoc', 'non-la']);
    final merged = mergeSaves(phone, save(stage: 20));
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
    final merged = mergeSaves(phone, cloud);
    expect(merged.adCoinsUsed, 3);
    expect(merged.sound, isFalse);
  });

  test('the first contact with the store is the earlier of the two', () {
    final phone = save()..storeSince = 2000, cloud = save(stage: 4)..storeSince = 1000;
    expect(mergeSaves(phone, cloud).storeSince, 1000);
    expect(mergeSaves(SaveData(), cloud).storeSince, 1000);
  });
}

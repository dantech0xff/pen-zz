import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/save_data.dart';
import 'package:pen_zz/state/cloud_sync.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_monetization.dart';

Future<GameController> phone({int stage = 0, int lvl = 1, int coins = 0}) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController();
  await g.load();
  g.replaceSave(SaveData(stage: stage, lvl: lvl, coins: coins));
  return g;
}

String cloudSave({int stage = 0, int lvl = 1, int coins = 0, int epoch = 0, Map<String, int> tx = const {}}) =>
    jsonEncode((SaveData(stage: stage, lvl: lvl, coins: coins, epoch: epoch)..creditedTx.addAll(tx)).toJson());

SaveData uploaded(FakeCloud cloud, String uid) => SaveData.fromJson(jsonDecode(cloud.docs[uid]!));

Future<void> settleTimers() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phone further ahead keeps its save and backs it up', () async {
    final g = await phone(stage: 20, lvl: 9, coins: 500);
    final cloud = FakeCloud();
    final ids = <String>[];
    final sync = CloudSync(game: g, cloud: cloud, onAccount: (uid) async => ids.add(uid));
    await sync.init();
    expect(sync.synced, isTrue);
    expect(ids, ['anon-1']);
    expect(uploaded(cloud, 'anon-1').stage, 20);
  });

  test('a better cloud save replaces the phone save, and the store hears after the merge', () async {
    final g = await phone(stage: 2);
    final cloud = FakeCloud();
    await cloud.init();
    cloud.docs['anon-1'] = cloudSave(stage: 40, lvl: 18, coins: 1200);
    int? stageWhenStoreHeard;
    final sync = CloudSync(game: g, cloud: cloud, onAccount: (_) async => stageWhenStoreHeard = g.save.stage);
    await sync.init();
    expect(g.save.stage, 40);
    expect(g.save.coins, 1200);
    expect(stageWhenStoreHeard, 40, reason: 'purchases are matched against the merged save');
  });

  test('an offline start uploads nothing until the cloud copy has been merged', () async {
    final g = await phone(stage: 1);
    final cloud = FakeCloud(online: false);
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 1));
    await sync.init();
    expect(sync.synced, isFalse);
    g.addBonus(coins: 10, xp: 0);
    await settleTimers();
    expect(cloud.uploads, 0);

    cloud.online = true;
    await cloud.init();
    cloud.docs['anon-1'] = cloudSave(stage: 30, lvl: 12);
    await sync.connect();
    expect(g.save.stage, 30, reason: 'the better cloud save was not overwritten');
    expect(sync.synced, isTrue);
  });

  test('changes are uploaded after a short pause, and only when something changed', () async {
    final g = await phone(stage: 3);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 1));
    await sync.init();
    final first = cloud.uploads;
    g.addBonus(coins: 50, xp: 0);
    await settleTimers();
    expect(cloud.uploads, first + 1);
    expect(uploaded(cloud, 'anon-1').coins, g.save.coins);
    await sync.push();
    expect(cloud.uploads, first + 1);
  });

  test('a progress reset reaches the cloud and wins over an older phone save', () async {
    final g = await phone(stage: 50, lvl: 20);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 1));
    await sync.init();
    await g.resetProgress();
    await settleTimers();
    expect(uploaded(cloud, 'anon-1').epoch, 1);

    final otherPhone = await phone(stage: 60, lvl: 25);
    final sync2 = CloudSync(game: otherPhone, cloud: cloud);
    await sync2.init();
    expect(otherPhone.save.stage, 0, reason: 'the reset applies to every phone of this player');
  });

  test('after a reinstall, linking the same Google account brings the progress back', () async {
    final cloud = FakeCloud();
    final first = await phone(stage: 35, lvl: 15);
    final syncA = CloudSync(game: first, cloud: cloud);
    await syncA.init();
    await syncA.linkGoogle();
    expect(cloud.linked, isTrue);
    final oldUid = cloud.uid!;

    // Reinstall: a new anonymous player with a fresh save, then the same Google account.
    final reinstalled = await phone();
    final cloud2 = FakeCloud(idPrefix: 'reinstall')
      ..docs.addAll(cloud.docs)
      ..googleOwners.addAll(cloud.googleOwners);
    final ids = <String>[];
    final syncB = CloudSync(game: reinstalled, cloud: cloud2, onAccount: (uid) async => ids.add(uid));
    await syncB.init();
    expect(reinstalled.save.stage, 0);
    await syncB.linkGoogle();
    expect(cloud2.uid, oldUid);
    expect(reinstalled.save.stage, 35);
    expect(ids.last, oldUid, reason: 'the store follows the player to the old account');
  });

  test('switching accounts keeps purchases made on this phone', () async {
    final cloud = FakeCloud()
      ..googleOwners['ban@example.com'] = 'old'
      ..docs['old'] = cloudSave(stage: 25, lvl: 10, coins: 300, tx: {'rc_1': 1000});
    final g = await phone(stage: 2, coins: 3500);
    g.save.creditedTx['rc_7'] = 3500;
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    await sync.linkGoogle();
    expect(g.save.stage, 25);
    expect(g.save.coins, 300 + 3500);
    expect(g.save.creditedTx.keys, containsAll(['rc_1', 'rc_7']));
    expect(uploaded(cloud, 'old').coins, 3800);
  });

  test('deleting the account removes the cloud save and starts a new backup', () async {
    final g = await phone(stage: 7);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    expect(cloud.docs.containsKey('anon-1'), isTrue);
    expect(await sync.deleteAccount(), isTrue);
    expect(cloud.docs.containsKey('anon-1'), isFalse);
    expect(cloud.uid, 'anon-2');
    expect(g.save.stage, 7, reason: 'progress on this phone stays');
    expect(uploaded(cloud, 'anon-2').stage, 7);
  });
}

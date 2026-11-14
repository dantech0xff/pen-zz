import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/save_data.dart';
import 'package:pen_zz/monetize/cloud_service.dart';
import 'package:pen_zz/state/cloud_sync.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_monetization.dart';

Future<GameController> phone({int stage = 0, int lvl = 1, int coins = 0, String account = ''}) async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController();
  await g.load();
  g.replaceSave(SaveData(stage: stage, lvl: lvl, coins: coins, account: account));
  return g;
}

CloudDoc doc(SaveData s, [int rev = 1]) => CloudDoc(jsonEncode(s.toJson()), rev);

SaveData stored(FakeCloud cloud, String uid) => SaveData.fromJson(jsonDecode(cloud.docs[uid]!.json!));

Future<void> settleTimers() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phone further ahead keeps its save and backs it up', () async {
    final g = await phone(stage: 20, lvl: 9, coins: 500);
    final cloud = FakeCloud();
    final ids = <String>[];
    final sync = CloudSync(game: g, cloud: cloud, onAccount: (uid) async => ids.add(uid));
    await sync.init();
    await settleTimers();
    expect(sync.synced, isTrue);
    expect(ids, ['anon-1']);
    expect(stored(cloud, 'anon-1').stage, 20);
    expect(stored(cloud, 'anon-1').account, 'anon-1');
  });

  test('a better cloud save replaces the phone save, and the store hears after the merge', () async {
    final g = await phone(stage: 2);
    final cloud = FakeCloud(docs: {'anon-1': doc(SaveData(stage: 40, lvl: 18, coins: 1200, account: 'anon-1'))});
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
    cloud.docs['anon-1'] = doc(SaveData(stage: 30, lvl: 12, account: 'anon-1'));
    await sync.connect();
    expect(g.save.stage, 30, reason: 'the better cloud save was not overwritten');
    expect(sync.synced, isTrue);
  });

  test('changes are uploaded after a short pause, and only when something changed', () async {
    final g = await phone(stage: 3);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 1));
    await sync.init();
    await settleTimers();
    final first = cloud.uploads;
    g.addBonus(coins: 50, xp: 0);
    await settleTimers();
    expect(cloud.uploads, first + 1);
    expect(stored(cloud, 'anon-1').coins, g.save.coins);
    await sync.push();
    expect(cloud.uploads, first + 1);
  });

  test('when another phone saved first, its save is merged before uploading', () async {
    final g = await phone(stage: 10, coins: 100);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 1));
    await sync.init();
    await settleTimers();
    // The player's other phone got much further and saved while this one was idle.
    cloud.otherPhoneWrites('anon-1', SaveData(stage: 40, lvl: 20, coins: 700, account: 'anon-1'));
    g.addBonus(coins: 5, xp: 0);
    await settleTimers();
    expect(cloud.conflicts, 1);
    expect(g.save.stage, 40, reason: 'the further save wins');
    expect(stored(cloud, 'anon-1').stage, 40, reason: 'stage 40 was not overwritten by stage 10');
  });

  test('a progress reset reaches the account\'s other phones', () async {
    final docs = <String, CloudDoc>{};
    final g = await phone(stage: 50, lvl: 20);
    final sync = CloudSync(
      game: g,
      cloud: FakeCloud(docs: docs),
      debounce: const Duration(milliseconds: 1),
    );
    await sync.init();
    await g.resetProgress();
    await settleTimers();
    expect(SaveData.fromJson(jsonDecode(docs['anon-1']!.json!)).epoch, 1);

    // The other phone has synced with this account before (its save names the account).
    final otherPhone = await phone(stage: 60, lvl: 25, account: 'anon-1');
    final cloud2 = FakeCloud(docs: docs);
    await cloud2.init();
    await CloudSync(game: otherPhone, cloud: cloud2).init();
    expect(otherPhone.save.stage, 0);
  });

  test('after a reinstall, linking the same Google account brings the progress back', () async {
    final docs = <String, CloudDoc>{};
    final cloud = FakeCloud(docs: docs);
    final first = await phone(stage: 35, lvl: 15);
    final syncA = CloudSync(game: first, cloud: cloud);
    await syncA.init();
    await syncA.linkGoogle();
    final oldUid = cloud.uid!;
    await settleTimers();

    final reinstalled = await phone();
    final cloud2 = FakeCloud(idPrefix: 'reinstall', docs: docs)..googleOwners.addAll(cloud.googleOwners);
    final ids = <String>[];
    final syncB = CloudSync(game: reinstalled, cloud: cloud2, onAccount: (uid) async => ids.add(uid));
    await syncB.init();
    expect(reinstalled.save.stage, 0);
    await syncB.linkGoogle();
    expect(cloud2.uid, oldUid);
    expect(reinstalled.save.stage, 35);
    expect(ids.last, oldUid, reason: 'the store follows the player to the old account');
    expect(docs.containsKey('reinstall-1'), isFalse, reason: 'the abandoned anonymous copy is gone');
  });

  test('switching accounts keeps purchases made on this phone', () async {
    final docs = {'old': doc(SaveData(stage: 25, lvl: 10, coins: 300, account: 'old')..creditedTx['rc_1'] = 1000)};
    final cloud = FakeCloud(docs: docs)..googleOwners['ban@example.com'] = 'old';
    final g = await phone(stage: 2, coins: 3500);
    g.save.creditedTx['rc_7'] = 3500;
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    await sync.linkGoogle();
    await settleTimers();
    expect(g.save.stage, 25);
    expect(g.save.coins, 300 + 3500);
    expect(g.save.creditedTx.keys, containsAll(['rc_1', 'rc_7']));
    expect(stored(cloud, 'old').coins, 3800);
  });

  test('linking while the first merge is still downloading merges the new account', () async {
    final docs = {'old': doc(SaveData(stage: 40, lvl: 18, account: 'old'))};
    final cloud = FakeCloud(docs: docs)..googleOwners['ban@example.com'] = 'old';
    await cloud.init();
    final gate = Completer<void>();
    cloud.downloadGate = gate;
    final g = await phone(stage: 3);
    final ids = <String>[];
    final sync = CloudSync(game: g, cloud: cloud, onAccount: (uid) async => ids.add(uid));
    final starting = sync.init();
    final linking = sync.linkGoogle();
    cloud.downloadGate = null;
    gate.complete();
    await starting;
    await linking;
    await settleTimers();
    expect(g.save.stage, 40);
    expect(sync.synced, isTrue);
    expect(ids.last, 'old');
  });

  test('switching to an account with no cloud copy uploads this phone\'s save', () async {
    final cloud = FakeCloud()..googleOwners['ban@example.com'] = 'empty';
    final g = await phone(stage: 6);
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    await sync.linkGoogle();
    await settleTimers();
    expect(stored(cloud, 'empty').stage, 6);
  });

  test('a cloud document that cannot be read is replaced, not left to block the backup', () async {
    final cloud = FakeCloud(docs: {'anon-1': const CloudDoc('{not json', 3)});
    final g = await phone(stage: 4);
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    await settleTimers();
    expect(sync.synced, isTrue);
    expect(stored(cloud, 'anon-1').stage, 4);
  });

  test('deleting the account removes the cloud save and starts a new backup', () async {
    final g = await phone(stage: 7);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud);
    await sync.init();
    await settleTimers();
    expect(cloud.docs.containsKey('anon-1'), isTrue);
    expect(await sync.deleteAccount(), DeleteResult.deleted);
    await settleTimers();
    expect(cloud.docs.containsKey('anon-1'), isFalse);
    expect(cloud.uid, 'anon-2');
    expect(g.save.stage, 7, reason: 'progress on this phone stays');
    expect(stored(cloud, 'anon-2').stage, 7);
  });

  test('a change just before deleting does not bring the deleted save back', () async {
    final g = await phone(stage: 7);
    final cloud = FakeCloud();
    final sync = CloudSync(game: g, cloud: cloud, debounce: const Duration(milliseconds: 5));
    await sync.init();
    await settleTimers();
    g.setSound(false); // schedules an upload a few milliseconds later
    await sync.deleteAccount();
    await settleTimers();
    expect(cloud.docs.containsKey('anon-1'), isFalse);
  });

  test('no merge swaps the save during a match; it waits until the match closes', () async {
    final g = await phone(stage: 2);
    final cloud = FakeCloud(docs: {'anon-1': doc(SaveData(stage: 40, lvl: 18, account: 'anon-1'))});
    var playing = true;
    final sync = CloudSync(game: g, cloud: cloud)..busy = () => playing;
    await sync.init();
    expect(g.save.stage, 2);
    expect(sync.synced, isFalse);
    playing = false;
    sync.idle();
    await settleTimers();
    expect(g.save.stage, 40);
  });
}

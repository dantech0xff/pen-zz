import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/arenas.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/gear.dart';
import 'package:pen_zz/core/levels.dart';
import 'package:pen_zz/core/rig.dart';
import 'package:pen_zz/core/rng.dart';
import 'package:pen_zz/core/strokes.dart';
import 'package:pen_zz/core/templates.dart';

void main() {
  test('template ink stays in a playable range', () {
    for (final t in weaponTemplates) {
      final ink = inkOf(t.strokes);
      expect(ink, inInclusiveRange(150, 370), reason: '${t.id} ink $ink');
    }
    for (final t in shieldTemplates) {
      final ink = inkOf(t.strokes);
      expect(ink, inInclusiveRange(100, 350), reason: '${t.id} ink $ink');
      final b = boundsOf(t.strokes);
      for (final v in [b[0], b[1], b[2], b[3]]) {
        expect(v.abs(), lessThan(shZone), reason: '${t.id} must fit the shield zone');
      }
    }
    expect(weaponTemplates.length, greaterThanOrEqualTo(30));
  });

  test('chapters reference existing arenas and templates', () {
    expect(chapters.length, 12);
    expect(levelCount, 120);
    final shieldIds = {for (final t in shieldTemplates) t.id};
    final weaponIds = {for (final t in weaponTemplates) t.id};
    for (final c in chapters) {
      expect(arenasById.containsKey(c.arenaId), isTrue, reason: c.arenaId);
      expect(weaponIds.contains(c.bossWeapon), isTrue, reason: c.bossWeapon);
      expect(shieldIds.contains(c.miniShield), isTrue, reason: c.miniShield);
      for (final w in c.weapons) {
        expect(weaponIds.contains(w), isTrue, reason: w);
      }
      for (final s in c.shields) {
        expect(shieldIds.contains(s), isTrue, reason: s);
      }
    }
    expect({for (final c in chapters) c.arenaId}.length, 12, reason: 'one arena per notebook');
    final unlocks = {for (var s = 1; s <= levelCount; s++) LevelDef(s).unlocks}..remove(null);
    expect(unlocks.length, 24, reason: '12 weapon and 12 shield blueprints from bosses');
  });

  test('bosses sit at levels 5 and 10 of every chapter', () {
    for (var s = 1; s <= levelCount; s++) {
      final lv = LevelDef(s);
      expect(lv.boss, s % 5 == 0);
      expect(lv.goal.text, isNotEmpty);
      expect(lv.coins, greaterThan(0));
    }
  });

  test('every level has a deterministic opponent within the ink budget', () {
    final player = weaponStats(fillTo(templateOf('kiem').strokes, 320));
    for (var s = 1; s <= levelCount; s++) {
      final a = stageOpponent(s), b = stageOpponent(s);
      expect(inkOf(a.wStrokes), closeTo(inkOf(b.wStrokes), 1e-9), reason: 'stage $s is deterministic');
      expect(inkOf(a.wStrokes), lessThanOrEqualTo(weaponInkCap * 1.25), reason: 'stage $s weapon ink');
      expect(a.name, isNotEmpty);
      botPickShield(a, player, Rng(s));
      expect(inkOf(a.wStrokes) + inkOf(a.sStrokes), lessThanOrEqualTo(inkMax), reason: 'stage $s total ink');
      expect(a.s, isNotNull);
      expect(a.aiL, inInclusiveRange(1, 9));
    }
  });

  test('wardrobe ids are unique and the catalog is big enough', () {
    final all = [...hats, ...capes, ...glasses, ...bodyInks, ...weaponInks, ...hitFxs, ...taunts];
    expect({for (final it in all) it.id}.length, all.length);
    expect(hats.length - 1, greaterThanOrEqualTo(15));
    expect(capes.length - 1, greaterThanOrEqualTo(12));
    expect(glasses.length - 1, greaterThanOrEqualTo(10));
    expect(bodyInks.length, greaterThanOrEqualTo(12));
    expect(hitFxs.length, greaterThanOrEqualTo(15));
    expect(taunts.length, greaterThanOrEqualTo(10));
    for (final id in defaultEquip.values) {
      expect(itemById(id), isNotNull, reason: id);
    }
    expect(weaponInks.where((i) => i.fx.name != 'none').length, 6);
  });

  test('blueprint stamping respects the ink left', () {
    for (final t in [...weaponTemplates, ...shieldTemplates]) {
      expect(stampBlueprint(t, 200), isNotEmpty, reason: t.id);
      for (final left in [200.0, 60.0, 10.0, 0.0]) {
        final st = stampBlueprint(t, left);
        expect(inkOf(st), lessThanOrEqualTo(left + 1e-6), reason: '${t.id} with $left ink left');
      }
      expect(stampBlueprint(t, stampMinInk(t) / 0.98 + 1), isNotEmpty, reason: '${t.id} at its smallest size');
    }
  });
}

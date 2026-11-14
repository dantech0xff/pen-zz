import 'dart:math' as math;

import 'catalog.dart';
import 'gear.dart';
import 'levels.dart';
import 'mathx.dart';
import 'rig.dart';
import 'rng.dart';
import 'strokes.dart';
import 'templates.dart';

enum OppKind { stage, practice, ghost }

/// Upgrade-point split per bot personality: power, defence, speed.
const Map<String, List<double>> archetypes = {
  'hùng hổ': [0.6, 0.2, 0.2],
  'lì lợm': [0.2, 0.6, 0.2],
  'nhanh nhẹn': [0.2, 0.2, 0.6],
  'cân bằng': [1 / 3, 1 / 3, 1 / 3],
};

Points splitPts(int total, List<double> w) {
  final pow = jsRound(total * w[0]), def = jsRound(total * w[1]);
  return Points(pow: pow, def: def, spd: math.max(0, total - pow - def));
}

/// Bots keep at least a third of the ink for their shield.
const double weaponInkCap = 560;

/// AI level ramps across the 120 levels; bosses are one level sharper.
int aiLevelFor(int stage, bool boss) => 1 + (stage - 1) * 7 ~/ 119 + (boss ? 1 : 0);

class OppSpec {
  OppSpec({
    required this.kind,
    required this.name,
    required this.lvl,
    required this.aiL,
    required this.pts,
    required this.eq,
    required this.wStrokes,
    required this.wName,
    this.stage = 0,
    this.boss = false,
    this.arch = 'cân bằng',
    this.shieldId,
    Strokes? sStrokes,
  }) : sStrokes = sStrokes ?? [] {
    compute();
  }

  final OppKind kind;
  final String name;
  final int lvl;
  final int aiL;
  final Points pts;
  final Map<Slot, String> eq;
  final Strokes wStrokes;
  final String wName;
  final int stage;
  final bool boss;
  final String arch;

  /// Signature shield of a mini-boss.
  final String? shieldId;

  /// Bots draw their shield after seeing the player's weapon, right before the fight.
  Strokes sStrokes;
  String sName = '';
  late WeaponStats w;
  ShieldStats? s;

  bool get hasShieldYet => s != null;

  void compute() {
    w = boostW(weaponStats(wStrokes), pts, inkFxOf(eq[Slot.inkW] ?? sameInk));
    s = sStrokes.isNotEmpty || kind == OppKind.ghost ? boostS(shieldStats(sStrokes), pts) : null;
  }
}

Strokes botWeapon(GearTemplate t, int aiL, Rng rng) {
  final k = 0.85 + rng.next() * 0.3 + math.min(0.15, (aiL - 1) * 0.03);
  var ws = scaleSt(t.strokes, k);
  // Higher levels pack more ink into the same shape: more attack without a longer swing.
  if (aiL >= 2) ws = fillTo(ws, math.min(weaponInkCap, inkOf(ws) * (1 + 0.15 * (aiL - 1))));
  return wobble(ws, 1.2, rng);
}

List<String> _earlierWeapons(int chapterIndex) => [
      for (var c = 0; c < chapterIndex; c++) ...[...chapters[c].weapons, chapters[c].bossWeapon],
    ];

String _some(Rng rng, List<Item> list, double p, int maxPrice) {
  final pool = [for (final it in list.skip(1)) if (it.price <= maxPrice) it.id];
  return pool.isNotEmpty && rng.next() < p ? rng.pick(pool) : list.first.id;
}

Map<Slot, String> _botLook(Rng rng, LevelDef lv) {
  final s = lv.stage;
  final effectInks = [for (final it in weaponInks) if (!it.rainbow) it.id];
  if (lv.boss) {
    final tier = lv.chapterIndex;
    return {
      Slot.hat: rng.pick(tier >= 6
          ? ['vuong-mien', 'hao-quang', 'sung-quy', 'cuop-bien']
          : ['vuong-mien', 'phu-thuy', 'bao-hiem', 'cao-boi', 'non-coi']),
      Slot.cape: rng.pick(tier >= 6
          ? ['phi-phong-vang', 'canh-doi', 'canh-thien-than', 'ao-choang-lua', 'ao-choang-bang']
          : ['phi-phong-do', 'ao-choang-den', 'ao-choang-sao', 'phi-phong-vang']),
      Slot.glass: rng.pick(['khong-kinh', 'kinh-ram', 'kinh-pixel', 'mat-na', 'kinh-3d']),
      Slot.ink: rng.pick(['muc-den', 'muc-tim', 'muc-man', 'muc-nau']),
      Slot.inkW: tier >= 1 && rng.chance(0.6) ? rng.pick(effectInks) : rng.pick([sameInk, 'nhu-vang']),
      Slot.inkS: sameInk,
      Slot.fx: rng.pick([for (final it in hitFxs) it.id]),
      Slot.taunt: rng.pick([for (final it in taunts) it.id]),
    };
  }
  final effectChance = s >= 25 ? math.min(0.45, 0.15 + 0.004 * (s - 25)) : 0.0;
  final maxPrice = 600 + s * 12;
  return {
    Slot.hat: s >= 3 ? _some(rng, hats, 0.5, maxPrice) : 'khong-mu',
    Slot.cape: s >= 6 ? _some(rng, capes, 0.3, maxPrice) : 'khong-choang',
    Slot.glass: s >= 4 ? _some(rng, glasses, 0.3, maxPrice) : 'khong-kinh',
    Slot.ink: 'muc-xanh',
    Slot.inkW: rng.chance(effectChance) ? rng.pick(effectInks) : sameInk,
    Slot.inkS: sameInk,
    Slot.fx: s >= 8 ? rng.pick([for (final it in hitFxs) if (it.price <= maxPrice) it.id]) : 'muc',
    Slot.taunt: rng.pick([for (final it in taunts) if (it.price <= maxPrice) it.id]),
  };
}

/// The fixed opponent of a level: same name, weapon and look on every attempt.
OppSpec stageOpponent(int stage) {
  final lv = LevelDef(stage.clamp(1, levelCount));
  final ch = lv.chapter;
  final rng = Rng(hashString('stage-${lv.stage}'));
  final boss = lv.boss;
  final lvl = 1 + ((lv.stage - 1) * 0.45).floor();
  final aiL = aiLevelFor(lv.stage, boss);
  final arch = rng.pick(archetypes.keys.toList());
  final String wid;
  if (lv.chapterBoss) {
    wid = ch.bossWeapon;
  } else if (lv.chapterIndex == 0 || rng.chance(0.8)) {
    wid = rng.pick(ch.weapons);
  } else {
    wid = rng.pick(_earlierWeapons(lv.chapterIndex));
  }
  final t = templateOf(wid);
  final ws = botWeapon(t, aiL, rng);
  final eq = _botLook(rng, lv);
  final name = lv.chapterBoss
      ? ch.boss
      : lv.miniBoss
          ? ch.miniBoss
          : rng.pick(ch.bots);
  return OppSpec(
    kind: OppKind.stage,
    name: name,
    lvl: lvl,
    aiL: aiL,
    pts: splitPts(jsRound((lvl - 1) * 3 * (boss ? 1.15 : 1) * ch.botPower), archetypes[arch]!),
    eq: eq,
    wStrokes: ws,
    wName: t.name.toLowerCase(),
    stage: lv.stage,
    boss: boss,
    arch: arch,
    shieldId: lv.miniBoss ? ch.miniShield : null,
  );
}

/// Practice bot near the player's progress; no level rewards.
OppSpec practiceOpponent(int stage) {
  final base = stageOpponent(stage.clamp(1, levelCount));
  return OppSpec(
    kind: OppKind.practice,
    name: 'Bot luyện tập',
    lvl: base.lvl,
    aiL: base.aiL,
    pts: base.pts,
    eq: base.eq,
    wStrokes: base.wStrokes,
    wName: base.wName,
    stage: base.stage,
    arch: base.arch,
  );
}

/// The player's own gear and points, driven by the AI.
OppSpec ghostOpponent({required Strokes w, required Strokes s, required int lvl, required Points pts, required Map<Slot, String> eq}) =>
    OppSpec(
      kind: OppKind.ghost,
      name: 'Bóng ma của bạn',
      lvl: lvl,
      aiL: (1 + lvl ~/ 3).clamp(1, 6),
      pts: pts.copy(),
      eq: Map.of(eq),
      wStrokes: cloneSt(w),
      sStrokes: cloneSt(s),
      wName: 'vũ khí tự vẽ',
    );

/// Bot draws its shield after seeing the player's weapon; higher levels aim for a defence
/// above the player's attack.
void botPickShield(OppSpec o, WeaponStats pw, Rng rng) {
  if (o.kind == OppKind.ghost) return;
  final left = inkMax - inkOf(o.wStrokes) - 8;
  final l = o.aiL;
  final want = pw.atk * (0.7 + math.min(0.4, 0.06 * (l - 1)) + rng.range(-0.1, 0.15)) / mulDef(o.pts);
  final target = want < 90 ? 90.0 : (want > left ? left : want);
  final chapterShields = o.stage > 0 ? LevelDef(o.stage).chapter.shields : chapters.first.shields;
  var pool = o.shieldId != null ? [o.shieldId!] : chapterShields;
  if (o.shieldId == null && pw.reach > 200) {
    pool = [for (final t in shieldTemplates) if (t.tall) t.id];
  }
  var id = rng.pick(pool);
  var st = templateOf(id).strokes;
  final base = inkOf(st);
  if (base > target) {
    final k = target / base;
    if (k < 0.5 && o.shieldId == null) {
      id = 'khien-nho';
      st = templateOf(id).strokes;
      final b2 = inkOf(st);
      if (b2 > target) st = scaleSt(st, math.max(0.35, target / b2));
    } else {
      st = scaleSt(st, math.max(0.35, k));
    }
  }
  st = wobble(fillTo(st, target * 0.96), 0.8, rng);
  while (st.length > 1 && inkOf(st) > left) {
    st.removeLast();
  }
  o.sName = templateOf(id).name.toLowerCase();
  o.sStrokes = st;
  o.compute();
}

/// Stamps a blueprint for the player, scaled down to fit [inkLeft] if needed.
Strokes stampBlueprint(GearTemplate t, double inkLeft, {int seed = 7}) {
  var st = t.strokes;
  final ink = inkOf(st);
  final room = inkLeft * 0.98;
  if (ink > room && room > 0) st = scaleSt(st, math.max(0.3, room / ink));
  st = wobble(st, 0.6, Rng(seed));
  while (st.length > 1 && inkOf(st) > inkLeft) {
    st.removeLast();
  }
  return roundSt(st);
}

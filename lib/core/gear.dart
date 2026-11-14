import 'dart:math' as math;
import 'dart:typed_data';

import 'ink_fx.dart';
import 'mathx.dart';
import 'rig.dart';
import 'strokes.dart';

/// Share of the attack/defence gap that pushes the weaker side back on a block.
const double kBlock = 0.45;
const double walkBase = 100;

String lenClass(double n) => n < 110
    ? 'ngắn'
    : n < 160
    ? 'vừa'
    : n < 250
    ? 'dài'
    : 'quá dài';

class Dims {
  const Dims(this.len, this.wid);
  final double len;
  final double wid;
}

/// Length along the grip-to-tip axis (including what sticks out behind the hand)
/// and width across it.
Dims dimsOf(Float32List pts) {
  if (pts.isEmpty) return const Dims(0, 0);
  var tx = 0.0, ty = -1.0, best = -1.0;
  for (var i = 0; i < pts.length; i += 2) {
    final r = pts[i] * pts[i] + pts[i + 1] * pts[i + 1];
    if (r > best) {
      best = r;
      tx = pts[i];
      ty = pts[i + 1];
    }
  }
  var n = hypot(tx, ty);
  if (n == 0) n = 1;
  final ux = tx / n, uy = ty / n;
  var a0 = 0.0, a1 = 0.0, b0 = 1e9, b1 = -1e9;
  for (var i = 0; i < pts.length; i += 2) {
    final a = pts[i] * ux + pts[i + 1] * uy, b = pts[i + 1] * ux - pts[i] * uy;
    if (a < a0) a0 = a;
    if (a > a1) a1 = a;
    if (b < b0) b0 = b;
    if (b > b1) b1 = b;
  }
  return Dims(a1 - a0, b1 - b0);
}

/// Farthest forward point the weapon reaches at body height during a swing.
double effectiveReach(Float32List pts) {
  var best = 0.0;
  for (var k = 0; k <= 32; k++) {
    final th = thWind + swingArc * k / 32;
    final h = strikeHand(th);
    final c = math.cos(th), s = math.sin(th);
    for (var i = 0; i < pts.length; i += 2) {
      final x = h.x + pts[i] * c - pts[i + 1] * s, y = h.y + pts[i] * s + pts[i + 1] * c;
      if (y > -112 && y < -2 && x > best) best = x;
    }
  }
  return best;
}

class WeaponStats {
  const WeaponStats({
    required this.ink,
    required this.atk,
    required this.len,
    required this.wid,
    required this.windup,
    required this.strike,
    required this.recover,
    required this.pts,
    required this.tip,
    required this.reach,
    this.pMul = 1,
    this.dMul = 1,
    this.fx = InkFx.none,
  });

  /// Ink used, attack (ink after upgrades), size, swing phase times in seconds.
  final double ink, atk, len, wid, windup, strike, recover;

  /// Resampled points and index of the farthest point (trail and gradient tip).
  final Float32List pts;
  final int tip;
  final double reach;

  /// Knockback and % multipliers from the weapon ink.
  final double pMul, dMul;
  final InkFx fx;

  /// Knockback distance at 0% against a defender of [tough]ness (1 = no upgrades, as in the web game).
  double knock(double tough) => (30 + 0.25 * atk / tough) * pMul;

  /// % added per hit against a defender of [tough]ness.
  double pct(double tough) => (3 + atk / tough / 40) * dMul;

  double get kP => knock(1);
  double get kD => pct(1);

  double get cast => windup + strike;
  double get cycle => windup + strike + recover;
  String get cls => lenClass(len);

  WeaponStats copyWith({
    double? atk,
    double? windup,
    double? strike,
    double? recover,
    double? pMul,
    double? dMul,
    InkFx? fx,
  }) => WeaponStats(
    ink: ink,
    atk: atk ?? this.atk,
    len: len,
    wid: wid,
    windup: windup ?? this.windup,
    strike: strike ?? this.strike,
    recover: recover ?? this.recover,
    pts: pts,
    tip: tip,
    reach: reach,
    pMul: pMul ?? this.pMul,
    dMul: dMul ?? this.dMul,
    fx: fx ?? this.fx,
  );
}

/// Attack equals ink; swing time grows with the square of the length and a little with width.
WeaponStats weaponStats(Strokes st) {
  final ink = st.isEmpty ? 0.0 : inkOf(st);
  final pts = resample(st);
  var tip = 0, best = -1.0;
  for (var i = 0; i < pts.length; i += 2) {
    final r = pts[i] * pts[i] + pts[i + 1] * pts[i + 1];
    if (r > best) {
      best = r;
      tip = i;
    }
  }
  final d = dimsOf(pts);
  final len = d.len, wid = d.wid, l2 = len * len;
  return WeaponStats(
    ink: ink,
    atk: ink,
    len: len,
    wid: wid,
    windup: 0.05 + 0.0005 * len + 0.0000095 * l2 + 0.0008 * wid,
    strike: 0.03 + 0.0005 * len + 0.0000025 * l2 + 0.0003 * wid,
    recover: 0.08 + 0.0008 * len + 0.000006 * l2 + 0.0004 * wid,
    pts: pts,
    tip: tip,
    reach: effectiveReach(pts),
  );
}

class ShieldStats {
  const ShieldStats({
    required this.ink,
    required this.def,
    required this.pts,
    required this.has,
    required this.h,
    required this.w,
    required this.cx,
    required this.cy,
    required this.coverage,
    required this.raise,
    required this.lower,
    this.parryWin = 0.2,
  });

  final double ink, def;
  final Float32List pts;
  final bool has;
  final double h, w, cx, cy, coverage, raise, lower, parryWin;

  ShieldStats copyWith({double? def, double? raise, double? lower}) => ShieldStats(
    ink: ink,
    def: def ?? this.def,
    pts: pts,
    has: has,
    h: h,
    w: w,
    cx: cx,
    cy: cy,
    coverage: coverage,
    raise: raise ?? this.raise,
    lower: lower ?? this.lower,
    parryWin: parryWin,
  );
}

/// Defence equals ink; raising time grows with the square of the height.
ShieldStats shieldStats(Strokes st) {
  final ink = st.isEmpty ? 0.0 : inkOf(st);
  final ok = ink >= 5;
  final pts = resample(st);
  final bins = Uint8List(27);
  var x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  for (var i = 0; i < pts.length; i += 2) {
    final x = pts[i], y = pts[i + 1];
    if (x < x0) x0 = x;
    if (x > x1) x1 = x;
    if (y < y0) y0 = y;
    if (y > y1) y1 = y;
    final yy0 = shRaised.y + y;
    for (var yy = yy0 - sR; yy <= yy0 + sR; yy += 2) {
      final b = ((yy + 108) / 4).floor();
      if (b >= 0 && b < 27) bins[b] = 1;
    }
  }
  var cov = 0;
  for (final b in bins) {
    cov += b;
  }
  final h = ok ? y1 - y0 : 0.0, w = ok ? x1 - x0 : 0.0;
  return ShieldStats(
    ink: ink,
    def: ink,
    pts: pts,
    has: ok,
    h: h,
    w: w,
    cx: ok ? (x0 + x1) / 2 : 0,
    cy: ok ? (y0 + y1) / 2 : 0,
    coverage: ok ? cov / 27 : 0,
    raise: 0.03 + 0.0012 * h + 0.000009 * h * h + 0.0004 * w,
    lower: 0.04 + 0.0007 * h + 0.0002 * w,
  );
}

/// Upgrade points in power, defence and speed.
class Points {
  Points({this.pow = 0, this.def = 0, this.spd = 0});

  int pow, def, spd;

  int get total => pow + def + spd;

  Points copy() => Points(pow: pow, def: def, spd: spd);

  Map<String, int> toJson() => {'pow': pow, 'def': def, 'spd': spd};
}

/// Points count fully up to 20 (the range the web game was tuned for) and with
/// diminishing returns after that, so 120 levels of growth do not turn every hit into a ring-out.
double softPts(int p) => p <= 20 ? p.toDouble() : 20 + 20 * math.log(1 + (p - 20) / 20);

double mulAtk(Points p) => 1 + 0.05 * softPts(p.pow);
double mulDef(Points p) => 1 + 0.05 * softPts(p.def);
double mulTime(Points p) => 1 / (1 + 0.04 * softPts(p.spd));
double mulWalk(Points p) => 1 + 0.02 * softPts(p.spd);

/// How hard a fighter is to knock away; grows with level (total points) so evenly matched
/// fighters need several hits at every stage, not one, while out-levelling still pays off.
double toughness(Points p) => 1 + 0.05 * softPts(p.total ~/ 3);

/// Long weapons and tall shields slow walking; short daggers and small shields speed it up.
double walkW(WeaponStats? w) => w != null && w.ink > 0 ? clampD(1 - 0.002 * (w.len - 140), 0.55, 1.15) : 1;
double walkS(ShieldStats? s) => s != null ? clampD(1 - 0.0018 * ((s.has ? s.h : 0) - 85), 0.7, 1.08) : 1;
double gearWalk(WeaponStats? w, ShieldStats? s) => walkW(w) * walkS(s);

WeaponStats boostW(WeaponStats w, Points p, [InkFx fx = InkFx.none]) {
  final spec = inkFxSpec(fx);
  final a = w.atk * mulAtk(p), t = mulTime(p);
  return w.copyWith(
    atk: a,
    pMul: spec.pMul,
    dMul: spec.dMul,
    windup: w.windup * t * spec.windMul,
    strike: w.strike * t,
    recover: w.recover * t,
    fx: fx,
  );
}

ShieldStats boostS(ShieldStats s, Points p) {
  final t = mulTime(p);
  return s.copyWith(def: s.def * mulDef(p), raise: s.raise * t, lower: s.lower * t);
}

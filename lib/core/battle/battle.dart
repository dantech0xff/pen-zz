import 'dart:math' as math;
import 'dart:typed_data';

import '../arenas.dart';
import '../gear.dart';
import '../ink_fx.dart';
import '../mathx.dart';
import '../rig.dart';
import '../rng.dart';
import '../strokes.dart';
import 'ai.dart';
import 'fighter.dart';
import 'poses.dart';

/// One side of a match. [aiLevel] null means a human player drives it.
class BattleSide {
  const BattleSide({
    required this.wStrokes,
    required this.sStrokes,
    required this.w,
    required this.s,
    required this.look,
    required this.pts,
    this.aiLevel,
    this.windMul = 1,
  });

  final Strokes wStrokes;
  final Strokes sStrokes;
  final WeaponStats w;
  final ShieldStats s;
  final Look look;
  final Points pts;
  final int? aiLevel;
  final double windMul;
}

class BattleSetup {
  const BattleSetup({
    required this.player,
    required this.opponent,
    required this.rules,
    required this.seed,
    this.roundsToWin = 2,
  });

  final BattleSide player;
  final BattleSide opponent;
  final ArenaRules rules;
  final int seed;
  final int roundsToWin;
}

enum Phase { ready, fight, over, done }

enum EvKind { round, fight, whoosh, hit, block, parry, shieldUp, fall, roundEnd, matchEnd, status, warn }

/// Something the presentation layer turns into particles, text, sound or haptics.
class BattleEvent {
  const BattleEvent(
    this.kind, {
    this.x = 0,
    this.y = 0,
    this.side = 0,
    this.dir = 0,
    this.head = false,
    this.label = '',
    this.color = 0,
    this.size = 22,
    this.shake = 0,
    this.fx = '',
    this.inkFx = InkFx.none,
  });

  final EvKind kind;
  final double x, y;

  /// 0 = player, 1 = opponent (the side the event is about).
  final int side;
  final double dir;
  final bool head;
  final String label;
  final int color;
  final double size;
  final double shake;
  final String fx;
  final InkFx inkFx;
}

/// What the player did this match; used for stars and the result screen.
class MatchStats {
  int hits = 0, headHits = 0, blocks = 0, parries = 0, roundsLost = 0, roundsWon = 0;
  bool usedShield = false;
  double fightTime = 0;
  double playerDmg = 0;
}

const int pencilColor = 0x474B55;
const double _windAccel = 320;
const double _windDrift = 24;

/// Fixed-step simulation of a best-of-three duel; same rules as the web game plus arena rules.
class Battle {
  Battle(this.setup) : rng = Rng(setup.seed), rules = setup.rules {
    _startRound();
  }

  static const double dt = 1 / 120;

  final BattleSetup setup;
  final Rng rng;
  final ArenaRules rules;
  late Fighter p;
  late Fighter b;
  late BotBrain brainB;
  BotBrain? brainP;

  int round = 1, winsP = 0, winsB = 0;
  Phase phase = Phase.ready;
  double phaseT = 0, now = 0, hitstop = 0;
  int frame = 0;

  /// Current platform half width (shrinks on crumbling arenas and in long rounds).
  double half = 330;
  double roundFightT = 0;

  /// Signed wind, -strength..+strength; positive blows to the right.
  double windNow = 0;
  double _gustUntil = 0, _gustNext = 2, _gustDir = 1;

  /// Starting wind direction, random per round (and per match for round-long wind) so the
  /// left-hand player gets no built-in advantage.
  double _windSign = 1;
  late final double _matchWindSign = rng.chance(0.5) ? 1 : -1;
  bool _shrinkWarned = false;

  final MatchStats stats = MatchStats();
  final List<BattleEvent> events = [];
  bool inFwd = false, inBack = false, inBlock = false;
  bool? playerWon;

  int get roundsToWin => setup.roundsToWin;
  bool get finished => phase == Phase.done;

  /// Shrink kicks in on crumbling arenas, and on every arena once a round drags past 75 s.
  double get shrinkStart => rules.shrinks ? rules.shrinkStart : 75;
  double get shrinkSpeed => rules.shrinks ? rules.shrinkSpeed : 6;
  double get shrinkMin => rules.shrinks ? rules.shrinkMin : 130;

  Fighter _mk(BattleSide side, bool isOpp) => Fighter(
    look: side.look,
    isBot: isOpp,
    f: isOpp ? -1 : 1,
    x: isOpp ? startX : -startX,
    w: side.w,
    s: side.s,
    wStrokes: side.wStrokes,
    sStrokes: side.sStrokes,
    walkSp: walkBase * mulWalk(side.pts) * gearWalk(side.w, side.s),
    windMul: side.windMul,
    tough: toughness(side.pts),
  );

  void _startRound() {
    p = _mk(setup.player, false);
    b = _mk(setup.opponent, true);
    brainB = BotBrain(setup.opponent.aiLevel ?? 1);
    brainP = setup.player.aiLevel == null ? null : BotBrain(setup.player.aiLevel!);
    phase = Phase.ready;
    phaseT = 0;
    half = rules.half;
    roundFightT = 0;
    windNow = 0;
    _gustUntil = 0;
    _gustNext = 2 + rng.range(0, 2);
    _windSign = rng.chance(0.5) ? 1 : -1;
    _shrinkWarned = false;
    events.add(BattleEvent(EvKind.round, label: 'Hiệp $round'));
  }

  // ---------------- input ----------------

  void pressAttack() {
    if (phase != Phase.fight) return;
    if (p.state == FState.idle) {
      startAttack(p);
    } else if (p.state == FState.recover && p.recT - p.t < 0.15) {
      p.buffer = 0.2;
    }
  }

  bool startAttack(Fighter f) {
    if (f.state != FState.idle || phase != Phase.fight) return false;
    if (f.r > 0.3) {
      // Shield is up: lower it first, then swing.
      f.pendingAtk = true;
      return true;
    }
    _beginWindup(f);
    return true;
  }

  void _beginWindup(Fighter f) {
    f.pendingAtk = false;
    f.state = FState.windup;
    f.t = 0;
    f.windT = f.w.windup * f.windMul * (f.chilled ? chillSlow : 1);
    f.recT = f.w.recover;
  }

  double raiseTime(Fighter f) => f.s.raise * (f.chilled ? chillSlow : 1);

  // ---------------- arena rules ----------------

  double frictionAt(double x) {
    var k = rules.frictionMul;
    for (final z in rules.mud) {
      if (z.contains(x)) k *= 1.35;
    }
    for (final z in rules.slick) {
      if (z.contains(x)) k *= 0.5;
    }
    return frictionBase * k;
  }

  double mudAt(double x) {
    for (final z in rules.mud) {
      if (z.contains(x)) return 0.55;
    }
    return 1;
  }

  void _updateWind(double dt) {
    if (!rules.windy || phase != Phase.fight) {
      windNow += (0 - windNow) * math.min(1, dt * 3);
      return;
    }
    final s = rules.windStrength, t = roundFightT;
    double target;
    switch (rules.wind) {
      case WindMode.roundFlip:
        target = _matchWindSign * (round.isOdd ? 1 : -1) * s;
      case WindMode.alternate:
        target = _windSign * ((t / rules.windPeriod).floor().isEven ? 1 : -1) * s;
      case WindMode.gust:
        if (t >= _gustNext) {
          _gustUntil = t + rng.range(1.4, 2.6);
          _gustDir = rng.chance(0.5) ? 1 : -1;
          _gustNext = _gustUntil + rng.range(2, 4);
        }
        target = t < _gustUntil ? _gustDir * s : 0;
      case WindMode.beat:
        final local = t % rules.windPeriod;
        final pulse = local < 0.5 ? math.sin(local / 0.5 * math.pi) : 0.0;
        target = _windSign * ((t / rules.windPeriod).floor().isEven ? 1 : -1) * s * pulse * 1.8;
      case WindMode.none:
        target = 0;
    }
    windNow += (target - windNow) * math.min(1, dt * 3);
  }

  // ---------------- collision ----------------

  _HurtBox _hurtBox(Fighter d) {
    final j = rigOf(d, now);
    double px(P q) => d.x + d.f * q.x;
    double py(P q) => d.y + d.hop + q.y;
    final segs = <_Seg>[];
    void add(P a, P c, double r) => segs.add(_Seg(px(a), py(a), px(c), py(c), r + wR));
    add(j.hip, j.neck, 8);
    add(j.hip, j.kneeF, 6);
    add(j.kneeF, j.footF, 5.5);
    add(j.hip, j.kneeB, 6);
    add(j.kneeB, j.footB, 5.5);
    final hx = px(j.head), hy = py(j.head), hr = Len.head + 2 + wR;
    var x0 = hx - hr, x1 = hx + hr, y0 = hy - hr, y1 = hy + hr;
    for (final s in segs) {
      x0 = math.min(x0, math.min(s.ax, s.bx) - s.r);
      x1 = math.max(x1, math.max(s.ax, s.bx) + s.r);
      y0 = math.min(y0, math.min(s.ay, s.by) - s.r);
      y1 = math.max(y1, math.max(s.ay, s.by) + s.r);
    }
    return _HurtBox(hx, hy, hr * hr, segs, x0, y0, x1, y1);
  }

  _ShieldWorld _shieldWorld(Fighter f) {
    final j = rigOf(f, now);
    final hx = j.handS.x, hy = j.handS.y;
    final a = -25 * deg * (1 - f.r), c = math.cos(a), s = math.sin(a);
    final src = f.s.pts, out = Float32List(src.length);
    var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    for (var i = 0; i < src.length; i += 2) {
      final wx = f.x + f.f * (hx + src[i] * c - src[i + 1] * s);
      final wy = f.y + f.hop + hy + src[i] * s + src[i + 1] * c;
      out[i] = wx;
      out[i + 1] = wy;
      if (wx < x0) x0 = wx;
      if (wx > x1) x1 = wx;
      if (wy < y0) y0 = wy;
      if (wy > y1) y1 = wy;
    }
    const m = wR + sR;
    return _ShieldWorld(out, x0 - m, y0 - m, x1 + m, y1 + m);
  }

  _Contact? _testContact(Fighter a, Fighter d, double th) {
    final pts = a.w.pts;
    if (pts.isEmpty) return null;
    final h = strikeHand(th), c = math.cos(th), s = math.sin(th);
    final sw = (d.s.has && d.r >= 1 && d.state != FState.fall) ? _shieldWorld(d) : null;
    const rr = (wR + sR) * (wR + sR);
    final hb = _hurtBox(d);
    _Contact? body;
    for (var i = 0; i < pts.length; i += 2) {
      final lx = h.x + pts[i] * c - pts[i + 1] * s, ly = h.y + pts[i] * s + pts[i + 1] * c;
      final wx = a.x + a.f * lx, wy = a.y + a.hop + ly;
      if (sw != null && wx > sw.x0 && wx < sw.x1 && wy > sw.y0 && wy < sw.y1) {
        final sp = sw.pts;
        for (var k = 0; k < sp.length; k += 2) {
          final dx = sp[k] - wx, dy = sp[k + 1] - wy;
          if (dx * dx + dy * dy < rr) return _Contact(true, false, wx, wy);
        }
      }
      if (body == null) {
        final part = hb.test(wx, wy);
        if (part != 0) body = _Contact(false, part == 2, wx, wy);
      }
    }
    return body;
  }

  void _sweep(Fighter a, Fighter d, double th0, double th1) {
    final n = math.min(14, math.max(1, ((th1 - th0).abs() / (2.5 * deg)).ceil()));
    for (var k = 1; k <= n; k++) {
      final res = _testContact(a, d, th0 + (th1 - th0) * k / n);
      if (res != null) {
        _resolveHit(a, d, res);
        return;
      }
    }
  }

  void _shove(Fighter f, double dist) => f.vx = signD(dist) * math.sqrt(2 * frictionBase * dist.abs());

  int _side(Fighter f) => identical(f, p) ? 0 : 1;

  void _resolveHit(Fighter a, Fighter d, _Contact res) {
    a.hit = true;
    final kp = a.w.knock(d.tough), kd = a.w.pct(d.tough), dir = a.f;
    if (res.shield) {
      if (now - d.raisedAt <= d.s.parryWin) {
        // Parry: shield raised just in time stuns the attacker and throws them back.
        a.state = FState.stun;
        a.t = 0;
        a.stunT = 0.8;
        a.pendingAtk = false;
        _shove(a, -dir * (30 + a.w.knock(a.tough) * 0.35));
        hitstop = 0.13;
        events.add(
          BattleEvent(
            EvKind.parry,
            x: res.x,
            y: res.y,
            side: _side(d),
            dir: -dir,
            label: 'ĐỠ CHUẨN!',
            color: d.look.body,
            size: 28,
            shake: 8,
          ),
        );
        if (!d.isBot) stats.parries++;
      } else {
        // Block: weapon attack against shield defence; the weaker side is pushed by the difference.
        final diff = a.w.atk - d.s.def, push = diff.abs() * kBlock / (diff > 0 ? d.tough : a.tough);
        a.state = FState.recover;
        a.t = 0;
        a.recFrom = a.th;
        a.recT = a.w.recover;
        String label;
        int color;
        if (diff > 4) {
          _shove(d, dir * push);
          label = 'ÉP LÙI';
          color = a.look.body;
        } else if (diff < -4) {
          _shove(a, -dir * push);
          label = 'DỘI LẠI';
          color = d.look.body;
        } else {
          label = 'CHẶN';
          color = pencilColor;
        }
        hitstop = 0.05;
        events.add(
          BattleEvent(
            EvKind.block,
            x: res.x,
            y: res.y,
            side: _side(d),
            dir: -dir,
            label: label,
            color: color,
            size: 22,
            shake: 3 + math.min(6, push / 25),
          ),
        );
        if (!d.isBot) stats.blocks++;
      }
      return;
    }
    final mult = res.head ? 1.2 : 1.0;
    final dmg = kd * mult;
    d.dmg += dmg;
    final dist = kp * mult * (1 + d.dmg / 45);
    _shove(d, dir * dist);
    d.state = FState.hitstun;
    d.t = 0;
    d.stunT = 0.2 + dist / 700;
    d.trail.clear();
    d.pendingAtk = false;
    d.hopV = -math.min(520.0, 160 + dist * 1.6);
    hitstop = 0.05 + math.min(0.09, kp / 1800);
    final shownDmg = jsRound(dmg);
    events.add(
      BattleEvent(
        EvKind.hit,
        x: res.x,
        y: res.y,
        side: _side(d),
        dir: dir,
        head: res.head,
        label: res.head ? 'Trúng đầu! +$shownDmg%' : '+$shownDmg%',
        color: a.look.body,
        size: res.head ? 22 : 26,
        shake: math.min(16, 3 + kp / 14),
        fx: a.look.fx,
        inkFx: a.w.fx,
      ),
    );
    if (d.s.has && d.r > 0.02 && d.r < 1) {
      events.add(
        BattleEvent(
          EvKind.status,
          x: d.x,
          y: d.y - 168,
          side: _side(d),
          label: d.blockHeld ? 'CHƯA KỊP ĐỠ' : 'HẠ KHIÊN SỚM',
          color: pencilColor,
          size: 18,
        ),
      );
    }
    _applyInk(a, d, dmg);
    if (!a.isBot) {
      stats.hits++;
      if (res.head) stats.headHits++;
    }
  }

  void _applyInk(Fighter a, Fighter d, double dmg) {
    String? label;
    switch (a.w.fx) {
      case InkFx.ice:
        d.chillT = chillTime;
        label = 'ĐÓNG BĂNG';
      case InkFx.fire:
        d.burnT = burnTime;
        d.burnAcc = 0;
        label = 'BỎNG';
      case InkFx.shock:
        if (rng.chance(shockChance)) {
          d.stunT += shockStun;
          d.shockT = d.stunT;
          label = 'TÊ LIỆT';
        }
      case InkFx.leech:
        final heal = dmg * leechRatio;
        a.dmg = math.max(0, a.dmg - heal);
        events.add(
          BattleEvent(
            EvKind.status,
            x: a.x,
            y: a.y - 150,
            side: _side(a),
            label: 'HỒI ${jsRound(heal)}%',
            color: 0x9B1D4F,
            size: 18,
            inkFx: InkFx.leech,
          ),
        );
      case InkFx.stone:
      case InkFx.wind:
      case InkFx.none:
        break;
    }
    if (label != null) {
      events.add(
        BattleEvent(EvKind.status, x: d.x, y: d.y - 150, side: _side(d), label: label, size: 18, inkFx: a.w.fx),
      );
    }
  }

  P tipWorld(Fighter f) {
    final pts = f.w.pts;
    final h = f.state == FState.strike || f.rig == null ? strikeHand(f.th) : f.rig!.handW;
    final c = math.cos(f.th), s = math.sin(f.th), i = f.w.tip;
    return P(f.x + f.f * (h.x + pts[i] * c - pts[i + 1] * s), f.y + f.hop + h.y + pts[i] * s + pts[i + 1] * c);
  }

  void _recordTrail(Fighter f) {
    if (f.w.pts.isEmpty) return;
    f.trail.add(tipWorld(f));
    if (f.trail.length > 20) f.trail.removeAt(0);
  }

  // ---------------- per-fighter update ----------------

  /// The shield only blocks once fully raised (r = 1); while rising or lowering, hits go through.
  void _updateShield(Fighter f, double dt) {
    final want = f.blockHeld && f.s.has && f.state == FState.idle && !f.pendingAtk;
    if (want) {
      final prev = f.r;
      f.r = math.min(1, f.r + dt / raiseTime(f));
      if (f.r >= 1 && prev < 1) {
        f.raisedAt = now;
        final j = rigOf(f, now);
        events.add(
          BattleEvent(
            EvKind.shieldUp,
            x: f.x + f.f * (j.handS.x + f.s.cx),
            y: f.y + f.hop + j.handS.y + f.s.cy,
            side: _side(f),
            color: f.look.shieldInk,
          ),
        );
      }
      if (!f.isBot && f.r > 0.3) stats.usedShield = true;
    } else {
      f.r = math.max(0, f.r - dt / f.s.lower);
    }
  }

  void _updateStatus(Fighter f, double dt) {
    if (f.chillT > 0) f.chillT = math.max(0, f.chillT - dt);
    if (f.shockT > 0) f.shockT = math.max(0, f.shockT - dt);
    if (f.burnT > 0) {
      f.burnT -= dt;
      f.burnAcc += dt;
      while (f.burnAcc >= burnTick) {
        f.burnAcc -= burnTick;
        f.dmg += burnDmg;
      }
      if (f.burnT <= 0) {
        f.burnT = 0;
        f.burnAcc = 0;
      }
    }
  }

  void _updateFighter(Fighter f, Fighter e, double dt) {
    f.t += dt;
    if (f.state == FState.fall) {
      f.vy += grav * dt;
      f.y += f.vy * dt;
      f.x += f.vx * dt + windNow * 60 * dt;
      f.vx *= math.pow(0.98, dt * 60);
      f.rot += dt * 5 * (f.x == 0 ? 1 : signD(f.x));
      f.r = math.max(0, f.r - dt * 8);
      updatePose(f, dt, now);
      return;
    }
    _updateStatus(f, dt);
    if (f.vx != 0) {
      f.x += f.vx * dt;
      if (phase == Phase.fight) f.vx += windNow * _windAccel * dt;
      final dec = frictionAt(f.x) * dt;
      if (f.vx.abs() <= dec) {
        f.vx = 0;
      } else {
        f.vx -= signD(f.vx) * dec;
      }
    }
    if (f.hop < 0 || f.hopV != 0) {
      f.hopV += grav * dt;
      f.hop += f.hopV * dt;
      if (f.hop >= 0) {
        f.hop = 0;
        f.hopV = 0;
      }
    }
    switch (f.state) {
      case FState.windup:
        f.th = thWind * easeOut(math.min(1, f.t / f.windT));
        if (f.t >= f.windT) {
          f.state = FState.strike;
          f.t = 0;
          f.hit = false;
          f.trail.clear();
          events.add(BattleEvent(EvKind.whoosh, side: _side(f)));
        }
      case FState.strike:
        final prev = f.th;
        f.th = thWind + swingArc * smooth(math.min(1, f.t / f.w.strike));
        _recordTrail(f);
        if (!f.hit && phase == Phase.fight) _sweep(f, e, prev, f.th);
        if (f.state == FState.strike && f.t >= f.w.strike) {
          f.state = FState.recover;
          f.t = 0;
          f.recFrom = f.th;
        }
      case FState.recover:
        f.th = f.recFrom * (1 - easeOut(math.min(1, f.t / f.recT)));
        if (f.t >= f.recT) {
          f.state = FState.idle;
          f.t = 0;
          f.th = 0;
        }
      case FState.hitstun:
      case FState.stun:
        f.th *= math.pow(0.02, dt);
        if (f.t >= f.stunT) {
          f.state = FState.idle;
          f.t = 0;
        }
      case FState.idle:
      case FState.fall:
        break;
    }
    if (f.buffer > 0) {
      f.buffer -= dt;
      if (f.state == FState.idle) {
        f.buffer = 0;
        startAttack(f);
      }
    }
    if (f.pendingAtk && f.state == FState.idle && f.r <= 0.3) _beginWindup(f);
    // Walking: backing off is slower than advancing; with the shield up only 35% speed.
    f.walking = false;
    final edge = half - 8;
    if (f.state == FState.idle && f.moveDir != 0 && e.state != FState.fall && phase == Phase.fight) {
      final sp =
          f.walkSp * (f.moveDir > 0 ? 1 : 0.8) * (f.r > 0.5 ? 0.35 : 1) * mudAt(f.x) * (f.chilled ? chillWalk : 1);
      var nx = f.x + f.f * f.moveDir * sp * dt;
      if (f.moveDir > 0) {
        final lim = e.x - f.f * 46;
        nx = f.f > 0 ? math.min(nx, lim) : math.max(nx, lim);
      }
      // Walking never takes you over the edge; only hits do.
      if (nx.abs() > edge && nx.abs() > f.x.abs()) nx = f.x;
      if (nx != f.x) {
        f.walk += (nx - f.x) * f.f * 0.12;
        f.walking = true;
        f.x = nx;
      }
    }
    if (phase == Phase.fight && f.vx == 0 && windNow != 0) {
      final nx = f.x + windNow * _windDrift * dt;
      if (!(nx.abs() > edge && nx.abs() > f.x.abs())) f.x = nx;
    }
    updatePose(f, dt, now);
  }

  // ---------------- match flow ----------------

  void _endRound(bool won) {
    phase = Phase.over;
    phaseT = 0;
    if (won) {
      winsP++;
      stats.roundsWon++;
    } else {
      winsB++;
      stats.roundsLost++;
    }
    final w = won ? p : b;
    w.taunting = true;
    w.tauntT = 0;
    w.moveDir = 0;
    w.blockHeld = false;
    events.add(BattleEvent(EvKind.roundEnd, side: won ? 0 : 1, label: won ? 'Thắng hiệp!' : 'Mất hiệp!'));
  }

  void _nextRound() {
    if (winsP >= roundsToWin || winsB >= roundsToWin) {
      phase = Phase.done;
      playerWon = winsP >= roundsToWin;
      stats.playerDmg = p.dmg;
      events.add(BattleEvent(EvKind.matchEnd, side: playerWon! ? 0 : 1));
    } else {
      round++;
      _startRound();
    }
  }

  /// Advances one fixed step. After the match the fighters keep moving (the winner's
  /// taunt plays behind the result card) but no round logic runs.
  void step([double dt = Battle.dt]) {
    for (final f in [p, b]) {
      if (f.taunting) f.tauntT += dt;
    }
    if (hitstop > 0) {
      hitstop -= dt;
      return;
    }
    now += dt;
    phaseT += dt;
    if (phase == Phase.ready) {
      if (phaseT >= 1.0) {
        phase = Phase.fight;
        phaseT = 0;
        events.add(const BattleEvent(EvKind.fight, label: 'ĐÁNH!'));
      }
      return;
    }
    if (phase == Phase.fight) {
      roundFightT += dt;
      stats.fightTime += dt;
      _updateWind(dt);
      if (roundFightT >= shrinkStart - 3 && !_shrinkWarned) {
        _shrinkWarned = true;
        events.add(const BattleEvent(EvKind.warn, label: 'Sàn sắp sụt!'));
      }
      if (roundFightT > shrinkStart) half = math.max(shrinkMin, half - shrinkSpeed * dt);
      brainB.update(this, b, p);
      if (brainP != null) {
        brainP!.update(this, p, b);
      } else {
        p.blockHeld = inBlock;
        p.moveDir = (inFwd ? 1 : 0) - (inBack ? 1 : 0);
      }
    } else {
      _updateWind(dt);
      p.blockHeld = false;
      p.moveDir = 0;
    }
    frame++;
    _updateShield(p, dt);
    _updateShield(b, dt);
    if (frame.isOdd) {
      _updateFighter(p, b, dt);
      _updateFighter(b, p, dt);
    } else {
      _updateFighter(b, p, dt);
      _updateFighter(p, b, dt);
    }
    if (p.state != FState.fall && b.state != FState.fall) {
      final gap = b.x - p.x;
      if (gap < 46) {
        final o = (46 - gap) / 2;
        p.x -= o;
        b.x += o;
      }
    }
    for (final f in [p, b]) {
      if (f.state != FState.fall && f.x.abs() > half + 2) {
        f.state = FState.fall;
        f.t = 0;
        f.vy = -160;
        f.r = 0;
        events.add(BattleEvent(EvKind.fall, side: _side(f), x: f.x));
      }
    }
    if (phase == Phase.fight) {
      if (p.state == FState.fall && p.t > 0.85) {
        _endRound(false);
      } else if (b.state == FState.fall && b.t > 0.85) {
        _endRound(true);
      }
    } else if (phase == Phase.over && phaseT > 1.6) {
      _nextRound();
    }
  }

  /// Runs a whole AI-vs-AI match (used by tests and balance tools). Returns true if the player side won.
  bool runToEnd({double maxSeconds = 600}) {
    var t = 0.0;
    while (!finished && t < maxSeconds) {
      step();
      t += dt;
      events.clear();
    }
    return playerWon ?? false;
  }
}

class _Seg {
  const _Seg(this.ax, this.ay, this.bx, this.by, this.r);
  final double ax, ay, bx, by, r;
}

class _HurtBox {
  const _HurtBox(this.hx, this.hy, this.hr2, this.segs, this.x0, this.y0, this.x1, this.y1);
  final double hx, hy, hr2;
  final List<_Seg> segs;
  final double x0, y0, x1, y1;

  /// 0 = miss, 1 = body, 2 = head.
  int test(double x, double y) {
    if (x < x0 || x > x1 || y < y0 || y > y1) return 0;
    final dx = x - hx, dy = y - hy;
    if (dx * dx + dy * dy < hr2) return 2;
    for (final s in segs) {
      final ux = s.bx - s.ax, uy = s.by - s.ay;
      var l = ux * ux + uy * uy;
      if (l == 0) l = 1;
      final t = clampD(((x - s.ax) * ux + (y - s.ay) * uy) / l, 0, 1);
      final ex = x - s.ax - ux * t, ey = y - s.ay - uy * t;
      if (ex * ex + ey * ey < s.r * s.r) return 1;
    }
    return 0;
  }
}

class _ShieldWorld {
  const _ShieldWorld(this.pts, this.x0, this.y0, this.x1, this.y1);
  final Float32List pts;
  final double x0, y0, x1, y1;
}

class _Contact {
  const _Contact(this.shield, this.head, this.x, this.y);
  final bool shield;
  final bool head;
  final double x, y;
}

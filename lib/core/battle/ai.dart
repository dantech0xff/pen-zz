import 'dart:math' as math;

import 'battle.dart';
import 'fighter.dart';

/// Bot controller ported from the web game. Higher [level] reacts faster, blocks more,
/// keeps its own range, backs off when a block would still push it, and punishes recoveries.
class BotBrain {
  BotBrain(this.level);

  final int level;
  bool seen = false;
  double blockAt = double.infinity;
  double releaseAt = 0;
  double atkAt = double.infinity;
  int moveDir = 0;
  double moveUntil = 0;
  double guardAt = 0;

  void reset() {
    seen = false;
    blockAt = double.infinity;
    releaseAt = 0;
    atkAt = double.infinity;
    moveDir = 0;
    moveUntil = 0;
    guardAt = 0;
  }

  void update(Battle g, Fighter me, Fighter foe) {
    final l = level.toDouble();
    final now = g.now, rng = g.rng;
    final dist = (me.x - foe.x).abs();
    final swinging = foe.state == FState.windup || foe.state == FState.strike;
    // Compare own defence with the foe's attack: block more when a block holds, back off when it would not.
    final safeBlock = me.s.has && me.s.def >= foe.w.atk - 4;
    final badBlock = !me.s.has || foe.w.atk - me.s.def > 150;
    final backRoom = g.half + me.f * me.x;
    if (swinging && !seen) {
      seen = true;
      final threat = dist <= foe.w.reach + 60;
      // The shield must be fully up before contact: reaction plus raise time against time left.
      final delay = rng.range(0.14, 0.32) * math.max(0.55, 1 - 0.06 * (l - 1));
      final left = (foe.state == FState.windup ? math.max(0.0, foe.windT - foe.t) : 0.0) + foe.w.strike * 0.45;
      final inTime = me.blockHeld || delay + g.raiseTime(me) * (1 - me.r) <= left;
      final pb = math.min(0.85, 0.3 + 0.08 * (l - 1) + (safeBlock ? 0.15 : 0) - (badBlock ? 0.2 : 0));
      if (threat && me.s.has && rng.next() < pb && (inTime || rng.next() < math.max(0.0, 0.7 - 0.15 * l))) {
        blockAt = now + (inTime ? delay : delay * 0.5);
      } else {
        blockAt = double.infinity;
        if (threat && (badBlock || !inTime) && l >= 2 && backRoom > 90) {
          moveDir = -1;
          moveUntil = now + 0.35;
        }
      }
    }
    // Against weapons too fast to react to, higher levels keep the shield up while in range.
    if (!swinging &&
        me.state == FState.idle &&
        !me.blockHeld &&
        me.s.has &&
        l >= 3 &&
        now >= guardAt &&
        dist <= foe.w.reach + 25 &&
        foe.w.windup * 0.9 < 0.22 + g.raiseTime(me)) {
      guardAt = now + 0.5;
      if (rng.next() < math.min(0.55, 0.12 * l)) {
        me.blockHeld = true;
        releaseAt = now + rng.range(0.45, 0.9);
      }
    }
    if (!swinging && seen) {
      seen = false;
      releaseAt = now + rng.range(0.06, 0.18);
    }
    if (now >= blockAt && me.state == FState.idle) {
      me.blockHeld = true;
      blockAt = double.infinity;
      atkAt = double.infinity;
    }
    if (me.blockHeld && !seen && releaseAt != 0 && now >= releaseAt) {
      me.blockHeld = false;
      releaseAt = 0;
    }
    // Movement: keep own range, stay off the edge, rush in when the foe is exposed.
    if (now >= moveUntil) {
      moveUntil = now + rng.range(0.15, 0.35);
      final myR = me.w.reach + 6, theirR = foe.w.reach + 22;
      final punish = foe.state == FState.recover || foe.state == FState.stun;
      var dir = 0;
      if (backRoom < 45) {
        dir = 1;
      } else if (punish && dist > myR - 5) {
        dir = 1;
      } else if (dist > myR + 4) {
        dir = 1;
      } else if (me.w.reach > foe.w.reach + 25 &&
          dist < theirR + 8 &&
          backRoom > 90 &&
          rng.next() < math.min(1, 0.5 + 0.25 * (l - 1))) {
        dir = -1;
      } else if (l >= 3 && rng.next() < 0.25) {
        dir = rng.next() < 0.5 ? -1 : 1;
      }
      moveDir = dir;
    }
    me.moveDir = moveDir;
    final inRange = dist <= me.w.reach + 10;
    if (me.state == FState.idle && !me.blockHeld && inRange && foe.state != FState.fall) {
      final punish = foe.state == FState.recover || foe.state == FState.stun;
      double pd() => rng.range(0.15, 0.35) * math.max(0.4, 1 - 0.12 * (l - 1));
      if (atkAt == double.infinity) {
        atkAt = now + (punish ? pd() : rng.range(0.15, 0.6) * math.max(0.5, 1 - 0.06 * (l - 1)));
      } else if (punish && atkAt - now > 0.4) {
        atkAt = now + pd();
      }
      if (now >= atkAt) {
        // Attacking into a raised shield that out-defends the weapon only bounces back; smart bots wait.
        final wall = foe.r >= 1 && foe.s.def > me.w.atk + 4 && rng.next() < math.min(0.9, 0.25 * l);
        if (wall) {
          atkAt = now + rng.range(0.2, 0.45);
        } else {
          atkAt = double.infinity;
          g.startAttack(me);
        }
      }
    } else if (!inRange) {
      atkAt = double.infinity;
    }
  }
}

/// Bots wind up slower at low levels (the same handicap as the web game).
double botWindMul(int level) => math.max(1, 1.6 - 0.08 * (level - 1));

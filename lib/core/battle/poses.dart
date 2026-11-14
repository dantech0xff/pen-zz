import 'dart:math' as math;

import '../mathx.dart';
import '../rig.dart';
import 'fighter.dart';

/// Breathing at rest, or a walk cycle while moving.
Pose idlePose(Fighter f, double animT) {
  if (f.walking) {
    final ph = f.walk, s = math.sin(ph), c = math.cos(ph);
    return Pose(
      hipX: 3,
      hipY: -45.5 - 2.4 * (1 - s.abs()),
      lean: 0.15,
      fFx: 3 + 13 * s,
      fFy: -math.max(0, c) * 8,
      fBx: 3 - 13 * s,
      fBy: -math.max(0, -c) * 8,
      hWx: hand0.x + 2 * s,
      hWy: hand0.y - c.abs() * 1.5,
      th: f.th,
    );
  }
  final b = math.sin(animT * 2.6 + (f.f < 0 ? 1.7 : 0));
  return Pose(hipY: -46 + b * 1.1, lean: 0.08 + b * 0.015, hWx: hand0.x, hWy: hand0.y + b * 1.2, th: f.th);
}

/// Taunt animation at time [t] since it started.
Pose tauntPose(String id, double t) {
  switch (id) {
    case 'nhay':
      final s = math.sin(t * 7), b = s.abs();
      return Pose(
        dy: -b * 16,
        rot: s * 0.1,
        hipY: -47,
        lean: s * 0.1,
        fFx: 13 + s * 6,
        fFy: -b * 9,
        fBx: -12 + s * 6,
        fBy: -(1 - b) * 5,
        hWx: 12,
        hWy: -114,
        hSx: 24,
        hSy: -66,
        th: -70 * deg + math.sin(t * 14) * 0.4,
      );
    case 'gong':
      return Pose(
        sc: 1 + 0.07 * math.sin(t * 5).abs(),
        hipY: -43,
        lean: -0.04,
        fFx: 20,
        fBx: -18,
        hWx: 8,
        hWy: -104,
        hSx: 20,
        hSy: -60,
        th: -95 * deg,
      );
    case 'cui-chao':
      final u = smooth(math.min(1, t / 0.4));
      return Pose(
        hipX: -3 * u,
        hipY: -46 + 1.5 * u,
        lean: 0.08 + 0.8 * u,
        head: 0.3 * u,
        fFx: 13,
        fBx: -11,
        hWx: hand0.x - 2 * u,
        hWy: hand0.y + 26 * u,
        hSx: 6 - 10 * u,
        hSy: -40,
        th: 40 * deg * u,
      );
    case 'xoay':
      return Pose(hipY: -46 + math.sin(t * 6), hWx: 28, hWy: -84, th: t * 12);
    case 'tra-da':
      final sip = math.max(0.0, math.sin(t * 2.2));
      return Pose(
        hipX: -2,
        hipY: -22,
        lean: -0.04,
        head: -0.08 * sip,
        fFx: 21,
        fBx: 10,
        hWx: 20,
        hWy: -36,
        th: 10 * deg,
        hSx: 16 - 8 * sip,
        hSy: -48 - 20 * sip,
      );
    case 'vo-tay':
      final k = math.sin(t * 8).abs();
      return Pose(
        dy: -k * 2,
        lean: 0.12,
        hWx: 18,
        hWy: -78 + 6 * (1 - k),
        hSx: 24,
        hSy: -78 - 6 * (1 - k),
        th: 25 * deg,
      );
    case 'ngu-gat':
      final b = math.sin(t * 1.6);
      return Pose(
        hipX: -2,
        hipY: -44 + b * 0.8,
        lean: -0.12,
        head: -0.55 + b * 0.04,
        hWx: 10,
        hWy: -52,
        hSx: 2,
        hSy: -44,
        th: 100 * deg,
      );
    case 'ngoi-thien':
      final fl = math.sin(t * 2);
      return Pose(
        dy: -14 - 4 * fl,
        hipY: -26,
        lean: 0.02,
        fFx: 18,
        fFy: -6,
        fBx: -10,
        fBy: -4,
        hWx: 16,
        hWy: -34,
        hSx: 10,
        hSy: -30,
        th: 10 * deg,
      );
    case 'chup-anh':
      return Pose(hipX: -2, lean: -0.1, head: -0.15, hWx: 12, hWy: -60, hSx: 30, hSy: -100, th: 30 * deg);
    default: // vay-tay
      return Pose(dy: -math.sin(t * 5).abs() * 2, hWx: 18, hWy: -110, th: -40 * deg + math.sin(t * 10) * 0.45);
  }
}

/// Taunts that hold a prop in the shield hand instead of the shield.
bool tauntHidesShield(String id) => id == 'tra-da' || id == 'chup-anh';

String poseKind(Fighter f) => f.taunting ? 'taunt' : f.state.name;

Pose poseFor(Fighter f, String kind, double animT) {
  switch (kind) {
    case 'windup':
      final p = Pose.mix(f.pz0 ?? restPose, windPose, clampD(f.th / thWind, 0, 1));
      p.th = f.th;
      return p;
    case 'strike':
      return strikeBody(f.th);
    case 'recover':
      final from = f.recFrom;
      final p = Pose.mix(idlePose(f, animT), strikeBody(from), from != 0 ? clampD(f.th / from, 0, 1) : 0);
      p.th = f.th;
      return p;
    case 'hitstun':
      final u = clampD(f.t / math.max(0.2, f.stunT == 0 ? 0.3 : f.stunT), 0, 1);
      final p = Pose.mix(hurtPose, idlePose(f, animT), smooth(clampD((u - 0.3) / 0.7, 0, 1)));
      p.th = f.th;
      return p;
    case 'stun':
      final w = math.sin(f.t * 9) * 0.06;
      return Pose(hipX: -6, hipY: -44, lean: -0.22 + w, head: -0.15 + w * 2, fFx: 20, fBx: -17, hWx: 6, hWy: -92, th: f.th);
    case 'fall':
      return Pose(head: -0.3, lean: 0, fFx: 18, fFy: -22, fBx: -16, fBy: -14, hWx: 16, hWy: -118, th: f.th);
    case 'taunt':
      return tauntPose(f.taunt, f.tauntT);
    default:
      return idlePose(f, animT);
  }
}

Pose basePose(Fighter f, double animT) {
  final k = poseKind(f), p = poseFor(f, k, animT);
  if (k != 'taunt') {
    final h = shHand(f.r);
    p.hSx = h.x;
    p.hSy = h.y;
  }
  return p;
}

/// Blends 0.16 s into a new pose kind; swing poses follow the swing angle exactly so
/// collision matches what is drawn.
void updatePose(Fighter f, double dt, double animT) {
  final kind = poseKind(f);
  if (kind != f.pk) {
    f.pfrom = f.pz;
    f.pk = kind;
    f.pb = 0;
    if (kind == 'windup') f.pz0 = f.pz ?? restPose;
  }
  f.pb += dt;
  var p = poseFor(f, kind, animT);
  if (kind != 'windup' && kind != 'strike' && kind != 'recover' && f.pfrom != null && f.pb < 0.16) {
    p = Pose.mix(f.pfrom!, p, smooth(f.pb / 0.16));
  }
  if (kind != 'taunt') {
    final h = shHand(f.r);
    p.hSx = h.x;
    p.hSy = h.y;
  }
  f.pz = p;
  f.rig = solveRig(p);
}

Rig rigOf(Fighter f, double animT) => f.rig ?? solveRig(basePose(f, animT));

enum Mood { calm, fierce, hurt, dizzy, happy, sleep }

Mood moodOf(Fighter f) {
  if (f.state == FState.hitstun || f.state == FState.fall) return Mood.hurt;
  if (f.state == FState.stun) return Mood.dizzy;
  if (f.taunting) return f.taunt == 'ngu-gat' ? Mood.sleep : Mood.happy;
  if (f.state == FState.windup || f.state == FState.strike || f.r > 0.5) return Mood.fierce;
  return Mood.calm;
}

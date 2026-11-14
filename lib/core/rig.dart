import 'dart:math' as math;

import 'mathx.dart';

// Shared constants of the stick figure, gear and arena (same values as the web game).
const double inkMax = 800;
const double startX = 110;
const P shRaised = P(24, -58);
const P shLow = P(6, -40);
const double shZone = 120;
const double drawW = 380;
const P feet = P(110, 356);
const double wR = 4.5;
const double sR = 5;
const double frictionBase = 1600;
const double grav = 2400;
const double thWind = -50 * deg;
const double thEnd = 110 * deg;
const double swingArc = thEnd - thWind;

/// Weapon grip at rest. Drawings are made relative to this point, so gear stays in the hand.
final P hand0 = P(4 + 26 * math.cos(-10 * deg), -72 + 26 * math.sin(-10 * deg));

abstract final class Len {
  static const double thigh = 26, shin = 26, upper = 22, fore = 21, torso = 40, head = 11;
}

class Ik {
  const Ik(this.j, this.e);
  final P j;
  final P e;
}

/// Two-bone inverse kinematics: root [r], target [t], bone lengths [a] and [b].
Ik ik(P r, P t, double a, double b, double bend) {
  var dx = t.x - r.x, dy = t.y - r.y;
  var d = hypot(dx, dy);
  if (d == 0) d = 0.001;
  final maxD = a + b - 0.5, minD = (a - b).abs() + 0.5;
  if (d > maxD) {
    dx *= maxD / d;
    dy *= maxD / d;
    d = maxD;
  } else if (d < minD) {
    dx *= minD / d;
    dy *= minD / d;
    d = minD;
  }
  final base = math.atan2(dy, dx);
  final ang = math.acos(clampD((a * a + d * d - b * b) / (2 * a * d), -1, 1));
  final j = base + bend * ang;
  return Ik(P(r.x + math.cos(j) * a, r.y + math.sin(j) * a), P(r.x + dx, r.y + dy));
}

/// While swinging, the hand runs on a circle around the shoulder tied to the weapon angle.
const double arcR = 36;
double arcAngle(double th) => -105 * deg + 0.8125 * (th - thWind);

/// Body pose: hip, lean, head tilt, foot and hand targets, arm-arc blend, weapon angle,
/// plus whole-body bounce, rotation and scale used by taunts.
class Pose {
  Pose({
    this.hipX = 0,
    this.hipY = -46,
    this.lean = 0.08,
    this.head = 0,
    this.fFx = 15,
    this.fFy = 0,
    this.fBx = -13,
    this.fBy = 0,
    double? hWx,
    double? hWy,
    double? hSx,
    double? hSy,
    this.arc = 0,
    this.th = 0,
    this.dy = 0,
    this.rot = 0,
    this.sc = 1,
  }) : hWx = hWx ?? hand0.x,
       hWy = hWy ?? hand0.y,
       hSx = hSx ?? shLow.x,
       hSy = hSy ?? shLow.y;

  double hipX, hipY, lean, head, fFx, fFy, fBx, fBy, hWx, hWy, hSx, hSy, arc, th, dy, rot, sc;

  Pose copy() => Pose(
    hipX: hipX,
    hipY: hipY,
    lean: lean,
    head: head,
    fFx: fFx,
    fFy: fFy,
    fBx: fBx,
    fBy: fBy,
    hWx: hWx,
    hWy: hWy,
    hSx: hSx,
    hSy: hSy,
    arc: arc,
    th: th,
    dy: dy,
    rot: rot,
    sc: sc,
  );

  static Pose mix(Pose p, Pose q, double u) => Pose(
    hipX: lerpD(p.hipX, q.hipX, u),
    hipY: lerpD(p.hipY, q.hipY, u),
    lean: lerpD(p.lean, q.lean, u),
    head: lerpD(p.head, q.head, u),
    fFx: lerpD(p.fFx, q.fFx, u),
    fFy: lerpD(p.fFy, q.fFy, u),
    fBx: lerpD(p.fBx, q.fBx, u),
    fBy: lerpD(p.fBy, q.fBy, u),
    hWx: lerpD(p.hWx, q.hWx, u),
    hWy: lerpD(p.hWy, q.hWy, u),
    hSx: lerpD(p.hSx, q.hSx, u),
    hSy: lerpD(p.hSy, q.hSy, u),
    arc: lerpD(p.arc, q.arc, u),
    th: lerpD(p.th, q.th, u),
    dy: lerpD(p.dy, q.dy, u),
    rot: lerpD(p.rot, q.rot, u),
    sc: lerpD(p.sc, q.sc, u),
  );
}

final Pose restPose = Pose();
final Pose windPose = Pose(hipX: -5, hipY: -44, lean: -0.16, fFx: 12, fFy: -4, arc: 1, th: thWind);
final Pose endPose = Pose(hipX: 11, hipY: -41, lean: 0.42, fFx: 31, fFy: 0, fBx: -14, fBy: 0, arc: 1, th: thEnd);
final Pose hurtPose = Pose(
  hipX: -9,
  hipY: -45,
  lean: -0.48,
  head: -0.45,
  fFx: 24,
  fFy: -10,
  fBx: -14,
  fBy: 0,
  hWx: 8,
  hWy: -96,
);

Pose strikeBody(double th) {
  final p = Pose.mix(windPose, endPose, clampD((th - thWind) / swingArc, 0, 1));
  p.th = th;
  return p;
}

P shoulderOf(Pose p) => P(p.hipX + math.sin(p.lean) * Len.torso * 0.88, p.hipY - math.cos(p.lean) * Len.torso * 0.88);

/// Grip position while striking; depends only on the swing angle.
P strikeHand(double th) {
  final sh = shoulderOf(strikeBody(th));
  final a = arcAngle(th);
  return P(sh.x + math.cos(a) * arcR, sh.y + math.sin(a) * arcR);
}

/// Shield hand between low (0) and fully raised (1).
P shHand(double r) => P(shLow.x + (shRaised.x - shLow.x) * r, shLow.y + (shRaised.y - shLow.y) * r);

class Rig {
  const Rig({
    required this.hip,
    required this.neck,
    required this.sh,
    required this.head,
    required this.ha,
    required this.lean,
    required this.kneeF,
    required this.footF,
    required this.kneeB,
    required this.footB,
    required this.elbW,
    required this.handW,
    required this.elbS,
    required this.handS,
  });

  final P hip, neck, sh, head, kneeF, footF, kneeB, footB, elbW, handW, elbS, handS;
  final double ha, lean;
}

Rig solveRig(Pose p) {
  final dirX = math.sin(p.lean), dirY = -math.cos(p.lean);
  final hip = P(p.hipX, p.hipY);
  final neck = P(hip.x + dirX * Len.torso, hip.y + dirY * Len.torso);
  final sh = P(hip.x + dirX * Len.torso * 0.88, hip.y + dirY * Len.torso * 0.88);
  final ha = p.lean + p.head;
  final head = P(neck.x + math.sin(ha) * (Len.head + 2), neck.y - math.cos(ha) * (Len.head + 2));
  var hw = P(p.hWx, p.hWy);
  if (p.arc > 0.001) {
    final a = arcAngle(p.th);
    final t = P(sh.x + math.cos(a) * arcR, sh.y + math.sin(a) * arcR);
    hw = P(hw.x + (t.x - hw.x) * p.arc, hw.y + (t.y - hw.y) * p.arc);
  }
  final lF = ik(hip, P(p.fFx, p.fFy), Len.thigh, Len.shin, -1);
  final lB = ik(hip, P(p.fBx, p.fBy), Len.thigh, Len.shin, -1);
  final aW = ik(sh, hw, Len.upper, Len.fore, 1);
  final aS = ik(sh, P(p.hSx, p.hSy), Len.upper, Len.fore, 1);
  return Rig(
    hip: hip,
    neck: neck,
    sh: sh,
    head: head,
    ha: ha,
    lean: p.lean,
    kneeF: lF.j,
    footF: lF.e,
    kneeB: lB.j,
    footB: lB.e,
    elbW: aW.j,
    handW: aW.e,
    elbS: aS.j,
    handS: aS.e,
  );
}

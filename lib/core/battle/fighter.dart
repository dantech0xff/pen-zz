import '../catalog.dart';
import '../gear.dart';
import '../mathx.dart';
import '../rig.dart';
import '../strokes.dart';

enum FState { idle, windup, strike, recover, hitstun, stun, fall }

/// Weapon ink: a flat colour, a grip-to-tip gradient, or the animated rainbow.
class WeaponInk {
  const WeaponInk(this.color, {this.grad, this.rainbow = false});
  final int color;
  final List<int>? grad;
  final bool rainbow;
  bool get special => grad != null || rainbow;
}

/// How a fighter looks: ink colours, cosmetics, hit effect and taunt.
class Look {
  const Look({
    required this.body,
    required this.weaponInk,
    required this.shieldInk,
    this.hat = 'khong-mu',
    this.cape = 'khong-choang',
    this.glass = 'khong-kinh',
    this.fx = 'muc',
    this.taunt = 'vay-tay',
  });

  final int body;
  final WeaponInk weaponInk;
  final int shieldInk;
  final String hat, cape, glass, fx, taunt;
}

const int opponentRed = 0xD3303C;

bool _isBodyInk(String id) => bodyInks.any((i) => i.id == id);
WeaponInk _special(String id) {
  final it = itemIndex[id]!;
  return WeaponInk(it.color!, grad: it.grad, rainbow: it.rainbow);
}

/// Look of the player, or of an opponent when [versus] (the player's equipment) is given.
/// Opponents never reuse one of the player's three colours: a clash turns their body red
/// and their weapon or shield back to their body colour. Special weapon inks always stay.
Look lookFor(Map<Slot, String> eq, {Map<Slot, String>? versus}) {
  String get(Slot s) => eq[s] ?? defaultEquip[s]!;
  late final int body;
  late final WeaponInk weapon;
  late final int shield;
  if (versus == null) {
    body = inkColor(get(Slot.ink));
    final iw = get(Slot.inkW);
    weapon = iw == sameInk
        ? WeaponInk(body)
        : weaponInks.any((i) => i.id == iw)
        ? _special(iw)
        : WeaponInk(_isBodyInk(iw) ? inkColor(iw) : body);
    final isd = get(Slot.inkS);
    shield = isd == sameInk || !_isBodyInk(isd) ? body : inkColor(isd);
  } else {
    String v(Slot s) => versus[s] ?? defaultEquip[s]!;
    final mine = [v(Slot.ink), v(Slot.inkW), v(Slot.inkS)].map((id) => id == sameInk ? v(Slot.ink) : id).toList();
    final id = get(Slot.ink);
    body = id != 'muc-xanh' && _isBodyInk(id) && !mine.contains(id) ? inkColor(id) : opponentRed;
    final iw = get(Slot.inkW);
    weapon = weaponInks.any((i) => i.id == iw)
        ? _special(iw)
        : WeaponInk(_isBodyInk(iw) && !mine.contains(iw) ? inkColor(iw) : body);
    final isd = get(Slot.inkS);
    shield = _isBodyInk(isd) && !mine.contains(isd) ? inkColor(isd) : body;
  }
  return Look(
    body: body,
    weaponInk: weapon,
    shieldInk: shield,
    hat: get(Slot.hat),
    cape: get(Slot.cape),
    glass: get(Slot.glass),
    fx: get(Slot.fx),
    taunt: get(Slot.taunt),
  );
}

final WeaponStats emptyWeapon = weaponStats(const []);
final ShieldStats emptyShield = shieldStats(const []);

/// A stick figure in a match, or a static preview (hero, thumbnails, wardrobe).
class Fighter {
  Fighter({
    required this.look,
    this.isBot = false,
    this.f = 1,
    this.x = 0,
    WeaponStats? w,
    ShieldStats? s,
    this.wStrokes = const [],
    this.sStrokes = const [],
    this.walkSp = walkBase,
    this.windMul = 1,
    this.tough = 1,
  }) : w = w ?? emptyWeapon,
       s = s ?? emptyShield;

  final Look look;
  final bool isBot;

  /// Facing: +1 looks right (player side), -1 looks left.
  final double f;
  double x;
  double y = 0, vx = 0, vy = 0, hop = 0, hopV = 0;
  final WeaponStats w;
  final ShieldStats s;
  final Strokes wStrokes;
  final Strokes sStrokes;
  final double walkSp;

  /// Extra wind-up time for bots (slower reactions at low AI levels).
  final double windMul;

  /// Resistance to knockback from upgrades, see [toughness].
  final double tough;

  FState state = FState.idle;
  double t = 0, th = 0;
  bool hit = false;
  double dmg = 0, r = 0, raisedAt = -9;
  bool blockHeld = false;
  double stunT = 0, windT = 0, recT = 0, recFrom = 0, walk = 0;
  bool walking = false;
  double rot = 0, buffer = 0;
  final List<P> trail = [];
  int moveDir = 0;
  bool pendingAtk = false;
  bool taunting = false;
  double tauntT = 0;

  // Pose blending state: current pose, rig, pose kind, blend source, blend time, wind-up start pose.
  Pose? pz;
  Rig? rig;
  String pk = '';
  Pose? pfrom;
  double pb = 0;
  Pose? pz0;

  // Ink effect statuses.
  double chillT = 0, burnT = 0, burnAcc = 0, shockT = 0;

  bool get chilled => chillT > 0;
  String get taunt => look.taunt;
}

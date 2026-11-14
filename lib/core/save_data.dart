import 'catalog.dart';
import 'gear.dart';
import 'levels.dart';
import 'rig.dart';
import 'strokes.dart';
import 'templates.dart';

/// Player progress, stored as JSON on the device.
class SaveData {
  SaveData({
    this.coins = 0,
    this.xp = 0,
    this.lvl = 1,
    this.free = 0,
    Points? pts,
    this.stage = 0,
    List<int>? stars,
    Set<String>? owned,
    Map<Slot, String>? eq,
    Strokes? w,
    Strokes? s,
    Set<String>? blueprints,
    this.sound = true,
    this.haptics = true,
    this.tutorialDone = false,
    this.wins = 0,
    this.losses = 0,
  }) : pts = pts ?? Points(),
       stars = stars ?? List<int>.filled(levelCount, 0),
       owned =
           owned ??
           {
             for (final id in defaultEquip.values)
               if (id != sameInk) id,
           },
       eq = eq ?? Map.of(defaultEquip),
       w = w ?? [],
       s = s ?? [],
       blueprints =
           blueprints ??
           {
             for (final t in [...weaponTemplates, ...shieldTemplates])
               if (t.starter) t.id,
           };

  static const int version = 1;

  int coins, xp, lvl, free;
  Points pts;

  /// Highest level cleared (0 = none).
  int stage;

  /// Star bits per level (index = level - 1).
  List<int> stars;
  Set<String> owned;
  Map<Slot, String> eq;
  Strokes w, s;
  Set<String> blueprints;
  bool sound, haptics, tutorialDone;
  int wins, losses;

  int get totalStars => stars.fold(0, (a, b) => a + starCount(b));

  Map<String, Object?> toJson() => {
    'v': version,
    'coins': coins,
    'xp': xp,
    'lvl': lvl,
    'free': free,
    'pts': pts.toJson(),
    'stage': stage,
    'stars': stars,
    'owned': owned.toList(),
    'eq': {for (final e in eq.entries) e.key.name: e.value},
    'w': roundSt(w),
    's': roundSt(s),
    'blueprints': blueprints.toList(),
    'sound': sound,
    'haptics': haptics,
    'tutorialDone': tutorialDone,
    'wins': wins,
    'losses': losses,
  };

  /// Reads a save defensively: unknown or broken fields fall back to defaults.
  static SaveData fromJson(Object? data) {
    final out = SaveData();
    if (data is! Map) return out;
    int n(Object? v, int lo, int hi, int d) => v is num && v.isFinite ? v.floor().clamp(lo, hi) : d;
    out.coins = n(data['coins'], 0, 1000000000, 0);
    out.xp = n(data['xp'], 0, 1000000000, 0);
    out.lvl = n(data['lvl'], 1, 999, 1);
    out.free = n(data['free'], 0, 9999, 0);
    final pp = data['pts'];
    if (pp is Map) {
      out.pts = Points(pow: n(pp['pow'], 0, 9999, 0), def: n(pp['def'], 0, 9999, 0), spd: n(pp['spd'], 0, 9999, 0));
    }
    out.stage = n(data['stage'], 0, levelCount, 0);
    final st = data['stars'];
    if (st is List) {
      for (var i = 0; i < levelCount && i < st.length; i++) {
        out.stars[i] = n(st[i], 0, 7, 0);
      }
    }
    final owned = data['owned'];
    if (owned is List) {
      out.owned.addAll(owned.whereType<String>().where(itemIndex.containsKey).take(400));
    }
    final eq = data['eq'];
    if (eq is Map) {
      for (final slot in Slot.values) {
        final id = eq[slot.name];
        if (id is String && fitsSlot(slot, id) && (id == sameInk || out.owned.contains(id))) out.eq[slot] = id;
      }
    }
    out.w = cleanStrokes(data['w']) ?? [];
    out.s = cleanStrokes(data['s']) ?? [];
    if (inkOf(out.w) + inkOf(out.s) > inkMax + 30) {
      out.w = [];
      out.s = [];
    }
    final bp = data['blueprints'];
    if (bp is List) {
      out.blueprints.addAll(bp.whereType<String>().where(templatesById.containsKey));
    }
    out.sound = data['sound'] != false;
    out.haptics = data['haptics'] != false;
    out.tutorialDone = data['tutorialDone'] == true;
    out.wins = n(data['wins'], 0, 100000000, 0);
    out.losses = n(data['losses'], 0, 100000000, 0);
    return out;
  }
}

/// Validates stroke data: at most 400 strokes and 5000 points, coordinates within ±420.
Strokes? cleanStrokes(Object? st) {
  if (st is! List || st.length > 400) return null;
  final out = <Stroke>[];
  var count = 0;
  for (final s in st) {
    if (s is! List || s.length < 2 || s.length.isOdd) continue;
    final t = <double>[];
    for (final v in s) {
      if (v is! num || !v.isFinite || v.abs() > 420) return null;
      t.add(v.toDouble());
    }
    count += t.length ~/ 2;
    if (count > 5000) return null;
    out.add(t);
  }
  return out;
}

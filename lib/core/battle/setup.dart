import '../bots.dart';
import '../catalog.dart';
import '../gear.dart';
import '../strokes.dart';
import 'ai.dart';
import 'battle.dart';
import 'fighter.dart';

/// The player's side of a match from saved gear, points and wardrobe.
BattleSide playerSide({
  required Strokes w,
  required Strokes s,
  required Points pts,
  required Map<Slot, String> eq,
  int? aiLevel,
}) => BattleSide(
  wStrokes: w,
  sStrokes: s,
  w: boostW(weaponStats(w), pts, inkFxOf(eq[Slot.inkW] ?? sameInk)),
  s: boostS(shieldStats(s), pts),
  look: lookFor(eq),
  pts: pts,
  aiLevel: aiLevel,
);

/// An opponent's side; its colours avoid the player's own inks.
BattleSide opponentSide(OppSpec o, Map<Slot, String> playerEq) => BattleSide(
  wStrokes: o.wStrokes,
  sStrokes: o.sStrokes,
  w: o.w,
  s: o.s ?? boostS(shieldStats(o.sStrokes), o.pts),
  look: lookFor(o.eq, versus: playerEq),
  pts: o.pts,
  aiLevel: o.aiL,
  windMul: botWindMul(o.aiL),
);

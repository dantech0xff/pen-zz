import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/arenas.dart';
import 'package:pen_zz/core/battle/battle.dart';
import 'package:pen_zz/core/battle/fighter.dart';
import 'package:pen_zz/core/battle/setup.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/gear.dart';
import 'package:pen_zz/core/levels.dart';
import 'package:pen_zz/core/rng.dart';
import 'package:pen_zz/core/strokes.dart';
import 'package:pen_zz/core/templates.dart';

Strokes proxyWeapon() => fillTo(scaleSt(templateOf('kiem').strokes, 1.05), 380);
Strokes proxyShield() => fillTo(templateOf('khien-tron').strokes, 360);

Points expectedPoints(int stage) {
  final lvl = 1 + (stage * 0.47).floor();
  final total = (lvl - 1) * 3;
  return Points(pow: total ~/ 3, def: total ~/ 3, spd: total - 2 * (total ~/ 3));
}

Battle stageBattle(int stage, {int seed = 1, int playerAi = 5, String inkW = sameInk, ArenaRules? rules}) {
  final eq = Map<Slot, String>.of(defaultEquip)..[Slot.inkW] = inkW;
  final me = playerSide(w: proxyWeapon(), s: proxyShield(), pts: expectedPoints(stage), eq: eq, aiLevel: playerAi);
  final o = stageOpponent(stage);
  botPickShield(o, me.w, Rng(seed));
  return Battle(
    BattleSetup(player: me, opponent: opponentSide(o, eq), rules: rules ?? LevelDef(stage).arena.rules, seed: seed),
  );
}

void main() {
  test('the same seed replays the same match', () {
    final a = stageBattle(12, seed: 42), b = stageBattle(12, seed: 42);
    var steps = 0;
    while (!a.finished && steps < 120 * 600) {
      a.step();
      b.step();
      steps++;
      expect(a.p.x, b.p.x);
      expect(a.b.dmg, b.b.dmg);
    }
    expect(a.finished, isTrue);
    expect(a.playerWon, b.playerWon);
  });

  test('AI matches finish on every arena', () {
    for (final stage in [1, 15, 25, 38, 44, 56, 63, 77, 85, 94, 108, 120]) {
      final g = stageBattle(stage, seed: stage);
      g.runToEnd(maxSeconds: 900);
      expect(g.finished, isTrue, reason: 'stage $stage on ${LevelDef(stage).arena.name}');
      expect(g.winsP == g.roundsToWin || g.winsB == g.roundsToWin, isTrue);
    }
  });

  test('ink effects apply on hit', () {
    final g = stageBattle(20, seed: 3, inkW: 'muc-lua');
    var burned = false;
    for (var i = 0; i < 120 * 120 && !g.finished; i++) {
      g.step();
      if (g.b.burnT > 0) burned = true;
      g.events.clear();
    }
    expect(burned, isTrue);

    final ice = stageBattle(20, seed: 4, inkW: 'muc-bang');
    var chilled = false;
    for (var i = 0; i < 120 * 120 && !ice.finished; i++) {
      ice.step();
      if (ice.b.chilled) chilled = true;
      ice.events.clear();
    }
    expect(chilled, isTrue);
  });

  test('walking never takes a fighter over the edge', () {
    final me = playerSide(w: proxyWeapon(), s: proxyShield(), pts: Points(), eq: Map.of(defaultEquip));
    final idleBot = opponentSide(
      OppSpec(
        kind: OppKind.practice,
        name: 'x',
        lvl: 1,
        aiL: 1,
        pts: Points(),
        eq: Map.of(defaultEquip),
        wStrokes: const [],
        wName: 'x',
        sStrokes: const [],
      ),
      defaultEquip,
    );
    final g = Battle(BattleSetup(player: me, opponent: idleBot, rules: const ArenaRules(), seed: 1));
    g.inBack = true;
    for (var i = 0; i < 120 * 12; i++) {
      g.step();
    }
    expect(g.p.state, isNot(FState.fall));
    expect(g.p.x, greaterThan(-g.half));
  });

  test('crumbling arenas shrink the floor', () {
    final me = playerSide(w: proxyWeapon(), s: proxyShield(), pts: Points(), eq: Map.of(defaultEquip));
    final idleBot = opponentSide(
      OppSpec(
        kind: OppKind.practice,
        name: 'x',
        lvl: 1,
        aiL: 1,
        pts: Points(),
        eq: Map.of(defaultEquip),
        wStrokes: const [],
        wName: 'x',
        sStrokes: const [],
      ),
      defaultEquip,
    );
    final rules = arenaOf('thanh-co').rules;
    final g = Battle(BattleSetup(player: me, opponent: idleBot, rules: rules, seed: 1));
    for (var i = 0; i < 120 * 30; i++) {
      g.step();
    }
    expect(g.half, lessThan(rules.half));
    expect(g.half, greaterThanOrEqualTo(rules.shrinkMin));
  });
}

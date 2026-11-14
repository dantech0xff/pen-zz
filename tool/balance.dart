// ignore_for_file: avoid_print
// Simulates AI-vs-AI matches to check the difficulty curve across the 120 levels and
// that no special ink dominates. Run: dart run tool/balance.dart
import 'package:pen_zz/core/arenas.dart';
import 'package:pen_zz/core/battle/battle.dart';
import 'package:pen_zz/core/battle/setup.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/gear.dart';
import 'package:pen_zz/core/levels.dart';
import 'package:pen_zz/core/rng.dart';
import 'package:pen_zz/core/strokes.dart';
import 'package:pen_zz/core/templates.dart';

/// Typical player gear: a filled sword and round shield, points of the level a player
/// usually has when reaching [stage] (first clears only).
BattleSide proxyPlayer(int stage, {int ai = 5, String inkW = sameInk, Map<Slot, String>? eq}) {
  final lvl = 1 + (stage * 0.47).floor();
  final total = (lvl - 1) * 3;
  final pts = Points(pow: total ~/ 3, def: total ~/ 3, spd: total - 2 * (total ~/ 3));
  final e = eq ?? (Map<Slot, String>.of(defaultEquip)..[Slot.inkW] = inkW);
  return playerSide(
    w: fillTo(scaleSt(templateOf('kiem').strokes, 1.05), 380),
    s: fillTo(templateOf('khien-tron').strokes, 360),
    pts: pts,
    eq: e,
    aiLevel: ai,
  );
}

void main() {
  print('Win rate of the proxy player (AI level 5) per notebook, 16 matches per level');
  print('chapter          arena                 normal  boss   fight s');
  for (var c = 0; c < chapters.length; c++) {
    var normalWins = 0, bossWins = 0, normal = 0, boss = 0;
    var time = 0.0;
    for (final i in [2, 5, 7, 10]) {
      final stage = c * 10 + i;
      for (var k = 0; k < 16; k++) {
        final me = proxyPlayer(stage);
        final o = stageOpponent(stage);
        botPickShield(o, me.w, Rng(k * 31 + stage));
        final g = Battle(
          BattleSetup(
            player: me,
            opponent: opponentSide(o, defaultEquip),
            rules: LevelDef(stage).arena.rules,
            seed: k * 7919 + stage,
          ),
        );
        final won = g.runToEnd(maxSeconds: 900);
        time += g.stats.fightTime;
        if (LevelDef(stage).boss) {
          boss++;
          if (won) bossWins++;
        } else {
          normal++;
          if (won) normalWins++;
        }
      }
    }
    print(
      '${chapters[c].name.padRight(16)} ${chapters[c].arena.name.padRight(20)}  '
      '${(normalWins * 100 / normal).toStringAsFixed(0).padLeft(4)}%  ${(bossWins * 100 / boss).toStringAsFixed(0).padLeft(4)}%  '
      '${(time / (normal + boss)).toStringAsFixed(1)}',
    );
  }

  print('\nSpecial inks: player with the ink vs identical player without (160 matches, stage 40 gear)');
  for (final ink in weaponInks) {
    var wins = 0;
    const n = 160;
    for (var k = 0; k < n; k++) {
      final me = proxyPlayer(40, inkW: ink.id);
      final mirror = proxyPlayer(40);
      final g = Battle(
        BattleSetup(
          player: me,
          opponent: BattleSide(
            wStrokes: mirror.wStrokes,
            sStrokes: mirror.sStrokes,
            w: mirror.w,
            s: mirror.s,
            look: mirror.look,
            pts: mirror.pts,
            aiLevel: 5,
          ),
          rules: const ArenaRules(),
          seed: 1000 + k,
        ),
      );
      if (g.runToEnd(maxSeconds: 900)) wins++;
    }
    print('${ink.name.padRight(14)} ${(wins * 100 / n).toStringAsFixed(0)}%');
  }
}

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/arenas.dart';
import 'package:pen_zz/core/battle/battle.dart';
import 'package:pen_zz/core/battle/fighter.dart';
import 'package:pen_zz/core/battle/setup.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/catalog.dart';
import 'package:pen_zz/core/gear.dart';
import 'package:pen_zz/core/rng.dart';
import 'package:pen_zz/core/templates.dart';
import 'package:pen_zz/game/battle_game.dart';

BattleGame newGame() {
  final eq = Map<Slot, String>.of(defaultEquip);
  final me = playerSide(w: templateOf('kiem').strokes, s: templateOf('khien-tron').strokes, pts: Points(), eq: eq);
  final o = stageOpponent(1);
  botPickShield(o, me.w, Rng(1));
  final battle = Battle(BattleSetup(player: me, opponent: opponentSide(o, eq), rules: arenas.first.rules, seed: 1));
  return BattleGame(battle: battle, arena: arenas.first, onMatchEnd: (_) {});
}

KeyDownEvent down(LogicalKeyboardKey l, PhysicalKeyboardKey p) =>
    KeyDownEvent(physicalKey: p, logicalKey: l, timeStamp: Duration.zero);

void main() {
  test('keys the battle does not use go on to the system', () {
    final game = newGame();
    final volume = down(LogicalKeyboardKey.audioVolumeUp, PhysicalKeyboardKey.audioVolumeUp);
    expect(game.onKeyEvent(volume, {LogicalKeyboardKey.audioVolumeUp}), KeyEventResult.ignored);
    final escape = down(LogicalKeyboardKey.escape, PhysicalKeyboardKey.escape);
    expect(game.onKeyEvent(escape, {LogicalKeyboardKey.escape}), KeyEventResult.ignored);
    final d = down(LogicalKeyboardKey.keyD, PhysicalKeyboardKey.keyD);
    expect(game.onKeyEvent(d, {LogicalKeyboardKey.keyD}), KeyEventResult.handled);
    expect(game.battle.inFwd, isTrue);
  });

  test('a key event does not cancel a pad the player is holding', () {
    final game = newGame();
    game.pad(block: true);
    final volume = down(LogicalKeyboardKey.audioVolumeDown, PhysicalKeyboardKey.audioVolumeDown);
    game.onKeyEvent(volume, {LogicalKeyboardKey.audioVolumeDown});
    expect(game.battle.inBlock, isTrue);
    game.pad(block: false);
    expect(game.battle.inBlock, isFalse);
  });

  test('no swing starts while the battle is paused', () {
    final game = newGame();
    final battle = game.battle;
    while (battle.phase != Phase.fight) {
      battle.step();
    }
    game.held.value = true;
    game.attack();
    expect(battle.p.state, FState.idle);
    game.held.value = false;
    game.attack();
    expect(battle.p.state, isNot(FState.idle));
  });
}

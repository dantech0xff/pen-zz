import 'package:flutter_test/flutter_test.dart';
import 'package:pen_zz/core/battle/battle.dart';
import 'package:pen_zz/core/bots.dart';
import 'package:pen_zz/core/levels.dart';
import 'package:pen_zz/state/game_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

MatchStats stats({int lost = 0, int hits = 0}) => MatchStats()
  ..roundsWon = 2
  ..roundsLost = lost
  ..hits = hits;

Future<GameController> freshController() async {
  SharedPreferences.setMockInitialValues({});
  final g = GameController();
  await g.load();
  return g;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a first win moves progress on and pays in full; a replay pays less', () async {
    final g = await freshController();
    final r = g.finishMatch(stageOpponent(1), true, stats());
    expect(r.firstClear, isTrue);
    expect(g.save.stage, 1);
    expect(g.nextStage, 2);
    expect(r.coins, greaterThanOrEqualTo(LevelDef(1).coins));
    expect(starCount(g.save.stars[0]), greaterThanOrEqualTo(2), reason: 'win and 2-0');

    final replay = g.finishMatch(stageOpponent(1), true, stats());
    expect(replay.firstClear, isFalse);
    expect(g.save.stage, 1);
    expect(replay.coins, lessThan(r.coins));
  });

  test('a loss gives a small reward and no progress', () async {
    final g = await freshController();
    final coins = g.save.coins;
    final r = g.finishMatch(stageOpponent(1), false, stats(lost: 2));
    expect(r.won, isFalse);
    expect(g.save.stage, 0);
    expect(g.save.coins, greaterThan(coins));
    expect(g.save.stars[0], 0);
  });

  test('beating the mini boss and the boss unlocks their blueprints once', () async {
    final g = await freshController();
    for (var stage = 1; stage <= 10; stage++) {
      final r = g.finishMatch(stageOpponent(stage), true, stats(hits: 99));
      final lv = LevelDef(stage);
      if (lv.unlocks != null) {
        expect(r.unlocked?.id, lv.unlocks, reason: 'stage $stage');
        expect(g.save.blueprints, contains(lv.unlocks));
      } else {
        expect(r.unlocked, isNull, reason: 'stage $stage');
      }
    }
    expect(g.save.stage, 10);
    expect(g.chaptersOpen, 2, reason: 'the second notebook opens');
    expect(g.finishMatch(stageOpponent(10), true, stats()).unlocked, isNull, reason: 'no second unlock');
  });

  test('levels up and upgrade points come from experience', () async {
    final g = await freshController();
    final lvl = g.save.lvl, free = g.save.free;
    for (var stage = 1; stage <= 20; stage++) {
      g.finishMatch(stageOpponent(stage), true, stats());
    }
    expect(g.save.lvl, greaterThan(lvl));
    expect(g.save.free, free + 3 * (g.save.lvl - lvl));
  });
}

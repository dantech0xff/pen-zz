import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/sfx.dart';
import '../core/arenas.dart';
import '../core/battle/battle.dart';
import '../core/battle/setup.dart';
import '../core/bots.dart';
import '../core/catalog.dart';
import '../core/gear.dart';
import '../core/levels.dart';
import '../core/rig.dart';
import '../core/rng.dart';
import '../core/save_data.dart';
import '../core/store_catalog.dart';
import '../core/strokes.dart';
import '../core/templates.dart';

/// What a finished match gave the player.
class MatchReward {
  MatchReward({
    required this.won,
    required this.coins,
    required this.xp,
    required this.levelsGained,
    this.starBits = 0,
    this.newStarBits = 0,
    this.firstClear = false,
    this.unlocked,
  });

  final bool won;
  final int coins, xp, levelsGained, starBits, newStarBits;
  final bool firstClear;
  final GearTemplate? unlocked;
}

enum Stat { pow, def, spd }

/// Holds the save, the player's derived gear stats, and every action that changes progress.
class GameController extends ChangeNotifier {
  static const _key = 'pen-zz-save-v1';

  SaveData save = SaveData();
  WeaponStats pw = weaponStats(const []);
  ShieldStats ps = shieldStats(const []);
  bool ready = false;
  Timer? _saveTimer;
  int _attempt = 0;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) save = SaveData.fromJson(jsonDecode(raw));
    } catch (_) {
      save = SaveData();
    }
    Sfx.instance.enabled = save.sound;
    Haptics.instance.enabled = save.haptics;
    _refresh();
    ready = true;
    notifyListeners();
  }

  void _refresh() {
    pw = boostW(weaponStats(save.w), save.pts, inkFxOf(save.eq[Slot.inkW] ?? sameInk));
    ps = boostS(shieldStats(save.s), save.pts);
  }

  void _changed() {
    _refresh();
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), flush);
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(save.toJson()));
    } catch (_) {
      // Storage can fail (private browsing); progress stays in memory for this session.
    }
  }

  bool get hasGear => save.w.isNotEmpty;
  int get nextStage => (save.stage + 1).clamp(1, levelCount);

  /// Notebooks the player has reached (unlocks arenas for practice).
  int get chaptersOpen => ((save.stage) ~/ levelsPerChapter + 1).clamp(1, chapters.length);

  // ---------------- gear and wardrobe ----------------

  /// Saves the drawings, cut to the ink cap so a later load never rejects them.
  void saveGear(Strokes w, Strokes s) {
    save.w = trimInk(roundSt(w), inkMax);
    save.s = trimInk(roundSt(s), inkMax - inkOf(save.w));
    _changed();
  }

  bool owns(String id) => id == sameInk || save.owned.contains(id);

  /// Buys (if needed) and equips. Returns false when coins are short.
  bool buyOrEquip(Slot slot, String id) {
    final it = itemById(id);
    if (it == null || !fitsSlot(slot, id)) return false;
    if (!owns(id)) {
      // Exclusive items come only from the store, never for coins.
      if (it.exclusive || save.coins < it.price) return false;
      save.coins -= it.price;
      save.owned.add(id);
      Sfx.instance.play('buy');
    } else {
      Sfx.instance.play('tap');
    }
    save.eq[slot] = id;
    _changed();
    return true;
  }

  void addPoint(Stat s) {
    if (save.free <= 0) return;
    switch (s) {
      case Stat.pow:
        save.pts.pow++;
      case Stat.def:
        save.pts.def++;
      case Stat.spd:
        save.pts.spd++;
    }
    save.free--;
    Sfx.instance.play('coin');
    _changed();
  }

  static const int respecCost = 100;

  bool respec() {
    final spent = save.pts.total;
    if (spent == 0 || save.coins < respecCost) return false;
    save.coins -= respecCost;
    save.free += spent;
    save.pts = Points();
    _changed();
    return true;
  }

  void setSound(bool on) {
    save.sound = on;
    Sfx.instance.enabled = on;
    _changed();
  }

  void setHaptics(bool on) {
    save.haptics = on;
    Haptics.instance.enabled = on;
    _changed();
  }

  void markTutorialDone() {
    if (save.tutorialDone) return;
    save.tutorialDone = true;
    _changed();
  }

  /// Starts over but keeps settings and everything bought with real money.
  Future<void> resetProgress() async {
    final old = save;
    save = SaveData(
      sound: old.sound,
      haptics: old.haptics,
      noAds: old.noAds,
      creditedPacks: old.creditedPacks,
      creditedTx: old.creditedTx,
      storeSince: old.storeSince,
      adDay: old.adDay,
      adCoinsUsed: old.adCoinsUsed,
      epoch: old.epoch + 1,
    );
    save.owned.addAll(old.owned.where((id) => itemIndex[id]?.exclusive ?? false));
    _changed();
    await flush();
  }

  /// Takes over a save merged with the cloud copy. Sound and haptics follow the new save,
  /// which keeps this phone's own settings.
  void replaceSave(SaveData merged) {
    save = merged;
    Sfx.instance.enabled = save.sound;
    Haptics.instance.enabled = save.haptics;
    _changed();
  }

  // ---------------- purchases and ads ----------------

  /// Extra coins and experience, e.g. from a rewarded ad. Returns the levels gained.
  int addBonus({required int coins, required int xp}) {
    save.coins += coins;
    final gained = _addXp(xp);
    _changed();
    return gained;
  }

  /// Coins from a rewarded "free coins" view on [day] (yyyymmdd).
  void creditAdCoins(int day, int coins) {
    if (save.adDay != day) {
      save.adDay = day;
      save.adCoinsUsed = 0;
    }
    save.adCoinsUsed++;
    save.coins += coins;
    _changed();
  }

  void resetAdCounter() {
    save.matchesSinceAd = 0;
    _changed();
  }

  /// Applies what the store reports and returns the coins credited.
  ///
  /// Entitlements unlock their items and switch ads off, and a one-time pack's coins are paid
  /// once. Coin packs are paid once per RevenueCat transaction id. The first snapshot this save
  /// sees sets [SaveData.storeSince] from the store's clock (or [purchaseTime], if earlier),
  /// and coin packs bought before it belong to an older install, so they are not paid again.
  int applyStore(StoreSnapshot snap, {DateTime? purchaseTime}) {
    var credited = 0;
    if (save.storeSince == 0) {
      final times = [snap.serverTime, purchaseTime].whereType<DateTime>();
      if (times.isNotEmpty) {
        // A minute of slack so a purchase made right at the first contact still counts.
        save.storeSince = times.reduce((a, b) => a.isBefore(b) ? a : b).millisecondsSinceEpoch - 60 * 1000;
      }
    }
    save.noAds = snap.entitlements.contains(Ent.noAds);
    for (final p in storeProducts) {
      final e = p.entitlement;
      if (e == null || !snap.entitlements.contains(e)) continue;
      save.owned.addAll(p.items);
      if (p.coins > 0 && save.creditedPacks.add(p.id)) {
        save.coins += p.coins;
        credited += p.coins;
      }
    }
    final since = save.storeSince;
    if (since > 0) {
      for (final t in snap.transactions) {
        final p = productById(t.productId), time = t.time;
        if (p == null || p.kind != ProductKind.consumable || time == null) continue;
        if (time.millisecondsSinceEpoch < since || save.creditedTx.containsKey(t.id)) continue;
        save.creditedTx[t.id] = p.coins;
        save.coins += p.coins;
        credited += p.coins;
      }
    }
    _changed();
    return credited;
  }

  // ---------------- matches ----------------

  /// Builds the match: the bot draws its shield now, after seeing the player's weapon.
  Battle startBattle(OppSpec o, ArenaDef arena) {
    _attempt++;
    final seed = hashString('${o.kind.name}-${o.stage}-${o.name}') ^ (_attempt * 7919);
    if (o.kind != OppKind.ghost) botPickShield(o, pw, Rng(seed));
    final me = playerSide(w: save.w, s: save.s, pts: save.pts, eq: save.eq);
    return Battle(BattleSetup(player: me, opponent: opponentSide(o, save.eq), rules: arena.rules, seed: seed));
  }

  int _addXp(int x) {
    save.xp += x;
    var n = 0;
    while (save.xp >= xpNeed(save.lvl)) {
      save.xp -= xpNeed(save.lvl);
      save.lvl++;
      save.free += 3;
      n++;
    }
    return n;
  }

  MatchReward finishMatch(OppSpec o, bool won, MatchStats st) {
    save.matchesSinceAd++;
    var coins = 0, xp = 0, bits = 0, newBits = 0;
    var first = false;
    GearTemplate? unlocked;
    if (o.kind == OppKind.stage) {
      final lv = LevelDef(o.stage);
      first = o.stage > save.stage;
      if (won) {
        coins = (lv.coins * (first ? 1 : 0.4)).round();
        xp = (lv.xp * (first ? 1 : 0.5)).round();
        if (first) save.stage = o.stage;
        bits = starBits(true, st, lv.goal);
        final old = save.stars[o.stage - 1];
        newBits = bits & ~old;
        save.stars[o.stage - 1] = old | bits;
        if (newBits & starFlawless != 0) coins += (lv.coins * 0.25).round();
        if (newBits & starGoal != 0) coins += (lv.coins * 0.5).round();
        final id = lv.unlocks;
        if (id != null && save.blueprints.add(id)) unlocked = templateOf(id);
      } else {
        coins = 5 + o.stage;
        xp = 10 + 2 * o.stage;
      }
    } else {
      coins = won ? 20 : 5;
      xp = won ? 30 : 10;
    }
    if (won) {
      save.wins++;
    } else {
      save.losses++;
    }
    save.coins += coins;
    final gained = _addXp(xp);
    Sfx.instance.play(gained > 0 ? 'lvup' : (newBits != 0 ? 'star' : 'coin'));
    _changed();
    return MatchReward(
      won: won,
      coins: coins,
      xp: xp,
      levelsGained: gained,
      starBits: bits,
      newStarBits: newBits,
      firstClear: first && won,
      unlocked: unlocked,
    );
  }
}

/// Gives widgets access to the controller and rebuilds them when it changes.
class AppScope extends InheritedNotifier<GameController> {
  const AppScope({super.key, required GameController controller, required super.child}) : super(notifier: controller);

  static GameController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static GameController read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

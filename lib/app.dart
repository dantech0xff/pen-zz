import 'package:flutter/material.dart';

import 'core/arenas.dart';
import 'core/bots.dart';
import 'core/levels.dart';
import 'state/game_controller.dart';
import 'state/cloud_sync.dart';
import 'state/monetization.dart';
import 'ui/screens/battle_screen.dart';
import 'ui/screens/draw_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/practice_screen.dart';
import 'ui/screens/pre_match_screen.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/screens/upgrade_screen.dart';
import 'ui/theme.dart';

enum Scr { home, draw, pre, battle, upgrade, shop, practice }

enum DrawMode { weapon, shield }

/// Where the editor was opened from: the first-time flow, the lobby, or the pre-match screen.
enum DrawFrom { first, home, pre }

/// Screen state of the app, like `go(name)` in the web version.
class Nav extends ChangeNotifier {
  Scr scr = Scr.home;
  DrawMode drawMode = DrawMode.weapon;
  DrawFrom drawFrom = DrawFrom.home;
  OppSpec? opp;
  ArenaDef arena = arenas.first;

  /// Stage picked on the lobby map; null follows the next unbeaten stage.
  int? selStage;
  int battleKey = 0;

  void go(Scr s) {
    scr = s;
    notifyListeners();
  }

  void home() => go(Scr.home);

  void openEditor(DrawMode mode, DrawFrom from) {
    drawMode = mode;
    drawFrom = from;
    go(Scr.draw);
  }

  void openStage(int stage) {
    final st = stage.clamp(1, levelCount);
    opp = stageOpponent(st);
    arena = LevelDef(st).arena;
    go(Scr.pre);
  }

  void openOpponent(OppSpec o, ArenaDef a) {
    opp = o;
    arena = a;
    go(Scr.pre);
  }

  void startBattle() {
    battleKey++;
    go(Scr.battle);
  }

  /// Android back button / back chips. Returns true when the app may close.
  bool back() {
    switch (scr) {
      case Scr.home:
        return true;
      case Scr.draw:
      case Scr.battle:
        // These screens handle back themselves (editor steps, pause menu).
        break;
      case Scr.pre:
        go(opp?.kind == OppKind.stage ? Scr.home : Scr.practice);
      case Scr.upgrade:
      case Scr.shop:
      case Scr.practice:
        home();
    }
    return false;
  }
}

class NavScope extends InheritedNotifier<Nav> {
  const NavScope({super.key, required Nav nav, required super.child}) : super(notifier: nav);
  static Nav of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<NavScope>()!.notifier!;
  static Nav read(BuildContext context) => context.getInheritedWidgetOfExactType<NavScope>()!.notifier!;
}

class PenApp extends StatefulWidget {
  const PenApp({super.key, required this.controller, this.monetization, this.cloud});
  final GameController controller;

  /// Ads and the store; none when left out (the web build and widget tests).
  final Monetization? monetization;

  /// Cloud save; none when left out.
  final CloudSync? cloud;

  @override
  State<PenApp> createState() => _PenAppState();
}

class _PenAppState extends State<PenApp> {
  final Nav _nav = Nav();
  late final AppLifecycleListener _life;
  late final Monetization _money = widget.monetization ?? Monetization.none(widget.controller);
  late final CloudSync _cloud = widget.cloud ?? CloudSync.none(widget.controller);

  void _save() {
    widget.controller.flush();
    _cloud.push();
  }

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onPause: _save, onDetach: _save, onResume: _cloud.connect);
    // The consent message needs a screen, so ads, the store and the cloud start after the
    // first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _money.init();
      _cloud.init();
    });
  }

  @override
  void dispose() {
    _life.dispose();
    if (widget.monetization == null) _money.dispose();
    if (widget.cloud == null) _cloud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    controller: widget.controller,
    child: MonetizationScope(
      monetization: _money,
      child: CloudScope(
        sync: _cloud,
        child: NavScope(
          nav: _nav,
          child: MaterialApp(
            title: 'Bút Chiến',
            debugShowCheckedModeBanner: false,
            theme: appTheme(),
            home: const _Shell(),
          ),
        ),
      ),
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell();

  @override
  Widget build(BuildContext context) {
    final nav = NavScope.of(context);
    final Widget screen = switch (nav.scr) {
      Scr.home => const HomeScreen(),
      Scr.draw => DrawScreen(key: ValueKey('draw-${nav.drawFrom.name}'), from: nav.drawFrom, initialMode: nav.drawMode),
      Scr.pre => const PreMatchScreen(),
      Scr.battle => BattleScreen(key: ValueKey('battle-${nav.battleKey}')),
      Scr.upgrade => const UpgradeScreen(),
      Scr.shop => const ShopScreen(),
      Scr.practice => const PracticeScreen(),
    };
    return PopScope(
      canPop: nav.scr == Scr.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.back();
      },
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(key: ValueKey(nav.scr), child: screen),
        ),
      ),
    );
  }
}

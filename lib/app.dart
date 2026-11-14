import 'package:flutter/material.dart';

import 'core/arenas.dart';
import 'core/bots.dart';
import 'core/levels.dart';
import 'state/game_controller.dart';
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
  int selStage = 1;
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
    selStage = stage.clamp(1, levelCount);
    opp = stageOpponent(selStage);
    arena = LevelDef(selStage).arena;
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
        go(drawFrom == DrawFrom.pre ? Scr.pre : Scr.home);
      case Scr.pre:
        go(opp?.kind == OppKind.stage ? Scr.home : Scr.practice);
      case Scr.battle:
        // The battle screen handles back itself (pause menu).
        break;
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
  const PenApp({super.key, required this.controller});
  final GameController controller;

  @override
  State<PenApp> createState() => _PenAppState();
}

class _PenAppState extends State<PenApp> {
  final Nav _nav = Nav();
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onPause: widget.controller.flush, onDetach: widget.controller.flush);
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    controller: widget.controller,
    child: NavScope(
      nav: _nav,
      child: MaterialApp(
        title: 'Bút Chiến',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: const _Shell(),
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
        if (!didPop && nav.scr != Scr.battle) nav.back();
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

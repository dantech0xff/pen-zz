import 'dart:math' as math;

import 'package:flame/extensions.dart';
import 'package:flame/game.dart' show Game;
import 'package:flame/input.dart' show KeyboardEvents;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, KeyEventResult;

import '../audio/sfx.dart';
import '../core/arenas.dart';
import '../core/battle/battle.dart';
import '../core/battle/fighter.dart';
import '../core/catalog.dart';
import '../core/ink_fx.dart';
import '../core/mathx.dart';
import '../render/arena_painter.dart';
import '../render/fighter_painter.dart';
import '../render/fx.dart';
import '../render/ink_painter.dart';
import '../render/palette.dart';
import '../render/text_fx.dart';

/// Room kept around the two fighters when framing (the web game used 320; phones get a closer camera).
const double _margin = 260;

/// What the Flutter HUD shows; rebuilt only when a value changes.
@immutable
class HudState {
  const HudState({
    this.pctP = 0,
    this.pctB = 0,
    this.winsP = 0,
    this.winsB = 0,
    this.round = 1,
    this.atkReady = false,
    this.blockReady = true,
  });

  final int pctP, pctB, winsP, winsB, round;
  final bool atkReady, blockReady;

  @override
  bool operator ==(Object other) =>
      other is HudState &&
      other.pctP == pctP &&
      other.pctB == pctB &&
      other.winsP == winsP &&
      other.winsB == winsB &&
      other.round == round &&
      other.atkReady == atkReady &&
      other.blockReady == blockReady;

  @override
  int get hashCode => Object.hash(pctP, pctB, winsP, winsB, round, atkReady, blockReady);
}

Color _fxStatusColor(InkFx fx) => switch (fx) {
  InkFx.ice => const Color(0xFF2A8FD0),
  InkFx.fire => const Color(0xFFE8541C),
  InkFx.shock => const Color(0xFF4A7FF0),
  InkFx.leech => const Color(0xFF9B1D4F),
  _ => Pal.pencil,
};

/// Runs a [Battle] at a fixed 120 Hz step and draws it like the web game's arena canvas.
class BattleGame extends Game with KeyboardEvents {
  BattleGame({required this.battle, required this.arena, required this.onMatchEnd, this.reduceMotion = false});

  final Battle battle;
  final ArenaDef arena;
  final void Function(bool won) onMatchEnd;

  /// No screen shake when the system asks for reduced motion.
  bool reduceMotion;

  final FxSystem fx = FxSystem();
  final ValueNotifier<HudState> hud = ValueNotifier(const HudState());

  /// Set by the screen (pause menu, app in background).
  final ValueNotifier<bool> held = ValueNotifier(false);

  double animT = 0;
  double _acc = 0;
  Size _size = const Size(320, 300);
  double camX = 0, camZ = 1;
  double _shake = 0;
  String _banner = '';
  double _bannerT = 0;
  bool _ended = false;
  bool _camInit = false;
  final math.Random _r = math.Random();

  @override
  Color backgroundColor() => rgb(arena.theme.paper);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _size = Size(size.x, size.y);
    if (!_camInit) {
      camZ = clampD(math.min(_size.width / (2 * 110 + _margin), _size.height / 400), 0.35, 1.6);
      _camInit = true;
    }
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !battle.finished) held.value = true;
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    bool has(List<LogicalKeyboardKey> ks) => ks.any(keysPressed.contains);
    battle.inFwd = has([LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight]);
    battle.inBack = has([LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft]);
    battle.inBlock = has([LogicalKeyboardKey.keyK, LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight]);
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.keyJ || event.logicalKey == LogicalKeyboardKey.space)) {
      battle.pressAttack();
    }
    return KeyEventResult.handled;
  }

  void _banner2(String text, double dur) {
    _banner = text;
    _bannerT = dur;
  }

  Fighter _side(int s) => s == 0 ? battle.p : battle.b;

  void _consume() {
    final sfx = Sfx.instance, hap = Haptics.instance;
    for (final e in battle.events) {
      switch (e.kind) {
        case EvKind.round:
          _banner2(e.label, double.infinity);
          fx.clear();
          camX = 0;
        case EvKind.fight:
          _banner2(e.label, 0.6);
        case EvKind.whoosh:
          sfx.play('whoosh', volume: 0.7);
        case EvKind.hit:
          final attacker = _side(1 - e.side);
          fx.hitFx(e.x, e.y, e.dir, e.fx, fxColorOf(attacker.look, animT));
          fx.pop(e.label, e.x, e.y - 28, rgb(e.color), e.size);
          _shake = math.max(_shake, e.shake);
          sfx.play('hit');
          if (e.side == 0) {
            hap.medium();
          } else {
            hap.light();
          }
        case EvKind.block:
          final d = _side(e.side);
          fx.sparks(e.x, e.y, e.dir, sparkGrey, 5, 380);
          fx.sparks(e.x, e.y, e.dir, rgb(d.look.shieldInk), 6, 420);
          fx.pop(e.label, e.x, e.y - 28, rgb(e.color), e.size);
          _shake = math.max(_shake, e.shake);
          sfx.play('block');
          hap.light();
        case EvKind.parry:
          final d = _side(e.side);
          fx.ring(e.x, e.y, rgb(d.look.shieldInk));
          fx.sparks(e.x, e.y, e.dir, Pal.gold, 16, 520);
          fx.pop(e.label, e.x, e.y - 34, rgb(e.color), e.size);
          _shake = math.max(_shake, e.shake);
          sfx.play('parry');
          hap.heavy();
        case EvKind.shieldUp:
          fx.ring(e.x, e.y, rgb(e.color), small: true);
        case EvKind.fall:
          sfx.play('fall');
          if (e.side == 0) hap.heavy();
        case EvKind.roundEnd:
          _banner2(e.label, double.infinity);
          sfx.play(e.side == 0 ? 'win' : 'lose');
        case EvKind.matchEnd:
          if (!_ended) {
            _ended = true;
            _banner2('', 0);
            onMatchEnd(e.side == 0);
          }
        case EvKind.status:
          final col = e.inkFx == InkFx.none ? rgb(e.color) : _fxStatusColor(e.inkFx);
          fx.pop(e.label, e.x, e.y, col, e.size);
          switch (e.inkFx) {
            case InkFx.ice:
              fx.hitFx(e.x, e.y + 60, 1, 'tuyet', col, n: 8, speed: 200);
              sfx.play('freeze', volume: 0.7);
            case InkFx.fire:
              fx.hitFx(e.x, e.y + 70, 1, 'lua', col, n: 6, speed: 220);
              sfx.play('burn', volume: 0.7);
            case InkFx.shock:
              fx.hitFx(e.x, e.y + 40, 1, 'set', col);
              sfx.play('zap', volume: 0.7);
            case InkFx.leech:
              fx.hitFx(e.x, e.y + 60, 1, 'trai-tim', col);
              sfx.play('heal', volume: 0.7);
            default:
              break;
          }
        case EvKind.warn:
          _banner2(e.label, 1.4);
          sfx.play('crumble');
      }
    }
    battle.events.clear();
  }

  @override
  void update(double dt) {
    if (held.value) return;
    dt = math.min(dt, 0.05);
    animT += dt;
    _acc += dt;
    var steps = 0;
    while (_acc >= Battle.dt && steps < 10) {
      battle.step();
      _acc -= Battle.dt;
      steps++;
    }
    if (steps == 10) _acc = 0;
    _consume();
    fx.update(dt);
    _shake = math.max(0, _shake - dt * 45);
    if (_banner.isNotEmpty && _bannerT != double.infinity) {
      _bannerT -= dt;
      if (_bannerT <= 0) _banner = '';
    }
    for (final f in [battle.p, battle.b]) {
      if (f.state == FState.strike && f.trail.isNotEmpty) fx.trailFx(f.look.fx, f.trail.last.x, f.trail.last.y);
    }
    if (battle.half < arena.rules.half - 1 && battle.phase == Phase.fight && _r.nextDouble() < dt * 6) {
      for (final s in [-1.0, 1.0]) {
        fx.parts.add(
          Part(
            PartKind.blot,
            s * battle.half + _r.nextDouble() * 6 * s,
            4,
            const Color(0xFF8A6D2F),
            0.8,
            vx: s * (20 + _r.nextDouble() * 40),
            vy: 60,
            r: 2 + _r.nextDouble() * 3,
          ),
        );
      }
    }
    _updateCam(dt);
    final p = battle.p, b = battle.b;
    final d = b.x - p.x;
    final show = battle.phase == Phase.fight && p.state != FState.fall && b.state != FState.fall;
    hud.value = HudState(
      pctP: jsRound(p.dmg),
      pctB: jsRound(b.dmg),
      winsP: battle.winsP,
      winsB: battle.winsB,
      round: battle.round,
      atkReady: show && d <= p.w.reach + 21 && p.state == FState.idle,
      blockReady: p.s.has,
    );
  }

  void _updateCam(double dt) {
    final p = battle.p, b = battle.b, half = arena.rules.half;
    var cx = clampD((p.x + b.x) / 2, -half + 80, half - 80);
    var zt = clampD(math.min(_size.width / ((b.x - p.x).abs() + _margin), _size.height / 400), 0.35, 1.6);
    if (battle.phase == Phase.over || battle.phase == Phase.done) {
      final w = p.taunting ? p : b;
      cx = w.x;
      zt = clampD(math.min(_size.width / 420, _size.height / 380), 0.35, 1.8);
    }
    final k = math.min(1.0, dt * 3.2);
    camX += (cx - camX) * k;
    camZ += (zt - camZ) * k;
  }

  @override
  void render(Canvas c) {
    final w = _size.width, h = _size.height;
    paintPaper(c, _size, arena.theme, camX * camZ);
    var shx = 0.0, shy = 0.0;
    if (_shake > 0 && !reduceMotion) {
      shx = (_r.nextDouble() - 0.5) * _shake;
      shy = (_r.nextDouble() - 0.5) * _shake;
    }
    final z = camZ, ox = w / 2 + shx - camX * z, oy = h * 0.64 + shy;
    Offset toS(double x, double y) => Offset(ox + x * z, oy + y * z);
    c.save();
    c.translate(ox, oy);
    c.scale(z, z);
    paintDoodles(c, arena.theme, arena.rules.half);
    paintPlatform(c, arena, battle.half, animT);
    final p = battle.p, b = battle.b;
    final showRanges =
        battle.phase != Phase.done && battle.phase != Phase.over && p.state != FState.fall && b.state != FState.fall;
    if (showRanges) {
      final d = b.x - p.x;
      paintRangeTick(c, p.x + p.w.reach, rgb(p.look.body), d <= p.w.reach + 21, 1);
      paintRangeTick(c, b.x - b.w.reach, rgb(b.look.body), d <= b.w.reach + 21, -1);
    }
    for (final f in [p, b]) {
      final fade = f.state == FState.strike
          ? 1.0
          : f.state == FState.recover
          ? clampD(1 - f.t / 0.15, 0, 1)
          : 0.0;
      drawTrail(c, f.look.fx, fxColorOf(f.look, animT), f.trail, fade, animT);
    }
    for (final f in [b, p]) {
      c.save();
      c.translate(f.x, f.y + f.hop);
      if (f.state == FState.fall) c.rotate(f.rot);
      c.scale(f.f, 1);
      paintFighter(c, f, animT);
      c.restore();
    }
    fx.draw(c);
    c.restore();
    if (b.state == FState.windup) {
      final s = toS(b.x, b.y + b.hop - 128);
      drawText(c, '!', s.dx, s.dy, 28, rgb(b.look.body), family: Fonts.display, outline: 5);
    }
    for (final f in [p, b]) {
      if (f.taunting && f.tauntT > 0.15 && f.state != FState.fall) {
        final s = toS(f.x, f.y - 148);
        drawBubble(c, s.dx, s.dy, tauntSay(f.look.taunt), rgb(f.look.body), w);
      }
    }
    for (final pop in fx.pops) {
      final s = toS(pop.x, pop.y);
      drawText(
        c,
        pop.text,
        s.dx,
        s.dy,
        pop.size,
        pop.col,
        family: Fonts.display,
        outline: 5,
        alpha: clampD(pop.life / Pop.max * 1.6, 0, 1),
      );
    }
    paintWind(c, _size, battle.windNow, animT);
    if (_banner.isNotEmpty) {
      final tp = textPainter(_banner, 36, Pal.ink, family: Fonts.display);
      c.save();
      c.translate(w / 2, h * 0.22);
      c.rotate(-2 * deg);
      fillRect(c, -tp.width / 2 - 12, -2, tp.width + 24, 22, withAlpha(Pal.hl, 0.92));
      tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
      c.restore();
    }
  }
}

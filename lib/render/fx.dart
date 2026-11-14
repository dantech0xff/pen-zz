import 'dart:math' as math;
import 'dart:ui';

import '../core/mathx.dart';
import 'ink_painter.dart';
import 'palette.dart';
import 'text_fx.dart';

enum PartKind { streak, ring, ember, dot, petal, bolt, bubble, star, heart, flake, confetti, word, leaf, blot, note, pixel }

class Part {
  Part(this.kind, this.x, this.y, this.col, this.life,
      {this.vx = 0, this.vy = 0, this.w = 3, this.r = 3, this.rot = 0, this.vr = 0, this.a = 0, this.len = 0, this.seed = 0,
      this.r0 = 14, this.grow = 70, this.lw = 4, this.text = ''})
      : max = life;

  final PartKind kind;
  double x, y, vx, vy, life;
  final double max;
  final Color col;
  final double w, r, a, len, seed, r0, grow, lw, vr;
  double rot;
  final String text;
}

/// Floating text (damage, block results, statuses).
class Pop {
  Pop(this.text, this.x, this.y, this.col, this.size) : life = 0.9;
  final String text;
  final double x;
  double y;
  final Color col;
  final double size;
  double life;
  static const double max = 0.9;
}

/// Hit, trail and parry particles. Purely visual, so it uses its own unseeded random.
class FxSystem {
  final List<Part> parts = [];
  final List<Pop> pops = [];
  final math.Random _r = math.Random();

  double rand(double a, double b) => a + _r.nextDouble() * (b - a);
  T pick<T>(List<T> a) => a[_r.nextInt(a.length)];

  void clear() {
    parts.clear();
    pops.clear();
  }

  void pop(String text, double x, double y, Color col, double size) => pops.add(Pop(text, x, y, col, size));

  void sparks(double x, double y, double dir, Color col, int n, double speed) {
    for (var i = 0; i < n; i++) {
      final a = (dir > 0 ? 0 : math.pi) + rand(-1.3, 1.3), v = rand(speed * 0.35, speed);
      parts.add(Part(PartKind.streak, x, y, col, rand(0.25, 0.45),
          vx: math.cos(a) * v, vy: math.sin(a) * v - rand(60, 260), w: rand(2, 4)));
    }
  }

  void ring(double x, double y, Color col, {bool small = false}) => parts.add(small
      ? Part(PartKind.ring, x, y, col, 0.22, r0: 6, grow: 26, lw: 2.5)
      : Part(PartKind.ring, x, y, col, 0.42));

  void hitFx(double x, double y, double dir, String fx, Color ink, {int n = 12, double speed = 560}) {
    final base = dir > 0 ? 0.0 : math.pi;
    double ang(double spread) => base + rand(-spread, spread);
    switch (fx) {
      case 'lua':
        for (var i = 0; i < n + 4; i++) {
          final a = ang(1.4), v = rand(speed * 0.2, speed * 0.6);
          parts.add(Part(PartKind.ember, x, y, rgb(pick([0xFF9F1C, 0xFFBF69, 0xE4572E, 0xFFD23F])), rand(0.35, 0.7),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(60, 200), r: rand(2, 4.5)));
        }
      case 'set':
        for (var i = 0; i < 6; i++) {
          parts.add(Part(PartKind.bolt, x, y, rgb(0x3FB8F0), 0.24, a: ang(1.6), len: rand(22, 46), seed: rand(0, 99)));
        }
        parts.add(Part(PartKind.ring, x, y, rgb(0x9BE7FF), 0.25));
      case 'cau-vong':
        for (var i = 0; i < n + 4; i++) {
          final a = ang(1.3), v = rand(speed * 0.35, speed);
          parts.add(Part(PartKind.streak, x, y, hsl(rand(0, 360), 0.9, 0.55), rand(0.3, 0.5),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(60, 260), w: rand(2.5, 4.5)));
        }
      case 'hoa-dao':
        for (var i = 0; i < n; i++) {
          final a = ang(1.5), v = rand(80, speed * 0.5);
          parts.add(Part(PartKind.petal, x, y, rgb(pick([0xFF8FB1, 0xFFC2D4, 0xFFB3C8, 0xFF6F9C])), rand(0.8, 1.4),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(40, 160), rot: rand(0, 6), vr: rand(-8, 8)));
        }
      case 'phao-hoa':
        for (var j = 0; j < 3; j++) {
          final col = rgb(pick([0xFF595E, 0xFFCA3A, 0x8AC926, 0x1982C4, 0xC77DFF]));
          final ox = x + rand(-26, 26), oy = y + rand(-34, 10);
          for (var i = 0; i < 12; i++) {
            final a = i / 12 * math.pi * 2, v = rand(160, 260);
            parts.add(Part(PartKind.dot, ox, oy, col, rand(0.5, 0.75), vx: math.cos(a) * v, vy: math.sin(a) * v, r: 2.6));
          }
        }
      case 'bong-bong':
        for (var i = 0; i < n; i++) {
          final a = ang(1.4), v = rand(60, speed * 0.35);
          parts.add(Part(PartKind.bubble, x, y, rgb(0x6EC6F0), rand(0.8, 1.3),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(20, 90), r: rand(3, 7)));
        }
      case 'trai-tim':
        for (var i = 0; i < 9; i++) {
          final a = ang(1.3), v = rand(70, speed * 0.4);
          parts.add(Part(PartKind.heart, x, y, rgb(pick([0xFF4F7B, 0xFF8FB1, 0xE91E63])), rand(0.7, 1.1),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(40, 120), r: rand(2.6, 4.2)));
        }
      case 'ngoi-sao':
        for (var i = 0; i < 9; i++) {
          final a = ang(1.4), v = rand(120, speed * 0.7);
          parts.add(Part(PartKind.star, x, y, rgb(pick([0xFFCA3A, 0xFFE14A, 0xFFF59D])), rand(0.5, 0.8),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(80, 220), r: rand(3, 5), rot: rand(0, 6), vr: rand(-10, 10)));
        }
      case 'tuyet':
        for (var i = 0; i < n; i++) {
          final a = ang(1.6), v = rand(50, speed * 0.3);
          parts.add(Part(PartKind.flake, x, y, rgb(pick([0xFFFFFF, 0xBDE6FA, 0x8FD3F5])), rand(0.9, 1.5),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(30, 100), r: rand(2.6, 4.2), rot: rand(0, 3), vr: rand(-3, 3)));
        }
      case 'giay-vun':
        for (var i = 0; i < n + 6; i++) {
          final a = ang(1.5), v = rand(120, speed * 0.75);
          parts.add(Part(PartKind.confetti, x, y, rgb(pick([0xFF595E, 0xFFCA3A, 0x8AC926, 0x1982C4, 0xC77DFF, 0xFF8FB1])),
              rand(0.6, 1.0),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(120, 300), rot: rand(0, 6), vr: rand(-14, 14)));
        }
      case 'la-phong':
        for (var i = 0; i < 9; i++) {
          final a = ang(1.5), v = rand(80, speed * 0.45);
          parts.add(Part(PartKind.leaf, x, y, rgb(pick([0xE4572E, 0xF28C28, 0xC0392B, 0xF5B041])), rand(0.9, 1.5),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(40, 140), r: rand(3.5, 5), rot: rand(0, 6), vr: rand(-6, 6)));
        }
      case 'not-nhac':
        for (var i = 0; i < 7; i++) {
          final a = ang(1.2), v = rand(60, speed * 0.3);
          parts.add(Part(PartKind.note, x, y, rgb(pick([0x6A3DB8, 0x1D3AA8, 0xC2185B])), rand(0.8, 1.2),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(40, 110), r: rand(2.6, 3.6)));
        }
      case 'muc-tau':
        for (var i = 0; i < n; i++) {
          final a = ang(1.3), v = rand(100, speed * 0.7);
          parts.add(Part(PartKind.blot, x, y, withAlpha(ink, 0.9), rand(0.45, 0.75),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(60, 200), r: rand(1.6, 5)));
        }
      case 'dien-tu':
        for (var i = 0; i < n + 4; i++) {
          final a = ang(1.6), v = rand(120, speed * 0.7);
          parts.add(Part(PartKind.pixel, x, y, rgb(pick([0x00E676, 0x00B8D4, 0xD500F9, 0xFFEA00])), rand(0.4, 0.7),
              vx: math.cos(a) * v, vy: math.sin(a) * v - rand(40, 160), r: rand(2.5, 4.5)));
        }
      case 'chu-bop':
        parts.add(Part(PartKind.word, x + dir * 10, y - 18, rgb(pick([0xFFCA3A, 0xFF595E, 0x1982C4])), 0.6,
            text: pick(['BỐP!', 'BỤP!', 'CHÁT!', 'BÙM!', 'HỰ!']), rot: rand(-0.25, 0.25)));
        sparks(x, y, dir, ink, 6, speed * 0.8);
      default:
        sparks(x, y, dir, ink, n, speed);
    }
  }

  /// Particles shed along the swing for some effects.
  void trailFx(String fx, double x, double y) {
    final p = _r.nextDouble();
    switch (fx) {
      case 'lua':
        if (p < 0.6) {
          parts.add(Part(PartKind.ember, x, y, rgb(pick([0xFF9F1C, 0xFFD23F, 0xE4572E])), rand(0.25, 0.45),
              vx: rand(-40, 40), vy: rand(-80, -20), r: rand(2, 3.5)));
        }
      case 'hoa-dao':
        if (p < 0.35) {
          parts.add(Part(PartKind.petal, x, y, rgb(pick([0xFF8FB1, 0xFFC2D4])), rand(0.6, 1.0),
              vx: rand(-30, 30), vy: rand(-40, 0), rot: rand(0, 6), vr: rand(-6, 6)));
        }
      case 'bong-bong':
        if (p < 0.3) parts.add(Part(PartKind.bubble, x, y, rgb(0x6EC6F0), rand(0.5, 0.8), vx: rand(-20, 20), vy: rand(-50, -10), r: rand(2, 4)));
      case 'ngoi-sao':
        if (p < 0.3) {
          parts.add(Part(PartKind.star, x, y, rgb(0xFFCA3A), rand(0.3, 0.5), vx: rand(-30, 30), vy: rand(-30, 30), r: 2.4, vr: rand(-8, 8)));
        }
      case 'tuyet':
        if (p < 0.35) parts.add(Part(PartKind.flake, x, y, rgb(0xFFFFFF), rand(0.6, 1.0), vx: rand(-20, 20), vy: rand(0, 30), r: 2.6, vr: 2));
      case 'giay-vun':
        if (p < 0.4) {
          parts.add(Part(PartKind.confetti, x, y, rgb(pick([0xFF595E, 0xFFCA3A, 0x8AC926, 0x1982C4])), rand(0.4, 0.7),
              vx: rand(-40, 40), vy: rand(-60, 0), rot: rand(0, 6), vr: rand(-10, 10)));
        }
      case 'dien-tu':
        if (p < 0.4) parts.add(Part(PartKind.pixel, x, y, rgb(pick([0x00E676, 0x00B8D4])), rand(0.25, 0.4), r: 3));
      case 'not-nhac':
        if (p < 0.15) parts.add(Part(PartKind.note, x, y, rgb(0x6A3DB8), rand(0.6, 0.9), vx: rand(-20, 20), vy: -40, r: 2.6));
      case 'la-phong':
        if (p < 0.25) {
          parts.add(Part(PartKind.leaf, x, y, rgb(pick([0xE4572E, 0xF28C28])), rand(0.6, 1.0),
              vx: rand(-30, 30), vy: rand(-30, 10), r: 3.4, rot: rand(0, 6), vr: rand(-5, 5)));
        }
    }
  }

  void update(double dt) {
    double damp(double k) => math.pow(k, dt).toDouble();
    for (final p in parts) {
      p.life -= dt;
      switch (p.kind) {
        case PartKind.ring:
        case PartKind.bolt:
          continue;
        case PartKind.ember:
          p.vx *= damp(0.2);
          p.vy = p.vy * damp(0.3) - 260 * dt;
        case PartKind.petal:
        case PartKind.leaf:
          p.vx *= damp(0.4);
          p.vy = p.vy * damp(0.5) + 160 * dt;
          p.rot += p.vr * dt;
          p.x += math.sin(p.life * 6) * 20 * dt;
        case PartKind.dot:
          p.vx *= damp(0.15);
          p.vy = p.vy * damp(0.15) + 120 * dt;
        case PartKind.bubble:
          p.vx *= damp(0.3);
          p.vy = p.vy * damp(0.4) - 40 * dt;
          p.x += math.sin(p.life * 8) * 10 * dt;
        case PartKind.heart:
        case PartKind.note:
          p.vx *= damp(0.4);
          p.vy = p.vy * damp(0.5) - 55 * dt;
          p.x += math.sin(p.life * 7) * 12 * dt;
        case PartKind.star:
          p.vx *= damp(0.5);
          p.vy += 600 * dt;
          p.rot += p.vr * dt;
        case PartKind.flake:
          p.vx *= damp(0.5);
          p.vy = p.vy * damp(0.5) + 50 * dt;
          p.x += math.sin(p.life * 5) * 15 * dt;
          p.rot += p.vr * dt;
        case PartKind.confetti:
          p.vx *= damp(0.6);
          p.vy = p.vy * damp(0.7) + 380 * dt;
          p.rot += p.vr * dt;
        case PartKind.word:
          p.y -= 30 * dt;
        case PartKind.blot:
          p.vx *= damp(0.5);
          p.vy += 900 * dt;
        case PartKind.pixel:
          p.vx *= damp(0.25);
          p.vy = p.vy * damp(0.25) + 200 * dt;
        case PartKind.streak:
          p.vy += 1400 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
    parts.removeWhere((p) => p.life <= 0);
    for (final p in pops) {
      p.life -= dt;
      p.y -= 50 * dt;
    }
    pops.removeWhere((p) => p.life <= 0);
  }

  void draw(Canvas c) {
    for (final p in parts) {
      final a = clampD(p.life / p.max, 0, 1);
      final col = withAlpha(p.col, a);
      switch (p.kind) {
        case PartKind.ring:
          strokePath(c, Path()..addOval(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.r0 + (1 - a) * p.grow)), col, p.lw);
        case PartKind.ember:
          dot(c, p.x, p.y, p.r * (0.5 + a * 0.5), col);
        case PartKind.dot:
        case PartKind.blot:
          dot(c, p.x, p.y, p.r, col);
        case PartKind.petal:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 5.2)), col);
          c.restore();
        case PartKind.bolt:
          final ca = math.cos(p.a), sa = math.sin(p.a);
          final path = Path()..moveTo(p.x, p.y);
          for (var i = 1; i <= 4; i++) {
            final d = p.len * i / 4, jg = i < 4 ? math.sin(p.seed + i * 2.3) * 7 : 0.0;
            path.lineTo(p.x + ca * d - sa * jg, p.y + sa * d + ca * jg);
          }
          strokePath(c, path, col, 3);
          strokePath(c, path, withAlpha(const Color(0xFFFFFFFF), a), 1.2);
        case PartKind.bubble:
          fillPath(c, Path()..addOval(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.r)), withAlpha(p.col, a * 0.18));
          strokePath(c, Path()..addOval(Rect.fromCircle(center: Offset(p.x, p.y), radius: p.r)), col, 1.3);
          dot(c, p.x - p.r * 0.35, p.y - p.r * 0.35, p.r * 0.22, withAlpha(const Color(0xFFFFFFFF), a));
        case PartKind.heart:
          fillPath(c, _heart(p.x, p.y, p.r), col);
        case PartKind.star:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          fillPath(c, _starPath(p.r, p.r * 0.45, 5), col);
          c.restore();
        case PartKind.flake:
          for (var k = 0; k < 3; k++) {
            final ang = p.rot + k * math.pi / 3;
            line(c, p.x - math.cos(ang) * p.r, p.y - math.sin(ang) * p.r, p.x + math.cos(ang) * p.r, p.y + math.sin(ang) * p.r,
                col, 1.2);
          }
        case PartKind.confetti:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          fillPath(c, Path()..addRect(const Rect.fromLTWH(-2.5, -1.2, 5, 2.4)), col);
          c.restore();
        case PartKind.word:
          final grow = 1 + (1 - a) * 0.35;
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          c.scale(grow);
          drawText(c, p.text, 0, 0, 22, p.col, family: Fonts.display, outline: 5, outlineColor: const Color(0xFF1D1F27), alpha: a);
          c.restore();
        case PartKind.leaf:
          c.save();
          c.translate(p.x, p.y);
          c.rotate(p.rot);
          fillPath(c, _starPath(p.r, p.r * 0.5, 5), col);
          c.restore();
        case PartKind.note:
          fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset(p.x, p.y), width: p.r * 2.2, height: p.r * 1.6)), col);
          line(c, p.x + p.r, p.y, p.x + p.r, p.y - p.r * 3.4, col, 1.3);
          line(c, p.x + p.r, p.y - p.r * 3.4, p.x + p.r * 2.2, p.y - p.r * 2.6, col, 1.3);
        case PartKind.pixel:
          fillRect(c, p.x - p.r / 2, p.y - p.r / 2, p.r, p.r, col);
        case PartKind.streak:
          line(c, p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03, col, p.w);
      }
    }
  }
}

Path _heart(double x, double y, double s) => Path()
  ..moveTo(x, y + s * 0.9)
  ..cubicTo(x - s * 1.6, y - s * 0.2, x - s * 0.7, y - s * 1.5, x, y - s * 0.5)
  ..cubicTo(x + s * 0.7, y - s * 1.5, x + s * 1.6, y - s * 0.2, x, y + s * 0.9)
  ..close();

Path _starPath(double outer, double inner, int n) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / n, r = i.isEven ? outer : inner;
    if (i == 0) {
      p.moveTo(math.cos(a) * r, math.sin(a) * r);
    } else {
      p.lineTo(math.cos(a) * r, math.sin(a) * r);
    }
  }
  return p..close();
}

/// Swing trail behind the weapon tip, styled per hit effect.
void drawTrail(Canvas c, String fx, Color ink, List<P> trail, double fade, double animT) {
  if (trail.length < 2 || fade <= 0) return;
  final n = trail.length;
  final rnd = math.Random(n);
  for (var i = 1; i < n; i++) {
    final u = i / n, a = trail[i - 1], b = trail[i];
    Color col;
    var w = 3 + 10 * u;
    switch (fx) {
      case 'lua':
        col = hsl(18 + 32 * u, 1, 0.48 + 0.1 * u, 0.55 * fade * u);
        w = 4 + 14 * u;
      case 'set':
        col = Color.fromRGBO(63, 184, 240, 0.75 * fade * u);
        w = 2 + 5 * u;
      case 'cau-vong':
        col = hsl((i * 40 + animT * 300) % 360, 0.9, 0.55, 0.5 * fade * u);
        w = 4 + 10 * u;
      case 'hoa-dao':
      case 'trai-tim':
        col = Color.fromRGBO(255, 111, 156, 0.45 * fade * u);
        w = 3 + 8 * u;
      case 'phao-hoa':
      case 'ngoi-sao':
      case 'chu-bop':
        col = Color.fromRGBO(255, 190, 30, 0.6 * fade * u);
        w = 2 + 6 * u;
      case 'bong-bong':
      case 'tuyet':
        col = Color.fromRGBO(110, 198, 240, 0.5 * fade * u);
        w = 3 + 9 * u;
      case 'giay-vun':
        col = hsl((i * 55) % 360, 0.85, 0.6, 0.45 * fade * u);
      case 'la-phong':
        col = Color.fromRGBO(242, 140, 40, 0.5 * fade * u);
      case 'not-nhac':
        col = Color.fromRGBO(106, 61, 184, 0.45 * fade * u);
      case 'dien-tu':
        col = Color.fromRGBO(0, 230, 118, 0.55 * fade * u);
        w = 3 + 6 * u;
      case 'muc-tau':
        col = withAlpha(ink, 0.5 * fade * u);
        w = 4 + 12 * u;
      default:
        col = withAlpha(ink, 0.3 * fade * u);
    }
    if (fx == 'set' || fx == 'dien-tu') {
      final mx = (a.x + b.x) / 2 + (rnd.nextDouble() - 0.5) * 12, my = (a.y + b.y) / 2 + (rnd.nextDouble() - 0.5) * 12;
      strokePath(
          c,
          Path()
            ..moveTo(a.x, a.y)
            ..lineTo(mx, my)
            ..lineTo(b.x, b.y),
          col,
          w);
    } else {
      line(c, a.x, a.y, b.x, b.y, col, w);
    }
  }
}

/// Grey of shield-block sparks.
const Color sparkGrey = Color(0xFF9AA0AD);

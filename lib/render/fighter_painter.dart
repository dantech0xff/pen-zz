import 'dart:math' as math;
import 'dart:ui';

import '../core/battle/fighter.dart';
import '../core/battle/poses.dart';
import '../core/mathx.dart';
import '../core/rig.dart';
import '../core/strokes.dart';
import 'ink_painter.dart';
import 'palette.dart';
import 'text_fx.dart';

final Paint _f = Paint()..isAntiAlias = true;
final Paint _s = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void _fillP(Canvas c, Path p, Color col) {
  _f
    ..style = PaintingStyle.fill
    ..shader = null
    ..color = col;
  c.drawPath(p, _f);
}

void _strokeP(Canvas c, Path p, Color col, double w) {
  _s
    ..color = col
    ..strokeWidth = w;
  c.drawPath(p, _s);
}

void _fs(Canvas c, Path p, Color fill, Color stroke, double w) {
  _fillP(c, p, fill);
  _strokeP(c, p, stroke, w);
}

Path _circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
Path _ellipse(double x, double y, double rx, double ry) =>
    Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: rx * 2, height: ry * 2));
Path _arc(double x, double y, double r, double a0, double a1) {
  var sweep = a1 - a0;
  if (sweep < 0) sweep += math.pi * 2;
  return Path()..addArc(Rect.fromCircle(center: Offset(x, y), radius: r), a0, sweep);
}

Path _poly(List<double> xy) {
  final p = Path()..moveTo(xy[0], xy[1]);
  for (var i = 2; i < xy.length; i += 2) {
    p.lineTo(xy[i], xy[i + 1]);
  }
  return p..close();
}

/// Upper half dome from angle pi to 2pi, closed (caps and helmets).
Path _dome(double cx, double cy, double r) => Path()
  ..moveTo(cx - r, cy)
  ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi, false)
  ..close();

Path _star(double x, double y, double outer, double inner, int n) {
  final p = Path();
  for (var i = 0; i < n * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / n, r = i.isEven ? outer : inner;
    final px = x + math.cos(a) * r, py = y + math.sin(a) * r;
    if (i == 0) {
      p.moveTo(px, py);
    } else {
      p.lineTo(px, py);
    }
  }
  return p..close();
}

Path heartPath(double x, double y, double s) => Path()
  ..moveTo(x, y + s * 0.9)
  ..cubicTo(x - s * 1.6, y - s * 0.2, x - s * 0.7, y - s * 1.5, x, y - s * 0.5)
  ..cubicTo(x + s * 0.7, y - s * 1.5, x + s * 1.6, y - s * 0.2, x, y + s * 0.9)
  ..close();

// ---------------- face ----------------

const _seeThrough = {'khong-kinh', 'kinh-can', 'kinh-tron-vang', 'mat-na', 'bit-mat'};

/// Face inside the head frame: x towards the facing side, y down.
void drawFace(Canvas c, Mood mood, Color ink, String glass) {
  final hide = !_seeThrough.contains(glass);
  switch (mood) {
    case Mood.hurt:
      if (!hide) {
        line(c, 3, -4, 6.5, -0.5, ink, 1.8);
        line(c, 6.5, -4, 3, -0.5, ink, 1.8);
        line(c, 8, -4, 11, -0.5, ink, 1.8);
        line(c, 11, -4, 8, -0.5, ink, 1.8);
      }
      line(c, 5, 5, 9, 4, ink, 1.8);
    case Mood.dizzy:
      if (!hide) {
        _strokeP(c, _arc(4.8, -1.8, 2.3, 0, 5), ink, 1.3);
        _strokeP(c, _arc(9.8, -1.8, 2.3, 0, 5), ink, 1.3);
      }
      _strokeP(
          c,
          Path()
            ..moveTo(4, 5)
            ..quadraticBezierTo(6, 3, 7.5, 5)
            ..quadraticBezierTo(9, 7, 10.5, 5),
          ink,
          1.6);
    case Mood.happy:
      if (!hide) {
        _strokeP(c, _arc(5, -1.5, 1.8, math.pi, 0), ink, 1.8);
        _strokeP(c, _arc(9.6, -1.5, 1.8, math.pi, 0), ink, 1.8);
      }
      _strokeP(c, _arc(7, 2.6, 3.2, 0.2, math.pi - 0.2), ink, 1.8);
    case Mood.sleep:
      if (!hide) {
        _strokeP(c, _arc(5, -2.2, 1.8, 0, math.pi), ink, 1.6);
        _strokeP(c, _arc(9.6, -2.2, 1.8, 0, math.pi), ink, 1.6);
      }
      _strokeP(c, _circle(7.5, 4, 1.3), ink, 1.3);
    case Mood.calm:
    case Mood.fierce:
      if (!hide) {
        dot(c, 5, -1.5, 1.7, ink);
        dot(c, 9.6, -1.5, 1.7, ink);
      }
      if (mood == Mood.fierce) {
        line(c, 2.5, -6.8, 7, -4.8, ink, 1.8);
        line(c, 7.8, -4.8, 12, -6.4, ink, 1.8);
        line(c, 5, 5, 9.5, 4.5, ink, 1.8);
      } else {
        _strokeP(c, _arc(7.5, 3, 2.5, 0.3, math.pi - 0.3), ink, 1.8);
      }
  }
}

void drawGlasses(Canvas c, String id) {
  switch (id) {
    case 'kinh-can':
      const col = Color(0xFF2A2D38);
      _strokeP(c, _circle(5, -1.5, 3), col, 1.3);
      _strokeP(c, _circle(10.4, -1.5, 3), col, 1.3);
      line(c, 7.9, -1.8, 7.5, -1.8, col, 1.3);
      line(c, 2, -1.8, -6, -3, col, 1.3);
    case 'kinh-ram':
      const col = Color(0xFF1C1F2A);
      _fillP(c, Path()..addRRect(RRect.fromLTRBR(1.4, -4.4, 7, 0.4, const Radius.circular(1.8))), col);
      _fillP(c, Path()..addRRect(RRect.fromLTRBR(8, -4.4, 13.6, 0.2, const Radius.circular(1.8))), col);
      line(c, 6.8, -3.6, 8.2, -3.6, col, 1.4);
      line(c, 1.6, -3.2, -6, -3.6, col, 1.4);
      line(c, 2.6, -3.2, 4.4, -3.2, const Color(0xB3FFFFFF), 1);
      line(c, 9.2, -3.2, 11, -3.2, const Color(0xB3FFFFFF), 1);
    case 'kinh-tim':
      _fs(c, heartPath(4.6, -1.4, 2.9), const Color(0xFFFF4F7B), const Color(0xFFA3123A), 1.1);
      _fs(c, heartPath(10.4, -1.4, 2.9), const Color(0xFFFF4F7B), const Color(0xFFA3123A), 1.1);
      line(c, 7.2, -2.2, 7.8, -2.2, const Color(0xFFA3123A), 1.1);
      line(c, 1.8, -2.4, -6, -3, const Color(0xFFA3123A), 1.1);
    case 'kinh-boi':
      const col = Color(0xFF155A8A);
      _strokeP(c, _arc(0, -1.8, 11.4, 0.2 + math.pi * 0.55, math.pi * 1.05), col, 1.6);
      _fs(c, _ellipse(4.8, -1.6, 3.1, 2.5), const Color(0xCC50B4EB), col, 1.3);
      _fs(c, _ellipse(10.4, -1.6, 3, 2.5), const Color(0xCC50B4EB), col, 1.3);
      dot(c, 3.8, -2.6, 0.8, const Color(0xCCFFFFFF));
      dot(c, 9.4, -2.6, 0.8, const Color(0xCCFFFFFF));
    case 'kinh-pixel':
      const q = 1.5;
      void px(double x, double y, double w, double h, Color col) => fillRect(c, x, y, w * q, h * q, col);
      const k = Color(0xFF111111), wh = Color(0xFFFFFFFF);
      px(-6, -5.2, 13.4, 1, k);
      px(1, -3.7, 4, 1, k);
      px(8.2, -3.7, 4, 1, k);
      px(1.75, -2.2, 3, 1, k);
      px(8.95, -2.2, 3, 1, k);
      px(2.5, -0.7, 2, 1, k);
      px(9.7, -0.7, 2, 1, k);
      px(2.5, -3.7, 1, 1, wh);
      px(9.7, -3.7, 1, 1, wh);
    case 'kinh-tron-vang':
      const col = Color(0xFFC99700);
      _strokeP(c, _circle(5, -1.5, 3.3), col, 1.2);
      _strokeP(c, _circle(10.4, -1.5, 3.3), col, 1.2);
      line(c, 8.3, -2.2, 7.1, -2.2, col, 1.1);
      line(c, 1.7, -1.8, -6, -3, col, 1.1);
    case 'bit-mat':
      const col = Color(0xFF1C1F2A);
      _fillP(c, _ellipse(9.8, -1.6, 3.4, 3), col);
      line(c, 6.6, -3.8, -10, -6.4, col, 1.2);
    case 'kinh-3d':
      _fs(c, Path()..addRect(const Rect.fromLTWH(1.2, -4.6, 12.8, 5.6)), const Color(0xFFFFFFFF), const Color(0xFF1C1F2A), 1.1);
      fillRect(c, 2, -3.9, 4.8, 4.2, const Color(0xBFE53935));
      fillRect(c, 8.4, -3.9, 4.8, 4.2, const Color(0xBF1E88E5));
      line(c, 1.2, -3, -6, -3.6, const Color(0xFF1C1F2A), 1.1);
    case 'kinh-sao':
      _fs(c, _star(5, -1.6, 3.6, 1.6, 5), const Color(0xFFFFCA3A), const Color(0xFF9A7400), 0.9);
      _fs(c, _star(10.4, -1.6, 3.6, 1.6, 5), const Color(0xFFFFCA3A), const Color(0xFF9A7400), 0.9);
      line(c, 1.6, -2, -6, -3, const Color(0xFF9A7400), 1);
    case 'mat-na':
      final mask = Path()
        ..fillType = PathFillType.evenOdd
        ..moveTo(0.5, -1.5)
        ..quadraticBezierTo(1.5, -6.5, 7.5, -4.2)
        ..quadraticBezierTo(13.5, -6.5, 14.5, -1.5)
        ..quadraticBezierTo(13, 2.2, 10, 1.2)
        ..quadraticBezierTo(7.5, 0.2, 5, 1.2)
        ..quadraticBezierTo(2, 2.2, 0.5, -1.5)
        ..close()
        ..addOval(Rect.fromCenter(center: const Offset(5, -1.6), width: 4.2, height: 3.2))
        ..addOval(Rect.fromCenter(center: const Offset(10, -1.6), width: 4.2, height: 3.2));
      _fs(c, mask, const Color(0xFF6A3DB8), const Color(0xFF2E1C63), 1);
      line(c, 0.5, -1.5, -7, -3, const Color(0xFF2E1C63), 1.2);
      dot(c, 13.6, -4.6, 0.9, Pal.gold);
  }
}

void drawHat(Canvas c, String id, Color ink, double animT) {
  switch (id) {
    case 'non-la':
      _fs(
          c,
          Path()
            ..moveTo(-22, -6)
            ..lineTo(1, -29)
            ..lineTo(24, -6)
            ..quadraticBezierTo(1, -1, -22, -6)
            ..close(),
          const Color(0xFFEAD39A),
          const Color(0xFF8A6D2F),
          1.6);
      line(c, -11, -13, 13, -13, const Color(0x998A6D2F), 1);
      line(c, -4, -20, 6, -20, const Color(0x998A6D2F), 1);
    case 'luoi-trai':
      _fs(c, _dome(0, -3, 11.6), const Color(0xFFF2B632), const Color(0xFF8F6400), 1.5);
      _fs(
          c,
          Path()
            ..moveTo(7, -4.5)
            ..quadraticBezierTo(16, -6.5, 22, -3)
            ..quadraticBezierTo(15, -1.5, 7, -2)
            ..close(),
          const Color(0xFFF2B632),
          const Color(0xFF8F6400),
          1.5);
      dot(c, 0, -14.4, 1.6, const Color(0xFF8F6400));
    case 'bao-hiem':
      _fs(c, _dome(0, -1, 13.2), const Color(0xFFFF8A3D), const Color(0xFF9A3D0A), 1.6);
      _fillP(
          c,
          Path()
            ..moveTo(-3, -14)
            ..quadraticBezierTo(1, -14.6, 3, -14)
            ..lineTo(3.4, -1.2)
            ..lineTo(-3.4, -1.2)
            ..close(),
          const Color(0xD9FFFFFF));
      _fs(
          c,
          Path()
            ..moveTo(11, -2)
            ..quadraticBezierTo(17, -2.4, 18, 0.2)
            ..lineTo(11, 0.2)
            ..close(),
          const Color(0xFFFF8A3D),
          const Color(0xFF9A3D0A),
          1.6);
      line(c, -4, 0, 1, 11, const Color(0xFF4A3A30), 1.1);
    case 'tai-meo':
      _fillP(c, _poly([-9.5, -6.5, -7, -19, -1, -10.4]), ink);
      _fillP(c, _poly([1.6, -10.6, 8, -18.5, 9.6, -6.4]), ink);
      _fillP(c, _poly([-7.6, -9, -6.6, -15.2, -3.4, -10.6]), const Color(0xFFFF9BB5));
      _fillP(c, _poly([3.8, -10.6, 7.4, -15, 7.9, -8.6]), const Color(0xFFFF9BB5));
    case 'phu-thuy':
      c.save();
      c.translate(1, -8.5);
      c.rotate(-0.06);
      _fs(c, _ellipse(0, 0, 19, 3.6), const Color(0xFF5B3AA8), const Color(0xFF2E1C63), 1.5);
      c.restore();
      _fs(
          c,
          Path()
            ..moveTo(-9, -9.5)
            ..quadraticBezierTo(-4, -26, -14, -40)
            ..quadraticBezierTo(3, -30, 11, -10)
            ..close(),
          const Color(0xFF5B3AA8),
          const Color(0xFF2E1C63),
          1.5);
      fillRect(c, -8.6, -14.6, 18.6, 3.2, const Color(0xFFE7B82C));
      _fillP(c, _star(-1.5, -22, 3.2, 1.4, 5), Pal.hl);
    case 'vuong-mien':
      _fs(c, _poly([-10, -10, -10, -20, -5, -14.5, 0, -23, 5, -14.5, 10, -20, 10, -10]), Pal.hl, const Color(0xFF9A7400), 1.5);
      dot(c, 0, -13.6, 1.6, Pal.red);
      dot(c, -6, -12.8, 1.2, const Color(0xFF2F9E6B));
      dot(c, 6, -12.8, 1.2, const Color(0xFF2F9E6B));
    case 'mu-len':
      _fs(c, _dome(0, -2, 12.4), const Color(0xFFD3303C), const Color(0xFF8F1D26), 1.4);
      _fs(c, Path()..addRRect(RRect.fromLTRBR(-13, -4.5, 13, -0.5, const Radius.circular(1.5))), Pal.body,
          const Color(0xFF8F1D26), 1.2);
      _fs(c, _circle(0, -15.6, 3.4), Pal.body, const Color(0xFF8F1D26), 1.2);
    case 'bang-do':
      const red = Color(0xFFD3303C);
      fillRect(c, -11.4, -7.6, 22.8, 4.2, red);
      final wave = math.sin(animT * 6) * 1.5;
      _strokeP(
          c,
          Path()
            ..moveTo(-11, -6)
            ..quadraticBezierTo(-17, -8 + wave, -21, -3 + wave),
          red,
          2.2);
      _strokeP(
          c,
          Path()
            ..moveTo(-11, -4.5)
            ..quadraticBezierTo(-16, -1 - wave, -19, 3 - wave),
          red,
          2.2);
      dot(c, -11, -5.6, 1.8, const Color(0xFF8F1D26));
    case 'non-coi':
      _fs(c, _dome(0, -3, 13.6), const Color(0xFF7D8A4E), const Color(0xFF3F4724), 1.5);
      _fs(c, _ellipse(0, -2.6, 18, 3.2), const Color(0xFF7D8A4E), const Color(0xFF3F4724), 1.5);
      line(c, -12.5, -6, 12.5, -6, const Color(0xFF3F4724), 1);
      _fillP(c, _star(0, -10, 2.4, 1, 5), const Color(0xFFE2B12A));
    case 'tot-nghiep':
      _fillP(
          c,
          Path()
            ..moveTo(-10, -5)
            ..lineTo(-9, -12)
            ..lineTo(9, -12)
            ..lineTo(10, -5)
            ..quadraticBezierTo(0, -3, -10, -5)
            ..close(),
          const Color(0xFF23252F));
      _fs(c, _poly([-17, -14, 3, -20, 20, -14, 0, -8.6]), const Color(0xFF2B2D3A), const Color(0xFF11121A), 1.2);
      _strokeP(
          c,
          Path()
            ..moveTo(1.5, -14.2)
            ..lineTo(14, -11)
            ..lineTo(14.5, -3),
          const Color(0xFFE7B82C),
          1.2);
      dot(c, 1.5, -14.2, 1.2, const Color(0xFFE7B82C));
      fillRect(c, 13.2, -4.5, 2.6, 3.5, const Color(0xFFE7B82C));
    case 'cao-boi':
      const fill = Color(0xFFA0652A), edge = Color(0xFF5A3510);
      _fs(
          c,
          Path()
            ..moveTo(-8, -8)
            ..lineTo(-7.4, -18)
            ..quadraticBezierTo(0, -21.5, 7.4, -18)
            ..lineTo(8, -8)
            ..close(),
          fill,
          edge,
          1.4);
      fillRect(c, -8, -10, 16, 2, edge);
      _fs(
          c,
          Path()
            ..moveTo(-21, -11)
            ..quadraticBezierTo(-14, -5, 0, -6)
            ..quadraticBezierTo(14, -5, 21, -11)
            ..quadraticBezierTo(18, -6, 0, -3)
            ..quadraticBezierTo(-18, -6, -21, -11)
            ..close(),
          fill,
          edge,
          1.4);
    case 'cuop-bien':
      _fillP(
          c,
          Path()
            ..moveTo(-17, -6)
            ..quadraticBezierTo(-12, -25, 0, -21)
            ..quadraticBezierTo(12, -25, 17, -6)
            ..quadraticBezierTo(0, -10, -17, -6)
            ..close(),
          const Color(0xFF1D1F27));
      line(c, -3.2, -17.5, 3.2, -11, const Color(0xFFFFFFFF), 1.1);
      line(c, 3.2, -17.5, -3.2, -11, const Color(0xFFFFFFFF), 1.1);
      dot(c, 0, -14.6, 2.6, const Color(0xFFFFFFFF));
      dot(c, -0.9, -14.9, 0.5, const Color(0xFF1D1F27));
      dot(c, 0.9, -14.9, 0.5, const Color(0xFF1D1F27));
    case 'sung-quy':
      const fill = Color(0xFFD3303C), edge = Color(0xFF8F1D26);
      _fs(
          c,
          Path()
            ..moveTo(-8, -8.6)
            ..quadraticBezierTo(-13, -15, -8.5, -22)
            ..quadraticBezierTo(-8, -15.5, -3, -10.4)
            ..close(),
          fill,
          edge,
          1);
      _fs(
          c,
          Path()
            ..moveTo(3, -10.6)
            ..quadraticBezierTo(8, -15.5, 8.5, -22.5)
            ..quadraticBezierTo(12.5, -15, 7.6, -8.2)
            ..close(),
          fill,
          edge,
          1);
    case 'hao-quang':
      final y = -21 + math.sin(animT * 3) * 1;
      _strokeP(c, _ellipse(0, y, 11, 3), const Color(0x59FFE14A), 5);
      _strokeP(c, _ellipse(0, y, 11, 3), const Color(0xFFE2B12A), 2.2);
    case 'tai-tho':
      for (final side in [-1.0, 1.0]) {
        c.save();
        c.translate(side * 5, -18 - (side > 0 ? 0.5 : 0));
        c.rotate(side * 0.18 + math.sin(animT * 2 + side) * 0.04);
        _fs(c, _ellipse(0, 0, 3.8, 10), const Color(0xFFFFFFFF), const Color(0xFF8A8F99), 1.2);
        _fillP(c, _ellipse(0, 1, 1.8, 7), const Color(0xFFFF9BB5));
        c.restore();
      }
    case 'vong-hoa':
      const petals = [0xFFFF8FB1, 0xFFFFD23F, 0xFFFFFDF7, 0xFFFF8FB1, 0xFFC77DFF];
      for (var a = 200.0; a <= 340; a += 28) {
        final r = a * deg;
        _fillP(c, _ellipse(math.cos(r) * 12, math.sin(r) * 12, 2.4, 1.3), const Color(0xFF2F9E44));
      }
      var i = 0;
      for (final a in [205.0, 235.0, 265.0, 295.0, 325.0]) {
        final r = a * deg, cx = math.cos(r) * 11.4, cy = math.sin(r) * 11.4 - 0.5;
        for (var k = 0; k < 5; k++) {
          final pa = k * math.pi * 2 / 5;
          dot(c, cx + math.cos(pa) * 1.8, cy + math.sin(pa) * 1.8, 1.5, Color(petals[i % petals.length]));
        }
        dot(c, cx, cy, 1, const Color(0xFFFFCA3A));
        i++;
      }
  }
}

// ---------------- back layer: capes, wings, backpack ----------------

class _Cape {
  const _Cape(this.col, this.dark, this.len, this.flare,
      {this.knot = false, this.collar = false, this.stars = false, this.trim = false, this.pattern = ''});
  final int col, dark;
  final double len, flare;
  final bool knot, collar, stars, trim;
  final String pattern;
}

const Map<String, _Cape> _capes = {
  'khan-do': _Cape(0xD3303C, 0x8F1D26, 30, 12, knot: true),
  'phi-phong-do': _Cape(0xD3303C, 0x8F1D26, 58, 18),
  'ao-choang-den': _Cape(0x2B2D3A, 0x0F1017, 62, 20, collar: true),
  'ao-choang-sao': _Cape(0x5B3AA8, 0x2E1C63, 60, 19, stars: true),
  'phi-phong-vang': _Cape(0xE2B12A, 0x8A6A00, 60, 21, trim: true),
  'khan-ran': _Cape(0x2F3A56, 0x151B2B, 28, 11, knot: true, pattern: 'check'),
  'ao-choang-la': _Cape(0x2F9E44, 0x1B5E20, 56, 18, pattern: 'leaf'),
  'ao-choang-bang': _Cape(0x7CC6F0, 0x2A7FB0, 58, 19, pattern: 'snow'),
  'ao-choang-lua': _Cape(0xE8541C, 0x9A2A0A, 58, 20, trim: true, pattern: 'flame'),
};

bool _moving(Fighter f) =>
    f.walking || f.state == FState.strike || f.state == FState.hitstun || f.state == FState.fall || f.state == FState.windup;

void _drawCape(Canvas c, _Cape sp, Rig j, Fighter f, double animT) {
  final moving = _moving(f);
  final t = animT * (moving ? 10 : 4) + (f.f < 0 ? 2 : 0);
  final wv = math.sin(t) * (moving ? 5 : 2.5), wv2 = math.sin(t * 1.3 + 1) * (moving ? 3.5 : 1.8);
  final n = j.neck, fwx = math.cos(j.lean), fwy = math.sin(j.lean);
  final a1 = P(n.x + fwx * 3, n.y + fwy * 3 + 1.5), a2 = P(n.x - fwx * 4.5, n.y - fwy * 4.5 + 1);
  final yb = math.min(n.y + sp.len, -5.0), fl = sp.flare + (moving ? 5 : 0);
  final b1 = P(n.x - 3 + wv * 0.3, yb), b2 = P(n.x - fl - 4 + wv, yb - 6 + wv2);
  final path = Path()
    ..moveTo(a1.x, a1.y)
    ..quadraticBezierTo(n.x + 1, (n.y + yb) / 2, b1.x, b1.y)
    ..quadraticBezierTo((b1.x + b2.x) / 2 + wv2, (b1.y + b2.y) / 2 + 4, b2.x, b2.y)
    ..quadraticBezierTo(n.x - fl * 0.55, (n.y + yb) / 2 - 4, a2.x, a2.y)
    ..close();
  _fillP(c, path, rgb(sp.col));
  if (sp.stars || sp.trim || sp.pattern.isNotEmpty) {
    c.save();
    c.clipPath(path);
    for (final uv in const [
      [0.35, 0.3],
      [0.7, 0.55],
      [0.45, 0.8],
      [0.2, 0.62],
    ]) {
      final u = uv[0], v = uv[1];
      final x = a2.x + (b2.x - a2.x) * v * 0.9 + (b1.x - a2.x) * u * 0.5, y = n.y + (yb - n.y) * v;
      if (sp.stars) {
        _fillP(c, _star(x, y, 2.6, 0.9, 4), Pal.hl);
      } else if (sp.pattern == 'leaf') {
        _fillP(c, _ellipse(x, y, 3.2, 1.6), const Color(0xFF7BD389));
      } else if (sp.pattern == 'snow') {
        for (var k = 0; k < 3; k++) {
          final a = k * math.pi / 3;
          line(c, x - math.cos(a) * 2.6, y - math.sin(a) * 2.6, x + math.cos(a) * 2.6, y + math.sin(a) * 2.6,
              const Color(0xFFFFFFFF), 1);
        }
      } else if (sp.pattern == 'check') {
        fillRect(c, x - 2, y - 2, 4, 4, const Color(0xCCFFFFFF));
      }
    }
    if (sp.trim) {
      final trim = sp.pattern == 'flame' ? const Color(0xFFFFC23D) : const Color(0xD9FFF6BE);
      _strokeP(
          c,
          Path()
            ..moveTo(b1.x, b1.y - 3)
            ..quadraticBezierTo((b1.x + b2.x) / 2 + wv2, (b1.y + b2.y) / 2 + 1, b2.x, b2.y - 3),
          trim,
          3);
    }
    c.restore();
  }
  _strokeP(c, path, rgb(sp.dark), 1.6);
  if (sp.collar) {
    final collar = Path()
      ..moveTo(a2.x + 1, a2.y)
      ..lineTo(n.x - fwx * 9 + fwy * 2, n.y - 10)
      ..lineTo(n.x + fwy * 3, n.y - 4)
      ..close();
    _fs(c, collar, rgb(sp.col), rgb(sp.dark), 1.6);
  }
  if (sp.knot) _fs(c, _circle(a1.x + 1, a1.y + 1, 2.6), rgb(sp.col), rgb(sp.dark), 1.2);
}

void _drawWings(Canvas c, Rig j, Fighter f, double animT, bool angel) {
  final moving = _moving(f);
  final flap = math.sin(animT * (moving ? 9 : 3)) * (moving ? 0.25 : 0.12);
  final fill = angel ? Pal.body : const Color(0xFF3A2D4A), edge = angel ? const Color(0xFF9AA0AD) : const Color(0xFF1B1324);
  Path wing() => angel
      ? (Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(-14, -22, -34, -26)
        ..quadraticBezierTo(-30, -18, -36, -14)
        ..quadraticBezierTo(-28, -10, -32, -4)
        ..quadraticBezierTo(-22, -4, -24, 2)
        ..quadraticBezierTo(-12, 0, 0, 0)
        ..close())
      : (Path()
        ..moveTo(0, 0)
        ..lineTo(-30, -24)
        ..quadraticBezierTo(-27, -15, -34, -10)
        ..quadraticBezierTo(-24, -10, -26, -3)
        ..quadraticBezierTo(-16, -5, -16, 2)
        ..quadraticBezierTo(-8, -2, 0, 0)
        ..close());
  for (final far in [true, false]) {
    c.save();
    c.translate(j.sh.x - 3 + (far ? 2 : 0), j.sh.y + 2 - (far ? 2 : 0));
    c.rotate(-0.35 + flap + (far ? 0.2 : 0));
    final p = wing();
    _fs(c, p, far ? withAlpha(fill, 0.7) : fill, edge, 1.4);
    if (!angel) {
      line(c, 0, 0, -26, -3, edge, 1);
      line(c, 0, 0, -16, 2, edge, 1);
    } else {
      line(c, -6, -4, -24, -14, withAlpha(edge, 0.6), 1);
    }
    c.restore();
  }
}

void _drawBackpack(Canvas c, Rig j) {
  final mx = (j.hip.x + j.neck.x) / 2, my = (j.hip.y + j.neck.y) / 2;
  final fwx = math.cos(j.lean), fwy = math.sin(j.lean);
  c.save();
  c.translate(mx - fwx * 9, my - fwy * 9 - 3);
  c.rotate(j.lean);
  _fs(c, Path()..addRRect(RRect.fromLTRBR(-7, -12, 6, 11, const Radius.circular(4))), const Color(0xFFE2B12A),
      const Color(0xFF8A6A00), 1.4);
  _fs(c, Path()..addRRect(RRect.fromLTRBR(-5, 2, 4, 9, const Radius.circular(2))), const Color(0xFFF2C94C),
      const Color(0xFF8A6A00), 1);
  c.restore();
  line(c, mx - fwx * 6, my - fwy * 6 - 12, j.sh.x, j.sh.y + 2, const Color(0xFF8A6A00), 1.6);
}

void _drawBack(Canvas c, String cape, Rig j, Fighter f, double animT) {
  final sp = _capes[cape];
  if (sp != null) {
    _drawCape(c, sp, j, f, animT);
  } else if (cape == 'canh-thien-than') {
    _drawWings(c, j, f, animT, true);
  } else if (cape == 'canh-doi') {
    _drawWings(c, j, f, animT, false);
  } else if (cape == 'balo') {
    _drawBackpack(c, j);
  }
}

// ---------------- props ----------------

/// Blue plastic street-tea stool.
void _drawChair(Canvas c, Rig j) {
  final y = j.hip.y + 4;
  _fs(c, Path()..addRRect(RRect.fromLTRBR(-15, y, 15, y + 5, const Radius.circular(2))), const Color(0xFF3C7BE0),
      const Color(0xFF1F4A96), 2);
  line(c, -12, y + 5, -14, 0, const Color(0xFF1F4A96), 2);
  line(c, 12, y + 5, 14, 0, const Color(0xFF1F4A96), 2);
}

/// Glass of iced tea.
void _drawTea(Canvas c, P h) {
  c.save();
  c.translate(h.x + 4, h.y - 4);
  _fillP(c, _poly([-5, -14, 5, -14, 4, 2, -4, 2]), const Color(0xD9D69634));
  fillRect(c, -3, -12, 3, 3, const Color(0xD9FFFFFF));
  fillRect(c, 0.5, -8, 3, 3, const Color(0xD9FFFFFF));
  _strokeP(c, _poly([-6, -17, 6, -17, 4.5, 2, -4.5, 2]), const Color(0xFF7A5A20), 1.4);
  c.restore();
}

void _drawPhone(Canvas c, P h, double animT) {
  c.save();
  c.translate(h.x, h.y);
  c.rotate(-0.2);
  _fs(c, Path()..addRRect(RRect.fromLTRBR(-3, -13, 4, 0, const Radius.circular(1.5))), const Color(0xFF252A37),
      const Color(0xFF111111), 1);
  fillRect(c, -2, -11.5, 5, 9, const Color(0xFF5A8DEE));
  if (animT % 1.2 < 0.12) {
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      line(c, -10 + math.cos(a) * 3, -8 + math.sin(a) * 3, -10 + math.cos(a) * 9, -8 + math.sin(a) * 9,
          const Color(0xFFFFF59D), 1.6);
    }
  }
  c.restore();
}

void _drawStatus(Canvas c, Fighter f, Rig j, double animT) {
  if (f.chilled) {
    for (var k = 0; k < 3; k++) {
      final x = j.hip.x + (k - 1) * 9, y = (j.hip.y + j.neck.y) / 2 + (k - 1) * 10;
      final rot = animT * 2 + k;
      for (var m = 0; m < 3; m++) {
        final a = rot + m * math.pi / 3;
        line(c, x - math.cos(a) * 3.2, y - math.sin(a) * 3.2, x + math.cos(a) * 3.2, y + math.sin(a) * 3.2,
            const Color(0xE67CC6F0), 1.2);
      }
    }
  }
  if (f.shockT > 0 && (animT * 20).floor().isEven) {
    for (final side in [-1.0, 1.0]) {
      final x = j.head.x + side * 15, y = j.head.y;
      _strokeP(
          c,
          Path()
            ..moveTo(x, y - 8)
            ..lineTo(x + side * 4, y - 3)
            ..lineTo(x - side * 1, y)
            ..lineTo(x + side * 4, y + 6),
          const Color(0xFFFFD23F),
          1.6);
    }
  }
  if (f.burnT > 0) {
    for (var k = 0; k < 3; k++) {
      final x = j.hip.x + (k - 1) * 8, y = j.hip.y + 6 - k * 14;
      final h = 6 + math.sin(animT * 18 + k * 2) * 2;
      _fillP(
          c,
          Path()
            ..moveTo(x - 3, y)
            ..quadraticBezierTo(x, y - h * 1.6, x + 3, y)
            ..close(),
          k.isEven ? const Color(0xCCFF9F1C) : const Color(0xCCE4572E));
    }
  }
}

// ---------------- the fighter ----------------

P _toe(P p) => P(p.x + 8, p.y);

final Expando<P> _farCache = Expando('far-point');

/// Farthest point from the grip; special inks run their gradient from the grip to it.
P farPoint(Strokes st) {
  final hit = _farCache[st];
  if (hit != null) return hit;
  var p = const P(0, -60);
  var best = 400.0;
  for (final s in st) {
    for (var i = 0; i + 1 < s.length; i += 2) {
      final d = s[i] * s[i] + s[i + 1] * s[i + 1];
      if (d > best) {
        best = d;
        p = P(s[i], s[i + 1]);
      }
    }
  }
  _farCache[st] = p;
  return p;
}

Shader? weaponShader(WeaponInk wi, Strokes st, double animT) {
  if (!wi.special) return null;
  final tip = farPoint(st);
  final List<Color> cols;
  if (wi.grad != null) {
    cols = [for (final g in wi.grad!) rgb(g)];
  } else {
    cols = [for (var i = 0; i <= 6; i++) hsl((animT * 90 + i * 52) % 360, 0.8, 0.46)];
  }
  final stops = [for (var i = 0; i < cols.length; i++) i / (cols.length - 1)];
  return Gradient.linear(const Offset(0, 8), Offset(tip.x, tip.y), cols, stops);
}

/// Colour for trails and hit sparks: the weapon ink (rainbow cycles).
Color fxColorOf(Look look, double animT) {
  final w = look.weaponInk;
  if (w.rainbow) return hsl((animT * 120) % 360, 0.8, 0.48);
  return rgb(w.color);
}

/// Draws a fighter facing right with feet at the origin.
void paintFighter(Canvas c, Fighter f, double animT, {bool editing = false}) {
  final look = f.look;
  final ink = rgb(look.body);
  final hop = f.hop;
  final p = f.pz ?? basePose(f, animT);
  final j = f.pz != null && f.rig != null ? f.rig! : solveRig(p);
  final mood = moodOf(f);
  final tea = f.taunting && f.taunt == 'tra-da';
  final selfie = f.taunting && f.taunt == 'chup-anh';
  if (f.state != FState.fall) {
    final k = clampD(1 + (hop + p.dy) / 160, 0.4, 1);
    _fillP(c, _ellipse((j.footF.x + j.footB.x) / 2 + 2, 2 - hop, 26 * k, 5 * k), const Color(0x26474B55));
  }
  c.save();
  if (p.dy != 0) c.translate(0, p.dy);
  if (p.rot != 0) c.rotate(p.rot);
  if (p.sc != 1) c.scale(p.sc);
  if (tea) _drawChair(c, j);
  _drawBack(c, look.cape, j, f, animT);
  final far = withAlpha(ink, 0.55);
  penLine(c, [j.hip, j.kneeB, j.footB, _toe(j.footB)], 7, far);
  penLine(c, [j.sh, j.elbW, j.handW], 6.5, far);
  if (f.wStrokes.isNotEmpty) {
    c.save();
    c.translate(j.handW.x, j.handW.y);
    c.rotate(p.th);
    drawInk(c, f.wStrokes, rgb(look.weaponInk.color), 7, shader: weaponShader(look.weaponInk, f.wStrokes, animT), cache: !editing);
    c.restore();
  }
  dot(c, j.handW.x, j.handW.y, 4.4, far);
  penLine(c, [j.hip, j.neck], 8, ink);
  dot(c, j.head.x + 1.8, j.head.y + 2.6, Len.head + 1.5, const Color(0x21232646));
  _fs(c, _circle(j.head.x, j.head.y, Len.head), Pal.body, ink, 4);
  c.save();
  c.translate(j.head.x, j.head.y);
  c.rotate(j.ha);
  drawFace(c, mood, ink, look.glass);
  drawGlasses(c, look.glass);
  drawHat(c, look.hat, ink, animT);
  c.restore();
  if (mood == Mood.dizzy) {
    final t = f.t * 6;
    for (var i = 0; i < 3; i++) {
      final a = t + i * 2.1;
      final sx = j.head.x + math.cos(a) * 15, sy = j.head.y - 20 + math.sin(a) * 4;
      line(c, sx - 3.4, sy, sx + 3.4, sy, const Color(0xFFC99700), 2);
      line(c, sx, sy - 3.4, sx, sy + 3.4, const Color(0xFFC99700), 2);
    }
  }
  if (mood == Mood.sleep) {
    for (var i = 0; i < 3; i++) {
      final ph = (animT * 0.8 + i / 3) % 1;
      drawText(c, 'z', j.head.x + 10 + ph * 10, j.head.y - 14 - ph * 18, 9.0 + i * 2, ink, alpha: 1 - ph);
    }
  }
  penLine(c, [j.hip, j.kneeF, j.footF, _toe(j.footF)], 7, ink);
  penLine(c, [j.sh, j.elbS, j.handS], 6.5, ink);
  if (tea) {
    _drawTea(c, j.handS);
  } else if (selfie) {
    _drawPhone(c, j.handS, animT);
  } else if (f.sStrokes.isNotEmpty) {
    final r = f.r;
    c.save();
    c.translate(j.handS.x, j.handS.y);
    c.rotate(-25 * deg * (1 - r));
    drawInk(c, f.sStrokes, rgb(look.shieldInk), 7, alpha: r > 0.02 && r < 1 ? 0.45 : 1, cache: !editing);
    c.restore();
  }
  dot(c, j.handS.x, j.handS.y, 4.4, ink);
  _drawStatus(c, f, j, animT);
  c.restore();
}

// ---------------- framing ----------------

/// Box `[x0, y0, x1, y1]` around a resting fighter holding the given weapon drawings.
List<double> gearBox(List<Strokes> sets) {
  var x0 = -34.0, x1 = 30.0, y0 = -146.0, y1 = 4.0;
  for (final st in sets) {
    for (final s in st) {
      for (var i = 0; i + 1 < s.length; i += 2) {
        final x = hand0.x + s[i], y = hand0.y + s[i + 1];
        x0 = math.min(x0, x);
        x1 = math.max(x1, x);
        y0 = math.min(y0, y);
        y1 = math.max(y1, y);
      }
    }
  }
  return [x0 - 10, y0 - 10, x1 + 10, y1 + 8];
}

/// Like [gearBox] but also fits the raised shield.
List<double> buildBox(Strokes w, Strokes s) {
  final b = gearBox([w]);
  for (final st in s) {
    for (var i = 0; i + 1 < st.length; i += 2) {
      final x = shRaised.x + st[i], y = shRaised.y + st[i + 1];
      b[0] = math.min(b[0], x - 10);
      b[2] = math.max(b[2], x + 10);
      b[1] = math.min(b[1], y - 10);
      b[3] = math.max(b[3], y + 8);
    }
  }
  b[1] = math.min(b[1], -160);
  return b;
}

/// Scales and centres [box] into [size]; returns the scale used.
double fitBox(Canvas c, Size size, List<double> box, {bool mirror = false, double fill = 1, bool alignBottom = false}) {
  final bw = box[2] - box[0], bh = box[3] - box[1];
  final k = math.min(size.width / bw, size.height / bh) * fill;
  if (mirror) {
    c.translate(size.width, 0);
    c.scale(-1, 1);
  }
  final ty = alignBottom ? size.height - 6 - box[3] * k : (size.height - bh * k) / 2 - box[1] * k;
  c.translate((size.width - bw * k) / 2 - box[0] * k, ty);
  c.scale(k, k);
  return k;
}

/// Thumbnail of a fighter with its weapon on a ground line (pre-match cards, blueprint tiles).
void paintThumb(Canvas c, Size size, Fighter f, List<double> box, {bool mirror = false, double animT = 0}) {
  c.save();
  fitBox(c, size, box, mirror: mirror);
  line(c, box[0], 1.5, box[2], 1.5, const Color(0x73474B55), 2);
  paintFighter(c, f, animT);
  c.restore();
}

/// Strokes alone, fitted into a tile (blueprint previews).
void paintStrokesFit(Canvas c, Size size, Strokes st, Color color, {WeaponInk? weaponInk, double animT = 0}) {
  if (st.isEmpty) return;
  final b = boundsOf(st);
  final box = [b[0] - 10, b[1] - 10, b[2] + 10, b[3] + 10];
  c.save();
  fitBox(c, size, box);
  drawInk(c, st, color, 6, shader: weaponInk == null ? null : weaponShader(weaponInk, st, animT));
  c.restore();
}

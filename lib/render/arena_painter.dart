import 'dart:math' as math;
import 'dart:ui';

import '../core/arenas.dart';
import 'ink_painter.dart';
import 'palette.dart';
import 'text_fx.dart';

/// Screen-space notebook paper for the arena's theme; [scroll] gives a little parallax.
void paintPaper(Canvas c, Size size, ArenaTheme th, double scroll) {
  c.drawRect(Offset.zero & size, Paint()..color = rgb(th.paper));
  final lineCol = rgb(th.line);
  final ox = -(scroll * 0.3) % 24;
  switch (th.kind) {
    case PaperKind.grid:
    case PaperKind.green:
    case PaperKind.blueprint:
      for (var x = ox; x < size.width; x += 24) {
        line(c, x, 0, x, size.height, lineCol, 1);
      }
      for (var y = 0.0; y < size.height; y += 24) {
        line(c, 0, y, size.width, y, lineCol, 1);
      }
      for (var y = 0.0; y < size.height; y += 6) {
        line(c, 0, y, size.width, y, withAlpha(lineCol, 0.35), 0.6);
      }
    case PaperKind.lined:
    case PaperKind.sepia:
      for (var y = 24.0; y < size.height; y += 24) {
        line(c, 0, y, size.width, y, lineCol, 1);
      }
      line(c, 26, 0, 26, size.height, withAlpha(Pal.margin, th.kind == PaperKind.sepia ? 0.4 : 0.8), 2);
    case PaperKind.dots:
      for (var x = ox; x < size.width; x += 18) {
        for (var y = 9.0; y < size.height; y += 18) {
          dot(c, x, y, 1.2, lineCol);
        }
      }
    case PaperKind.pixel:
      for (var x = ox; x < size.width; x += 12) {
        line(c, x, 0, x, size.height, withAlpha(lineCol, 0.6), 0.8);
      }
      for (var y = 0.0; y < size.height; y += 12) {
        line(c, 0, y, size.width, y, withAlpha(lineCol, 0.6), 0.8);
      }
    case PaperKind.staff:
      for (var top = 30.0; top < size.height; top += 70) {
        for (var k = 0; k < 5; k++) {
          line(c, 0, top + k * 7, size.width, top + k * 7, lineCol, 1);
        }
      }
    case PaperKind.kraft:
      final r = math.Random(7);
      for (var i = 0; i < 90; i++) {
        final x = r.nextDouble() * size.width, y = r.nextDouble() * size.height;
        line(c, x, y, x + 6 + r.nextDouble() * 10, y + r.nextDouble() * 2, withAlpha(lineCol, 0.7), 1);
      }
      for (var y = 24.0; y < size.height; y += 48) {
        line(c, 0, y, size.width, y, withAlpha(lineCol, 0.5), 1);
      }
    case PaperKind.chalk:
      break;
  }
}

/// Faint themed doodles in world space, behind the platform.
void paintDoodles(Canvas c, ArenaTheme th, double half) {
  final col = withAlpha(rgb(th.ink), 0.22);
  void t(String s, double x, double y, double size, [double rot = 0]) {
    c.save();
    c.translate(x, y);
    c.rotate(rot);
    drawText(c, s, 0, 0, size, col);
    c.restore();
  }

  final l = -half + 40, r = half - 40;
  switch (th.doodle) {
    case Doodle.math:
      t('x^2 + y^2 = r^2', l + 40, -230, 22, -0.06);
      t('pi = 3,14', r - 30, -260, 20, 0.05);
      t('1 + 1 = 2', 0, -300, 18);
      strokePath(c, Path()..addPolygon([Offset(r - 60, -150), Offset(r, -150), Offset(r - 30, -200)], true), col, 2);
      strokePath(c, Path()..addOval(Rect.fromCircle(center: Offset(l + 10, -150), radius: 26)), col, 2);
    case Doodle.letters:
      t('Ngày xửa ngày xưa...', l + 80, -250, 20, -0.04);
      t('Bài văn tả cảnh', r - 60, -190, 18, 0.05);
      t('« Học, học nữa »', 0, -310, 18);
    case Doodle.english:
      t('ABC', l + 20, -240, 34, -0.1);
      t('Hello!', r - 30, -210, 24, 0.08);
      t('I am a pen.', 0, -300, 20);
    case Doodle.physics:
      t('F = m.a', l + 30, -230, 24, -0.05);
      t('E = mc^2', r - 40, -270, 22, 0.06);
      line(c, -40, -320, 40, -320, col, 2);
      line(c, 0, -320, 18, -250, col, 2);
      strokePath(c, Path()..addOval(Rect.fromCircle(center: const Offset(18, -244), radius: 8)), col, 2);
    case Doodle.chem:
      t('H2O', l + 20, -220, 28, -0.06);
      t('CO2', r - 30, -260, 24, 0.05);
      final hex = Path();
      for (var i = 0; i <= 6; i++) {
        final a = i * math.pi / 3;
        final p = Offset(math.cos(a) * 26, -300 + math.sin(a) * 26);
        i == 0 ? hex.moveTo(p.dx, p.dy) : hex.lineTo(p.dx, p.dy);
      }
      strokePath(c, hex, col, 2);
    case Doodle.history:
      t('Thăng Long 1010', l + 70, -250, 22, -0.04);
      t('Bạch Đằng', r - 40, -200, 20, 0.05);
      final wall = Path()..moveTo(-90, -300);
      for (var k = 0; k < 6; k++) {
        wall
          ..relativeLineTo(0, -14)
          ..relativeLineTo(15, 0)
          ..relativeLineTo(0, 14)
          ..relativeLineTo(15, 0);
      }
      strokePath(c, wall, col, 2);
    case Doodle.geo:
      t('N', 0, -330, 26);
      line(c, 0, -315, 0, -255, col, 2);
      line(c, -30, -285, 30, -285, col, 2);
      for (var k = 0; k < 4; k++) {
        strokePath(
            c,
            Path()..addOval(Rect.fromCenter(center: Offset(l + 50, -220), width: 60.0 + k * 26, height: 30.0 + k * 14)),
            col,
            1.5);
      }
      t('Hà Nội •', r - 40, -240, 18);
    case Doodle.bio:
      t('DNA', l + 20, -230, 24, -0.05);
      for (var k = 0; k < 8; k++) {
        final y = -330.0 + k * 10;
        line(c, r - 60 + math.sin(k * 0.8) * 16, y, r - 60 - math.sin(k * 0.8) * 16, y, col, 1.5);
      }
      strokePath(c, Path()..addOval(Rect.fromCenter(center: const Offset(0, -290), width: 70, height: 40)), col, 2);
      dot(c, 6, -290, 6, col);
    case Doodle.art:
      final rr = math.Random(3);
      for (var k = 0; k < 7; k++) {
        final x = -half + rr.nextDouble() * half * 2, y = -330 + rr.nextDouble() * 160;
        dot(c, x, y, 8 + rr.nextDouble() * 14, withAlpha(rgb([0xFF595E, 0xFFCA3A, 0x8AC926, 0x1982C4, 0xC77DFF][k % 5]), 0.18));
      }
      t('Màu nước', l + 40, -200, 20, -0.05);
    case Doodle.sport:
      for (var k = 0; k < 3; k++) {
        strokePath(
            c,
            Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -270), width: 260.0 + k * 40, height: 70.0 + k * 22), const Radius.circular(60))),
            col,
            1.5);
      }
      t('1 - 0', r - 40, -210, 22);
    case Doodle.code:
      t('if (thang) {', l + 60, -260, 20, -0.03);
      t('  vui();', l + 70, -236, 20, -0.03);
      t('}', l + 30, -212, 20);
      t('0101 1100', r - 50, -300, 18, 0.04);
      t('<html>', r - 40, -200, 18);
    case Doodle.music:
      for (var k = 0; k < 5; k++) {
        line(c, -half, -300.0 + k * 9, half, -300.0 + k * 9, col, 1.2);
      }
      for (var k = 0; k < 6; k++) {
        final x = -half + 60 + k * (half * 2 - 120) / 5, y = -300.0 + (k * 13) % 36;
        fillPath(c, Path()..addOval(Rect.fromCenter(center: Offset(x, y), width: 12, height: 8)), col);
        line(c, x + 6, y, x + 6, y - 26, col, 1.5);
      }
  }
}

final List<double> _jitter = () {
  var seed = 11;
  double rnd() => (seed = (seed * 16807) % 2147483647) / 2147483647;
  return [for (var i = 0; i < 64; i++) rnd() * 12];
}();

Path _cliff(double half) {
  final p = Path();
  final lPts = <Offset>[], rPts = <Offset>[];
  var i = 0;
  for (var y = 0.0; y <= 900; y += 30) {
    final base = y == 0 ? 0.0 : 4 + y * 0.07;
    rPts.add(Offset(half - base - (y > 0 ? _jitter[i % 64] : 0), y));
    lPts.add(Offset(-half + base + (y > 0 ? _jitter[(i + 31) % 64] : 0), y));
    i++;
  }
  p.moveTo(lPts[0].dx, lPts[0].dy);
  for (final q in rPts) {
    p.lineTo(q.dx, q.dy);
  }
  for (var k = lPts.length - 1; k > 0; k--) {
    p.lineTo(lPts[k].dx, lPts[k].dy);
  }
  return p..close();
}

/// Platform with cliffs, arena hazards and "vực" labels. [half] is the current (maybe shrunk) half width.
void paintPlatform(Canvas c, ArenaDef arena, double half, double animT) {
  final th = arena.theme, rules = arena.rules;
  final cliff = _cliff(half);
  if (half < rules.half - 1) {
    strokePath(c, dashed(Path()..moveTo(-rules.half, 0)..lineTo(rules.half, 0), 6, 8), withAlpha(Pal.red, 0.35), 2);
  }
  fillPath(c, cliff, withAlpha(rgb(th.platform), 0.9));
  c.save();
  c.clipPath(cliff);
  for (var x = -half - 900; x < half; x += 18) {
    line(c, x, 900, x + 900, 0, const Color(0x26474B55), 2);
  }
  if (rules.frictionMul < 0.95) {
    for (var x = -half + 20; x < half - 20; x += 46) {
      final shine = 0.25 + 0.15 * math.sin(animT * 2 + x * 0.05);
      line(c, x, 6, x + 26, 6, Color.fromRGBO(120, 200, 230, shine), 3);
    }
  }
  c.restore();
  strokePath(c, cliff, rgb(th.edge), 3);
  line(c, -half, 0, half, 0, rgb(th.edge), 5);
  for (final z in rules.mud) {
    final x0 = math.max(z.x0, -half), x1 = math.min(z.x1, half);
    if (x1 <= x0) continue;
    final path = Path()..addRRect(RRect.fromLTRBR(x0, -5, x1, 4, const Radius.circular(5)));
    fillPath(c, path, const Color(0x997A4A2A));
    strokePath(c, path, const Color(0xCC5A3510), 1.5);
    for (var x = x0 + 10; x < x1 - 6; x += 22) {
      final b = (animT * 0.7 + x * 0.013) % 1;
      strokePath(c, Path()..addOval(Rect.fromCircle(center: Offset(x, -6 - b * 6), radius: 2 + b * 2)),
          Color.fromRGBO(90, 53, 16, 0.6 * (1 - b)), 1);
    }
  }
  final paint = [0xFF8FB1, 0x6EC6F0, 0xFFCA3A];
  var k = 0;
  for (final z in rules.slick) {
    final x0 = math.max(z.x0, -half), x1 = math.min(z.x1, half);
    if (x1 <= x0) continue;
    final col = rgb(paint[k++ % paint.length]);
    final path = Path()..addOval(Rect.fromLTRB(x0, -4, x1, 6));
    fillPath(c, path, withAlpha(col, 0.55));
    line(c, x0 + (x1 - x0) * 0.25, -1, x0 + (x1 - x0) * 0.45, -1, const Color(0xB3FFFFFF), 2);
  }
  for (var x = -half + 28; x < half - 20; x += 57) {
    line(c, x - 5, -7, x, 0, rgb(th.edge), 2);
    line(c, x, 0, x + 4, -9, rgb(th.edge), 2);
  }
  for (final sgn in [-1.0, 1.0]) {
    final x = sgn * (half + 56);
    drawText(c, 'vực', x, 66, 24, rgb(th.accent));
    line(c, x, 82, x, 128, rgb(th.accent), 2.5);
    line(c, x - 8, 118, x, 130, rgb(th.accent), 2.5);
    line(c, x + 8, 118, x, 130, rgb(th.accent), 2.5);
  }
}

/// Range bracket on the ground: `]` for the player, `[` for the opponent; bold when in range.
void paintRangeTick(Canvas c, double x, Color col, bool hot, double f) {
  strokePath(
      c,
      Path()
        ..moveTo(x - f * 9, -20)
        ..lineTo(x, -20)
        ..lineTo(x, 14)
        ..lineTo(x - f * 9, 14),
      withAlpha(col, hot ? 0.95 : 0.4),
      hot ? 4.5 : 3);
}

/// Wind streaks across the screen and an arrow showing direction and strength.
void paintWind(Canvas c, Size size, double wind, double animT) {
  final s = wind.abs();
  if (s < 0.05) return;
  final dir = wind > 0 ? 1.0 : -1.0;
  final r = math.Random(5);
  for (var i = 0; i < 9; i++) {
    final y = 30 + r.nextDouble() * (size.height * 0.6);
    final speed = 140 + r.nextDouble() * 120;
    final len = 24 + r.nextDouble() * 30;
    final x = ((r.nextDouble() * size.width + animT * speed * dir) % (size.width + len)) - len / 2;
    line(c, x, y, x + len * dir, y, Color.fromRGBO(71, 75, 85, 0.25 * math.min(1, s)), 2);
  }
  final cx = size.width / 2, cy = 16.0;
  final len = 18 + 18 * math.min(1, s);
  line(c, cx - len * dir / 2, cy, cx + len * dir / 2, cy, Pal.pencil, 3);
  line(c, cx + len * dir / 2, cy, cx + len * dir / 2 - 7 * dir, cy - 6, Pal.pencil, 3);
  line(c, cx + len * dir / 2, cy, cx + len * dir / 2 - 7 * dir, cy + 6, Pal.pencil, 3);
  drawText(c, 'gió', cx, cy + 15, 14, Pal.pencil);
}

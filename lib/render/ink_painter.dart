import 'dart:ui';

import '../core/mathx.dart';
import '../core/strokes.dart';
import 'palette.dart';

Path pathOfStroke(Stroke s) {
  final p = Path()..moveTo(s[0], s[1]);
  if (s.length < 4) {
    p.lineTo(s[0] + 0.01, s[1]);
    return p;
  }
  for (var i = 2; i < s.length; i += 2) {
    p.lineTo(s[i], s[i + 1]);
  }
  return p;
}

class _InkPaths {
  _InkPaths(this.paths, this.closed);
  final List<Path> paths;
  final List<bool> closed;
}

final Expando<_InkPaths> _pathCache = Expando('ink-paths');

/// Paths for a finished drawing are cached per stroke list; pass [cache] false while it is being edited.
_InkPaths _pathsFor(Strokes st, bool cache) {
  if (cache) {
    final hit = _pathCache[st];
    if (hit != null && hit.paths.length == st.length) return hit;
  }
  final out = _InkPaths(
    [
      for (final s in st)
        if (s.length >= 2) pathOfStroke(s),
    ],
    [
      for (final s in st)
        if (s.length >= 2) isClosed(s),
    ],
  );
  if (cache) _pathCache[st] = out;
  return out;
}

final Paint _p = Paint()
  ..isAntiAlias = true
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// Draws gear strokes like a ballpoint pen: light fill inside loops, a soft shadow,
/// the ink line and a thin highlight. [shader] replaces the colour for special inks.
void drawInk(Canvas c, Strokes st, Color color, double w, {Shader? shader, double alpha = 1, bool cache = true}) {
  if (st.isEmpty) return;
  final ip = _pathsFor(st, cache);
  // fill closed loops
  _p
    ..style = PaintingStyle.fill
    ..shader = shader
    ..color = withAlpha(color, (shader != null ? 0.14 : 0.12) * alpha);
  if (shader != null) _p.color = Color.fromRGBO(0, 0, 0, 0.14 * alpha);
  for (var i = 0; i < ip.paths.length; i++) {
    if (ip.closed[i]) c.drawPath(ip.paths[i], _p);
  }
  _p
    ..shader = null
    ..style = PaintingStyle.stroke
    ..strokeWidth = w + 1.5
    ..color = Color.fromRGBO(35, 38, 70, 0.17 * alpha);
  c.save();
  c.translate(2.4, 3.4);
  for (final path in ip.paths) {
    c.drawPath(path, _p);
  }
  c.restore();
  _p
    ..strokeWidth = w
    ..shader = shader
    ..color = shader != null ? Color.fromRGBO(0, 0, 0, alpha) : withAlpha(color, alpha);
  for (final path in ip.paths) {
    c.drawPath(path, _p);
  }
  _p
    ..shader = null
    ..strokeWidth = w * 0.26 < 1 ? 1 : w * 0.26
    ..color = Color.fromRGBO(255, 255, 255, 0.42 * alpha);
  c.save();
  c.translate(-0.9, -1.2);
  for (final path in ip.paths) {
    c.drawPath(path, _p);
  }
  c.restore();
}

/// A limb in pen style: shadow, line, highlight.
void penLine(Canvas c, List<P> pts, double w, Color col) {
  final path = Path()..moveTo(pts[0].x, pts[0].y);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].x, pts[i].y);
  }
  _p
    ..shader = null
    ..style = PaintingStyle.stroke
    ..strokeWidth = w + 1
    ..color = const Color.fromRGBO(35, 38, 70, 0.15);
  c.save();
  c.translate(2, 2.8);
  c.drawPath(path, _p);
  c.restore();
  _p
    ..strokeWidth = w
    ..color = col;
  c.drawPath(path, _p);
  _p
    ..strokeWidth = w * 0.26 < 1 ? 1 : w * 0.26
    ..color = const Color.fromRGBO(255, 255, 255, 0.36);
  c.save();
  c.translate(-0.8, -1);
  c.drawPath(path, _p);
  c.restore();
}

final Paint _line = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

void line(Canvas c, double x0, double y0, double x1, double y1, Color col, double w) {
  _line
    ..color = col
    ..strokeWidth = w;
  c.drawLine(Offset(x0, y0), Offset(x1, y1), _line);
}

void strokePath(Canvas c, Path p, Color col, double w) {
  _line
    ..color = col
    ..strokeWidth = w;
  c.drawPath(p, _line);
}

final Paint _fill = Paint()
  ..isAntiAlias = true
  ..style = PaintingStyle.fill;

void fillPath(Canvas c, Path p, Color col) {
  _fill
    ..shader = null
    ..color = col;
  c.drawPath(p, _fill);
}

void dot(Canvas c, double x, double y, double r, Color col) {
  _fill
    ..shader = null
    ..color = col;
  c.drawCircle(Offset(x, y), r, _fill);
}

void fillRect(Canvas c, double x, double y, double w, double h, Color col) {
  _fill
    ..shader = null
    ..color = col;
  c.drawRect(Rect.fromLTWH(x, y, w, h), _fill);
}

/// Dashed version of [source] (Flutter has no native line dash).
Path dashed(Path source, double dash, double gap) {
  final out = Path();
  for (final m in source.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      out.addPath(m.extractPath(d, d + dash), Offset.zero);
      d += dash + gap;
    }
  }
  return out;
}

void dashedLine(Canvas c, double x0, double y0, double x1, double y1, Color col, double w, double dash, double gap) {
  strokePath(
    c,
    dashed(
      Path()
        ..moveTo(x0, y0)
        ..lineTo(x1, y1),
      dash,
      gap,
    ),
    col,
    w,
  );
}

void dashedCircle(Canvas c, double x, double y, double r, Color col, double w, double dash, double gap) {
  strokePath(c, dashed(Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r)), dash, gap), col, w);
}

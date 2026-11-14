import 'dart:math' as math;
import 'dart:typed_data';

import 'mathx.dart';
import 'rng.dart';

/// One pen stroke as a flat list `[x0, y0, x1, y1, ...]` in gear-local units.
typedef Stroke = List<double>;

/// A drawing: weapon or shield made of strokes.
typedef Strokes = List<Stroke>;

/// Ink used by one stroke. A single dot still costs a little ink.
double strokeLen(Stroke s) {
  if (s.length < 4) return 3;
  var l = 0.0;
  for (var i = 2; i < s.length; i += 2) {
    l += hypot(s[i] - s[i - 2], s[i + 1] - s[i - 1]);
  }
  return l;
}

double inkOf(Strokes st) {
  var l = 0.0;
  for (final s in st) {
    l += strokeLen(s);
  }
  return l;
}

/// A loop the player drew by returning near the start point; it gets a light fill.
bool isClosed(Stroke s) =>
    s.length > 16 && hypot(s[0] - s[s.length - 2], s[1] - s[s.length - 1]) < 22 && strokeLen(s) > 60;

/// Points every [step] units along all strokes; collision and stats use these.
Float32List resample(Strokes st, [double step = 5]) {
  final out = <double>[];
  for (final s in st) {
    if (s.length < 2) continue;
    out
      ..add(s[0])
      ..add(s[1]);
    for (var i = 2; i < s.length; i += 2) {
      final ax = s[i - 2], ay = s[i - 1], bx = s[i], by = s[i + 1];
      final n = math.max(1, (hypot(bx - ax, by - ay) / step).ceil());
      for (var k = 1; k <= n; k++) {
        out
          ..add(ax + (bx - ax) * k / n)
          ..add(ay + (by - ay) * k / n);
      }
    }
  }
  return Float32List.fromList(out);
}

Strokes cloneSt(Strokes st) => [for (final s in st) List<double>.of(s)];

Strokes scaleSt(Strokes st, double k) => [
      for (final s in st) [for (final v in s) v * k],
    ];

/// Rounds coordinates to 0.1 to keep saves small.
Strokes roundSt(Strokes st) => [
      for (final s in st) [for (final v in s) (v * 10).roundToDouble() / 10],
    ];

/// Hand-drawn jitter for template gear, ported from the web game.
Strokes wobble(Strokes st, double amt, Rng rng) => [for (final s in st) _wobbleOne(s, amt, rng)];

Stroke _wobbleOne(Stroke s, double amt, Rng rng) {
  if (s.length < 4) return List<double>.of(s);
  final out = <double>[];
  var ph = rng.next() * 9;
  for (var i = 2; i < s.length; i += 2) {
    final ax = s[i - 2], ay = s[i - 1], bx = s[i], by = s[i + 1];
    final n = math.max(1, jsRound(hypot(bx - ax, by - ay) / 7));
    for (var k = (i == 2 ? 0 : 1); k <= n; k++) {
      final t = k / n;
      ph += 0.55;
      out
        ..add(ax + (bx - ax) * t + math.sin(ph * 1.7) * amt)
        ..add(ay + (by - ay) * t + math.cos(ph * 1.1) * amt);
    }
  }
  return out;
}

/// Horizontal fill lines inside a closed outline: more ink without a bigger shape.
Strokes hatch(Stroke poly, double gap) {
  var y0 = 1e9, y1 = -1e9;
  for (var i = 1; i < poly.length; i += 2) {
    y0 = math.min(y0, poly[i]);
    y1 = math.max(y1, poly[i]);
  }
  final lines = <Stroke>[];
  for (var y = y0 + gap / 2; y < y1; y += gap) {
    final xs = <double>[];
    for (var i = 2; i < poly.length; i += 2) {
      final ax = poly[i - 2], ay = poly[i - 1], bx = poly[i], by = poly[i + 1];
      if ((ay <= y && by > y) || (by <= y && ay > y)) {
        xs.add(ax + (y - ay) / (by - ay) * (bx - ax));
      }
    }
    xs.sort();
    for (var k = 0; k + 1 < xs.length; k += 2) {
      if (xs[k + 1] - xs[k] > 8) lines.add([xs[k] + 3, y, xs[k + 1] - 3, y]);
    }
  }
  return lines;
}

/// Adds ink up to [target] without growing the gear: hatches the first closed
/// outline, or re-traces the strokes beside themselves when there is none.
Strokes fillTo(Strokes st, double target) {
  final base = inkOf(st);
  if (target <= base + 10) return st;
  Stroke? poly;
  for (final s in st) {
    if (s.length >= 8 && hypot(s[0] - s[s.length - 2], s[1] - s[s.length - 1]) < 1 && strokeLen(s) > 60) {
      poly = s;
      break;
    }
  }
  if (poly == null) return thicken(st, target);
  var lo = 4.0, hi = 90.0;
  var best = <Stroke>[];
  for (var it = 0; it < 14; it++) {
    final mid = (lo + hi) / 2, lines = hatch(poly, mid);
    if (base + inkOf(lines) <= target) {
      best = lines;
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return [...st, ...best];
}

Strokes thicken(Strokes st, double target) {
  final out = [...st];
  var ink = inkOf(out);
  final order = [...st]..sort((a, b) => strokeLen(b).compareTo(strokeLen(a)));
  const offsets = [2.5, -2.5, 5.0, -5.0, 7.5, -7.5];
  for (final off in offsets) {
    for (final s in order) {
      if (s.length < 4) continue;
      final add = strokeLen(s);
      if (ink + add > target) continue;
      out.add(_offsetStroke(s, off));
      ink += add;
    }
    if (ink >= target - 20) break;
  }
  return out;
}

Stroke _offsetStroke(Stroke s, double off) {
  final dx = s[s.length - 2] - s[0], dy = s[s.length - 1] - s[1];
  final n = hypot(dx, dy);
  if (n < 1e-6) return List<double>.of(s);
  final px = -dy / n * off, py = dx / n * off;
  return [
    for (var i = 0; i < s.length; i += 2) ...[s[i] + px, s[i + 1] + py],
  ];
}

/// Bounding box `[x0, y0, x1, y1]` of all points.
List<double> boundsOf(Strokes st) {
  var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (final s in st) {
    for (var i = 0; i + 1 < s.length; i += 2) {
      x0 = math.min(x0, s[i]);
      x1 = math.max(x1, s[i]);
      y0 = math.min(y0, s[i + 1]);
      y1 = math.max(y1, s[i + 1]);
    }
  }
  return [x0, y0, x1, y1];
}

// ---- shape builders for templates ----

Stroke seg(double x0, double y0, double x1, double y1) => [x0, y0, x1, y1];

Stroke closedPoly(List<double> xy) => [...xy, xy[0], xy[1]];

Stroke rectPts(double x0, double y0, double x1, double y1) =>
    closedPoly([x0, y0, x1, y0, x1, y1, x0, y1]);

/// Circle as a closed polygon whose last point equals the first (like `circ` in the web game).
Stroke circlePts(double cx, double cy, double r, int n) => [
      for (var i = 0; i <= n; i++) ...[
        cx + math.cos(i / n * math.pi * 2) * r,
        cy + math.sin(i / n * math.pi * 2) * r,
      ],
    ];

Stroke ellipsePts(double cx, double cy, double rx, double ry, int n) => [
      for (var i = 0; i <= n; i++) ...[
        cx + math.cos(i / n * math.pi * 2) * rx,
        cy + math.sin(i / n * math.pi * 2) * ry,
      ],
    ];

/// Arc from [a0] to [a1] degrees (canvas angles: 90 points down).
Stroke arcPts(double cx, double cy, double r, double a0, double a1, int n) => [
      for (var i = 0; i <= n; i++) ...[
        cx + math.cos((a0 + (a1 - a0) * i / n) * deg) * r,
        cy + math.sin((a0 + (a1 - a0) * i / n) * deg) * r,
      ],
    ];

Stroke starPts(double cx, double cy, double outer, double inner, int points) {
  final out = <double>[];
  for (var i = 0; i <= points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final r = i.isEven ? outer : inner;
    out
      ..add(cx + math.cos(a) * r)
      ..add(cy + math.sin(a) * r);
  }
  return out;
}

/// Single-point stroke: a dot.
Stroke dotPt(double x, double y) => [x, y];

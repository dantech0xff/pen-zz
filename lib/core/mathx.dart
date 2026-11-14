import 'dart:math' as math;

const double deg = math.pi / 180;

/// Immutable 2D point in gear-local or world units (x right, y down).
class P {
  const P(this.x, this.y);
  final double x;
  final double y;

  P operator +(P o) => P(x + o.x, y + o.y);
  P operator -(P o) => P(x - o.x, y - o.y);
  P scale(double k) => P(x * k, y * k);

  @override
  String toString() => 'P($x, $y)';
}

double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
double easeOut(double u) => 1 - (1 - u) * (1 - u);
double smooth(double u) => u * u * (3 - 2 * u);
double hypot(double x, double y) => math.sqrt(x * x + y * y);
double signD(double v) => v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);
double lerpD(double a, double b, double u) => a + (b - a) * u;

/// Same rounding as JavaScript's Math.round (halves go towards +infinity),
/// so formulas ported from the web game give identical integers.
int jsRound(double v) => (v + 0.5).floor();

/// Thousands with dots, Vietnamese style: 25000 -> 25.000.
String fmtNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

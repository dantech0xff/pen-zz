/// Deterministic random generator (mulberry32). Battles and level content are
/// seeded with it so they replay identically on Android, iOS and the web build.
class Rng {
  Rng(int seed) : _s = seed & 0xFFFFFFFF;

  int _s;

  /// 32-bit multiply that stays exact on the web, where ints are doubles.
  static int imul(int a, int b) {
    final ah = (a >> 16) & 0xFFFF, al = a & 0xFFFF;
    final bh = (b >> 16) & 0xFFFF, bl = b & 0xFFFF;
    return (al * bl + (((ah * bl + al * bh) & 0xFFFF) << 16)) & 0xFFFFFFFF;
  }

  /// Next value in [0, 1).
  double next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = imul(t ^ (t >> 15), t | 1);
    t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  double range(double a, double b) => a + next() * (b - a);
  int nextInt(int n) => (next() * n).floor();
  bool chance(double p) => next() < p;
  T pick<T>(List<T> items) => items[nextInt(items.length)];

  /// Independent stream derived from this one, for sub-systems that should not
  /// shift the main sequence when they draw more or fewer numbers.
  Rng fork(int salt) => Rng(imul(_s ^ salt, 0x9E3779B1) ^ salt);
}

/// FNV-1a hash of a string, used to derive stable seeds from ids.
int hashString(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = Rng.imul(h ^ c, 0x01000193);
  }
  return h;
}

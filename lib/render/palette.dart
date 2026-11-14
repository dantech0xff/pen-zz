import 'package:flutter/painting.dart';

/// Colours of the notebook look (same values as the web game).
abstract final class Pal {
  static const paper = Color(0xFFFBFAF3);
  static const grid = Color(0xFFD3DBF1);
  static const margin = Color(0xFFEA8F97);
  static const ink = Color(0xFF1D3AA8);
  static const red = Color(0xFFD3303C);
  static const pencil = Color(0xFF474B55);
  static const hl = Color(0xFFFFE14A);
  static const body = Color(0xFFFFFDF7);
  static const gold = Color(0xFFE0A800);
  static const shadow = Color(0x2B232646);
}

/// `0xRRGGBB` with alpha.
Color rgb(int c, [double a = 1]) =>
    Color.fromARGB((a * 255).round().clamp(0, 255), (c >> 16) & 255, (c >> 8) & 255, c & 255);

Color withAlpha(Color c, double a) => c.withValues(alpha: (c.a * a).clamp(0.0, 1.0));

Color hsl(double h, double s, double l, [double a = 1]) =>
    HSLColor.fromAHSL(a.clamp(0.0, 1.0), h % 360, s.clamp(0.0, 1.0), l.clamp(0.0, 1.0)).toColor();

/// Font families bundled with the app.
abstract final class Fonts {
  static const display = 'Coiny';
  static const body = 'PatrickHand';
}

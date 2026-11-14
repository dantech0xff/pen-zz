import 'package:flutter/painting.dart';

import 'palette.dart';

final Map<String, TextPainter> _cache = {};

/// Cached text layout: canvas text is redrawn every frame, layouts are not.
TextPainter textPainter(String text, double size, Color color, {String family = Fonts.body, Paint? foreground}) {
  final key = '$text|$size|${color.toARGB32()}|$family|${foreground == null ? '' : 'o'}';
  final hit = _cache[key];
  if (hit != null) return hit;
  if (_cache.length > 400) _cache.clear();
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: family,
        fontSize: size,
        height: 1.1,
        color: foreground == null ? color : null,
        foreground: foreground,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  _cache[key] = tp;
  return tp;
}

/// Text centred at (x, y); [outline] draws a light rim first so it reads on any background.
void drawText(Canvas c, String text, double x, double y, double size, Color color,
    {String family = Fonts.body, double outline = 0, Color outlineColor = Pal.body, double alpha = 1}) {
  final col = withAlpha(color, alpha);
  if (outline > 0) {
    final rim = textPainter(text, size, outlineColor, family: family, foreground: Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outline
      ..strokeJoin = StrokeJoin.round
      ..color = withAlpha(outlineColor, alpha));
    rim.paint(c, Offset(x - rim.width / 2, y - rim.height / 2));
  }
  final tp = textPainter(text, size, col, family: family);
  tp.paint(c, Offset(x - tp.width / 2, y - tp.height / 2));
}

/// Speech bubble with a tail pointing down at (x, y); kept inside [maxW].
void drawBubble(Canvas c, double x, double y, String text, Color col, double maxW) {
  final tp = textPainter(text, 16, col);
  final w = tp.width + 18, h = 26.0;
  final cx = x.clamp(w / 2 + 4, maxW - w / 2 - 4).toDouble();
  final r = RRect.fromRectAndRadius(Rect.fromLTWH(cx - w / 2, y - h, w, h), const Radius.circular(10));
  final fill = Paint()..color = Pal.body;
  final stroke = Paint()
    ..color = col
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeJoin = StrokeJoin.round;
  final tail = Path()
    ..moveTo(cx - 6, y - 1)
    ..lineTo(cx, y + 7)
    ..lineTo(cx + 6, y - 1);
  c.drawRRect(r, fill);
  c.drawRRect(r, stroke);
  c.drawPath(tail, fill);
  c.drawPath(tail, stroke);
  c.drawRect(Rect.fromLTWH(cx - 5, y - 3, 10, 3), fill);
  tp.paint(c, Offset(cx - tp.width / 2, y - h / 2 - tp.height / 2));
}

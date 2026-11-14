import 'package:flutter/material.dart';

import '../render/palette.dart';

abstract final class T {
  static TextStyle display(double size, [Color color = Pal.ink]) =>
      TextStyle(fontFamily: Fonts.display, fontSize: size, color: color, height: 1.15);
  static TextStyle body(double size, [Color color = Pal.pencil]) =>
      TextStyle(fontFamily: Fonts.body, fontSize: size, color: color, height: 1.25);
}

/// Hand-drawn corner radii from the web version's CSS (`14px 6px 12px 8px / 8px 12px 6px 14px`).
const BorderRadius sketchRadius = BorderRadius.only(
  topLeft: Radius.elliptical(14, 8),
  topRight: Radius.elliptical(6, 12),
  bottomRight: Radius.elliptical(12, 6),
  bottomLeft: Radius.elliptical(8, 14),
);

const BorderRadius cardRadius = BorderRadius.only(
  topLeft: Radius.elliptical(14, 10),
  topRight: Radius.elliptical(8, 16),
  bottomRight: Radius.elliptical(16, 8),
  bottomLeft: Radius.elliptical(10, 14),
);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Pal.paper,
  colorScheme: ColorScheme.fromSeed(seedColor: Pal.ink, surface: Pal.paper),
  fontFamily: Fonts.body,
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Pal.paper, showDragHandle: true),
  dialogTheme: const DialogThemeData(backgroundColor: Pal.paper),
);

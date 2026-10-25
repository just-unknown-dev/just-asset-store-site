import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

/// Brand palette (dark, the default), from [JuPalette].
abstract final class JuColors {
  static const Color primary = Color(JuPalette.primary);
  static const Color background = Color(JuPalette.background);
  static const Color surface = Color(JuPalette.surface);
  static const Color surfaceSoft = Color(JuPalette.surfaceSoft);
  static const Color text = Color(JuPalette.text);
  static const Color textMuted = Color(JuPalette.textMuted);
  static const Color border = Color(JuPalette.border);
  static const Color codeBackground = Color(JuPalette.codeBackground);
  static const Color error = Color(JuPalette.error);

  /// Text drawn on top of [primary].
  static const Color onPrimary = Color(JuPalette.onPrimary);
}

/// The light variant, its primary darkened so it reads as text.
abstract final class JuColorsLight {
  static const Color primary = Color(JuPalette.lightPrimary);
  static const Color background = Color(JuPalette.lightBackground);
  static const Color surface = Color(JuPalette.lightSurface);
  static const Color surfaceSoft = Color(JuPalette.lightSurfaceSoft);
  static const Color text = Color(JuPalette.lightText);
  static const Color textMuted = Color(JuPalette.lightTextMuted);
  static const Color border = Color(JuPalette.lightBorder);
  static const Color codeBackground = Color(JuPalette.lightCodeBackground);
  static const Color error = JuColors.error;
  static const Color onPrimary = Color(JuPalette.lightOnPrimary);
}

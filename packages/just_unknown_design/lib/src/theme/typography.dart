import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

/// The font families, as an app names this package's fonts.
abstract final class JuFonts {
  static const String display = 'packages/${JuAssets.package}/SpaceGrotesk';
  static const String body = 'packages/${JuAssets.package}/Inter';
  static const String mono = 'packages/${JuAssets.package}/JetBrainsMono';
}

/// The type scale in [text], with body copy in [muted].
TextTheme juTextTheme({required Color text, required Color muted}) {
  TextStyle display(
    double size, {
    double height = 1.1,
    double spacing = -0.02,
  }) => TextStyle(
    fontFamily: JuFonts.display,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: height,
    letterSpacing: size * spacing,
    color: text,
  );

  TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.6,
  }) => TextStyle(
    fontFamily: JuFonts.body,
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color ?? text,
  );

  return TextTheme(
    displayLarge: display(64),
    displayMedium: display(52),
    displaySmall: display(40),
    headlineLarge: display(36, height: 1.15),
    headlineMedium: display(28, height: 1.2),
    headlineSmall: display(22, height: 1.25, spacing: -0.01),
    titleLarge: TextStyle(
      fontFamily: JuFonts.display,
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: text,
    ),
    titleMedium: body(17, weight: FontWeight.w600, height: 1.4),
    titleSmall: body(15, weight: FontWeight.w600, height: 1.4),
    bodyLarge: body(18, color: muted),
    bodyMedium: body(16, color: muted),
    bodySmall: body(14, color: muted, height: 1.5),
    labelLarge: body(15, weight: FontWeight.w600, height: 1.2),
    labelMedium: body(13, weight: FontWeight.w600, height: 1.2, color: muted),
    labelSmall: TextStyle(
      fontFamily: JuFonts.body,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      height: 1.2,
      color: muted,
    ),
  );
}

/// Code and commands.
const TextStyle juMonoStyle = TextStyle(
  fontFamily: JuFonts.mono,
  fontSize: 14,
  height: 1.6,
);

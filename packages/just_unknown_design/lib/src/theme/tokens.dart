import 'package:flutter/material.dart';

/// Design tokens that Material's ColorScheme does not model.
class JuTokens extends ThemeExtension<JuTokens> {
  const JuTokens({
    required this.surfaceSoft,
    required this.border,
    required this.textMuted,
    required this.glow,
    required this.codeBackground,
  });

  final Color surfaceSoft;
  final Color border;
  final Color textMuted;
  final Color glow;
  final Color codeBackground;

  @override
  JuTokens copyWith({
    Color? surfaceSoft,
    Color? border,
    Color? textMuted,
    Color? glow,
    Color? codeBackground,
  }) => JuTokens(
    surfaceSoft: surfaceSoft ?? this.surfaceSoft,
    border: border ?? this.border,
    textMuted: textMuted ?? this.textMuted,
    glow: glow ?? this.glow,
    codeBackground: codeBackground ?? this.codeBackground,
  );

  @override
  JuTokens lerp(ThemeExtension<JuTokens>? other, double t) {
    if (other is! JuTokens) return this;
    return JuTokens(
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
    );
  }
}

abstract final class JuSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
  static const double x10 = 40;
  static const double x12 = 48;
  static const double x16 = 64;
  static const double x24 = 96;
}

abstract final class JuRadii {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 24;

  /// Fully rounded ends (chips, badges).
  static const double pill = 999;
}

abstract final class JuDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
}

extension JuContext on BuildContext {
  JuTokens get tokens => Theme.of(this).extension<JuTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

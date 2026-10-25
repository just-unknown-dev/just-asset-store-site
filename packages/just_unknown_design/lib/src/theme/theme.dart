import 'package:flutter/material.dart';

import 'colors.dart';
import 'tokens.dart';
import 'typography.dart';

abstract final class JuTheme {
  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    primary: JuColors.primary,
    onPrimary: JuColors.onPrimary,
    background: JuColors.background,
    surface: JuColors.surface,
    surfaceSoft: JuColors.surfaceSoft,
    text: JuColors.text,
    textMuted: JuColors.textMuted,
    border: JuColors.border,
    codeBackground: JuColors.codeBackground,
    error: JuColors.error,
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    primary: JuColorsLight.primary,
    onPrimary: JuColorsLight.onPrimary,
    background: JuColorsLight.background,
    surface: JuColorsLight.surface,
    surfaceSoft: JuColorsLight.surfaceSoft,
    text: JuColorsLight.text,
    textMuted: JuColorsLight.textMuted,
    border: JuColorsLight.border,
    codeBackground: JuColorsLight.codeBackground,
    error: JuColorsLight.error,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color background,
    required Color surface,
    required Color surfaceSoft,
    required Color text,
    required Color textMuted,
    required Color border,
    required Color codeBackground,
    required Color error,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: primary,
      onSecondary: onPrimary,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: border,
      surfaceContainerHighest: surfaceSoft,
      surfaceContainerLow: background,
      inverseSurface: text,
      onInverseSurface: background,
    );
    final textTheme = juTextTheme(text: text, muted: textMuted);
    final tokens = JuTokens(
      surfaceSoft: surfaceSoft,
      border: border,
      textMuted: textMuted,
      glow: primary.withValues(alpha: 0.35),
      codeBackground: codeBackground,
    );

    final roundedSm = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(JuRadii.sm),
    );
    OutlineInputBorder field(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(JuRadii.sm),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: textTheme,
      fontFamily: JuFonts.body,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: textMuted, size: 22),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JuRadii.md),
          side: BorderSide(color: border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSoft,
        selectedColor: primary.withValues(alpha: 0.16),
        side: BorderSide(color: border),
        labelStyle: textTheme.labelMedium?.copyWith(color: text),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: primary),
        checkmarkColor: primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JuRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: roundedSm,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: roundedSm,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: text,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: roundedSm,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textMuted,
          shape: roundedSm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: textTheme.bodyMedium,
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelLarge?.copyWith(color: primary),
        helperStyle: textTheme.bodySmall,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: JuSpacing.x4,
          vertical: JuSpacing.x4,
        ),
        border: field(border),
        enabledBorder: field(border),
        focusedBorder: field(primary, 1.5),
        errorBorder: field(error),
        focusedErrorBorder: field(error, 1.5),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.3),
        selectionHandleColor: primary,
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: textMuted, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceSoft,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceSoft,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JuRadii.sm),
          side: BorderSide(color: border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium?.copyWith(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JuRadii.sm),
          side: BorderSide(color: border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(roundedSm),
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: surface,
        shape: const RoundedRectangleBorder(),
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textMuted,
        textColor: text,
        shape: roundedSm,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceSoft,
          borderRadius: BorderRadius.circular(JuRadii.sm),
          border: Border.all(color: border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: text),
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}

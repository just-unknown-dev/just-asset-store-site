/// The Just Unknown palette as ARGB ints. Pure Dart: the Flutter theme
/// (`JuColors`) and the static shell's CSS (`shellCss`) both read it, so
/// the two can't drift apart.
abstract final class JuPalette {
  /// The brand coral, the same in both modes.
  static const int primary = 0xFFF5746F;

  /// Text drawn on top of [primary].
  static const int onPrimary = 0xFF1A0B0B;

  /// Errors and warnings.
  static const int error = 0xFFFF6B6B;

  // Dark, the default.
  static const int background = 0xFF080B17;
  static const int surface = 0xFF141826;
  static const int surfaceSoft = 0xFF1C2233;
  static const int text = 0xFFEDEFF7;
  static const int textMuted = 0xFF9FA8C1;
  static const int border = 0xFF2A3248;
  static const int codeBackground = 0xFF0D1020;

  // Light, derived from the dark palette. The brand coral is too pale to
  // read as text on a light page (2.6:1), so light mode darkens it: 5:1 or
  // more on every light surface, with white on top of it.
  static const int lightPrimary = 0xFFB4433D;
  static const int lightOnPrimary = 0xFFFFFFFF;
  static const int lightBackground = 0xFFF7F8FC;
  static const int lightSurface = 0xFFFFFFFF;
  static const int lightSurfaceSoft = 0xFFEEF1F8;
  static const int lightText = 0xFF121626;
  static const int lightTextMuted = 0xFF5A6482;
  static const int lightBorder = 0xFFD9DEEA;
  static const int lightCodeBackground = 0xFFF0F2F8;

  /// [argb] as a CSS hex colour, `#F5746F`.
  static String hex(int argb) =>
      '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// [argb] as a CSS `rgba(…)` with [alpha] from 0 to 1.
  static String rgba(int argb, double alpha) =>
      'rgba(${(argb >> 16) & 0xFF},${(argb >> 8) & 0xFF},${argb & 0xFF},$alpha)';
}

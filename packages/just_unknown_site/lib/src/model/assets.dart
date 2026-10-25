/// Where the package's pictures and fonts are, for Flutter (asset keys)
/// and for the static shell (the URLs Flutter web serves them at).
abstract final class JuAssets {
  /// This package's name, which prefixes its asset keys.
  static const String package = 'just_unknown_design';

  /// The Just Unknown logo.
  static const String logo =
      'packages/$package/assets/logo/just_unknown_logo.png';

  /// The Just Game Engine logo.
  static const String engineLogo =
      'packages/$package/assets/logo/just_game_engine_logo.png';

  /// The folder Flutter web serves the bundled fonts from, so the static
  /// shell's `@font-face` rules download each face once, shared with Flutter.
  static const String fontBase = '/assets/packages/$package/assets/fonts';

  /// The URL Flutter web serves the asset [key] at.
  static String url(String key) => '/assets/$key';
}

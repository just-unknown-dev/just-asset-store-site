import 'dart:io';
import 'dart:isolate';

import 'package:just_asset_store/just_asset_store.dart' show Sha256;

/// One face of the pages' fonts.
final class PageFont {
  PageFont._(this.family, this.weight, String stem, this.bytes)
    : path = 'static/fonts/$stem.${Sha256.hexOf(bytes).substring(0, 12)}.woff2';

  /// Its CSS family, as the shell's styles name it.
  final String family;
  final int weight;

  /// The WOFF2 file.
  final List<int> bytes;

  /// Where it is served, named by its content so it is cached for ever.
  final String path;
}

/// The static pages' fonts: the design's faces cut to the Latin characters
/// the pages use, as WOFF2 (`tool/subset_fonts.py` makes them, into
/// `lib/src/fonts/`), about a tenth of the size of the app's TTFs.
abstract final class PageFonts {
  static const List<(String, int, String)> _faces = [
    ('Inter', 400, 'Inter-Regular'),
    ('Inter', 500, 'Inter-Medium'),
    ('Inter', 600, 'Inter-SemiBold'),
    ('SpaceGrotesk', 500, 'SpaceGrotesk-Medium'),
    ('SpaceGrotesk', 700, 'SpaceGrotesk-Bold'),
    ('JetBrainsMono', 400, 'JetBrainsMono-Regular'),
  ];

  /// Their licences, served beside them.
  static const List<String> licences = [
    'OFL-Inter.txt',
    'OFL-SpaceGrotesk.txt',
    'OFL-JetBrainsMono.txt',
  ];

  /// The folder they are in, inside this package. Run from source (`dart
  /// run`, `dart test`), where the package config says where it is.
  static String get _dir {
    final uri = Isolate.resolvePackageUriSync(
      Uri.parse('package:just_asset_store_pages/src/fonts/'),
    );
    if (uri == null) {
      throw StateError(
        'The pages\' fonts can\'t be found: run the page builder from '
        'source (dart run bin/pages.dart).',
      );
    }
    return uri.toFilePath();
  }

  /// Every face.
  static final List<PageFont> all = [
    for (final (family, weight, stem) in _faces)
      PageFont._(
        family,
        weight,
        stem,
        File('$_dir$stem.woff2').readAsBytesSync(),
      ),
  ];

  /// Their `@font-face` rules.
  static String get css => [
    for (final f in all)
      "@font-face{font-family:'${f.family}';font-weight:${f.weight};"
          "font-display:swap;src:url(/${f.path}) format('woff2')}",
    '',
  ].join('\n');

  /// Every file to serve: the faces, and their licences.
  static Map<String, List<int>> files() => {
    for (final f in all) f.path: f.bytes,
    for (final l in licences)
      'static/fonts/$l': File('$_dir$l').readAsBytesSync(),
  };
}

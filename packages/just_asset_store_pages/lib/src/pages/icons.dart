import 'package:just_asset_store/just_asset_store.dart' show ItemKind;

/// The pages' icons: 24 px Material shapes drawn as CSS masks, so they take
/// the colour of the text around them (`currentColor`) in either theme, and
/// need no file and no inline style. `<span class="s-ico s-ico-puzzle">`.
abstract final class PageIcons {
  /// Each icon's SVG path, by name.
  static const Map<String, String> paths = {
    'person':
        'M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z',
    'landscape':
        'M14 6l-3.75 5 2.85 3.8-1.6 1.2C9.81 13.75 7 10 7 10l-6 8h22L14 6z',
    'grid':
        'M3 3v8h8V3H3zm6 6H5V5h4v4zm-6 4v8h8v-8H3zm6 6H5v-4h4v4zm4-16v8h8V3h-8zm6 6h-4V5h4v4zm-6 4v8h8v-8h-8zm6 6h-4v-4h4v4z',
    'box':
        'M20 2H4c-1 0-2 .9-2 2v3.01c0 .72.43 1.34 1 1.69V20c0 1.1 1.1 2 2 2h14c.9 0 2-.9 2-2V8.7c.57-.35 1-.97 1-1.69V4c0-1.1-1-2-2-2zm-5 12H9v-2h6v2zm5-7H4V4l16-.02V7z',
    'sparkle':
        'M19 9l1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9zm-7.5.5L9 4 6.5 9.5 1 12l5.5 2.5L9 20l2.5-5.5L17 12l-5.5-2.5zM19 15l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25L19 15z',
    'window':
        'M19 3H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.89-2-2-2zm0 16H5V7h14v12z',
    'music':
        'M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z',
    'text': 'M2.5 4v3h5v12h3V7h5V4h-13zm19 5h-9v3h3v7h3v-7h3V9z',
    'puzzle':
        'M20.5 11H19V7c0-1.1-.9-2-2-2h-4V3.5C13 2.12 11.88 1 10.5 1S8 2.12 8 3.5V5H4c-1.1 0-1.99.9-1.99 2v3.8H3.5c1.49 0 2.7 1.21 2.7 2.7s-1.21 2.7-2.7 2.7H2V20c0 1.1.9 2 2 2h3.8v-1.5c0-1.49 1.21-2.7 2.7-2.7 1.49 0 2.7 1.21 2.7 2.7V22H17c1.1 0 2-.9 2-2v-4h1.5c1.38 0 2.5-1.12 2.5-2.5S21.88 11 20.5 11z',
    'wrench':
        'M22.7 19l-9.1-9.1c.9-2.3.4-5-1.5-6.9-2-2-5-2.4-7.4-1.3L9 6 6 9 1.6 4.7C.4 7.1.9 10.1 2.9 12.1c1.9 1.9 4.6 2.4 6.9 1.5l9.1 9.1c.4.4 1 .4 1.4 0l2.3-2.3c.5-.4.5-1.1.1-1.4z',
    'dashboard': 'M3 3h8v8H3zm10 0h8v8h-8zM3 13h8v8H3zm15 0h-2v3h-3v2h3v3h2v-3h3v-2h-3z',
    'code':
        'M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z',
    'shapes':
        'M12 2l-5.5 9h11L12 2zm5.5 11c-2.49 0-4.5 2.01-4.5 4.5s2.01 4.5 4.5 4.5 4.5-2.01 4.5-4.5-2.01-4.5-4.5-4.5zM3 21.5h8v-8H3v8z',
    'image':
        'M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z',
    'terminal':
        'M20 4H4c-1.11 0-2 .9-2 2v12c0 1.1.89 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 14H4V8h16v10zm-2-1h-6v-2h6v2zM7.5 17l-1.41-1.41L8.67 13l-2.59-2.59L7.5 9l4 4-4 4z',
    'shield': 'M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4z',
    'editor':
        'M21 3H3c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h18c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm0 16H3V8h18v11zM5 10h5v7H5z',
  };

  /// The icon a category gets, by its id; else its items' kind's.
  static const Map<String, String> categories = {
    'characters': 'person',
    'environments': 'landscape',
    'tilesets': 'grid',
    'props': 'box',
    'effects': 'sparkle',
    'ui': 'window',
    'audio': 'music',
    'fonts': 'text',
    'kits': 'puzzle',
    'editors': 'wrench',
    'templates': 'dashboard',
    'libraries': 'code',
    'core': 'shapes',
  };

  /// The icon that stands for [kind] (a card without a picture shows it).
  static String forKind(ItemKind kind) => switch (kind) {
    ItemKind.content => 'image',
    ItemKind.editorExtension => 'wrench',
    ItemKind.kit => 'puzzle',
    ItemKind.runtimeLibrary => 'code',
    ItemKind.template => 'dashboard',
  };

  /// The icon [name] as markup: decorative, so hidden from screen readers.
  static String html(String name, {String extra = ''}) =>
      '<span class="s-ico s-ico-$name${extra.isEmpty ? '' : ' $extra'}" '
      'aria-hidden="true"></span>';

  /// Every icon's CSS rule.
  static String get css {
    final b = StringBuffer(
      '.s-ico{display:inline-block;width:24px;height:24px;flex:none;'
      'background:currentColor;-webkit-mask:var(--i) center/contain no-repeat;'
      'mask:var(--i) center/contain no-repeat}\n',
    );
    paths.forEach((name, d) {
      final svg =
          "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>"
          "<path d='$d'/></svg>";
      b.write('.s-ico-$name{--i:url("data:image/svg+xml,${_encode(svg)}")}\n');
    });
    return '$b';
  }

  /// [svg] safe inside a CSS `url("…")`.
  static String _encode(String svg) => svg
      .replaceAll('%', '%25')
      .replaceAll('<', '%3C')
      .replaceAll('>', '%3E')
      .replaceAll('#', '%23')
      .replaceAll('"', '%22');
}

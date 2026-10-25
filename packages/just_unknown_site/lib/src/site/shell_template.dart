/// Fills the marker slots in the built `index.html`.
final class ShellTemplate {
  /// The template [source]; throws when a marker is missing.
  ShellTemplate(this.source) {
    for (final m in const [
      headOpen,
      headClose,
      bodyOpen,
      bodyClose,
      cssOpen,
      cssClose,
      bootstrap,
    ]) {
      if (!source.contains(m)) {
        throw StateError(
          'index.html template is missing "$m". Check web/index.html.',
        );
      }
    }
  }

  static const headOpen = '<!--SEO_HEAD-->';
  static const headClose = '<!--/SEO_HEAD-->';
  static const bodyOpen = '<!--SEO_BODY-->';
  static const bodyClose = '<!--/SEO_BODY-->';
  static const cssOpen = '/*SHELL_CSS*/';
  static const cssClose = '/*/SHELL_CSS*/';
  static const bootstrap = 'flutter_bootstrap.js';

  /// The built `index.html`.
  final String source;

  /// The page with [head], [body] and [css] in their slots.
  String fill({
    required String head,
    required String body,
    required String css,
  }) {
    var out = source;
    out = _replaceBetween(out, headOpen, headClose, head);
    out = _replaceBetween(out, bodyOpen, bodyClose, body);
    out = _replaceBetween(out, cssOpen, cssClose, css);
    return out;
  }

  static String _replaceBetween(
    String s,
    String open,
    String close,
    String content,
  ) {
    final a = s.indexOf(open);
    final b = s.indexOf(close, a + open.length);
    if (a < 0 || b < 0) {
      throw StateError('Marker pair $open / $close not found.');
    }
    return '${s.substring(0, a)}$open\n$content\n$close'
        '${s.substring(b + close.length)}';
  }
}

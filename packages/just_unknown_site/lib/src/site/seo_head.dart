import 'dart:convert';

import 'html_escape.dart';
import 'site_identity.dart';

/// One extra `<meta>` tag: `property="…"` (Open Graph) or `name="…"`.
final class MetaTag {
  /// `<meta property="[key]" content="[content]">`.
  const MetaTag.property(this.key, this.content) : attribute = 'property';

  /// `<meta name="[key]" content="[content]">`.
  const MetaTag.name(this.key, this.content) : attribute = 'name';

  final String attribute;
  final String key;
  final String content;

  /// The tag.
  String render() =>
      '<meta $attribute="${esc(key)}" content="${esc(content)}">';
}

/// A page's `<head>` content: title, description, canonical, Open Graph,
/// Twitter, robots and a JSON-LD graph.
final class SeoHead {
  /// The head of the page at [path] on [site].
  const SeoHead({
    required this.site,
    required this.title,
    required this.description,
    required this.path,
    this.jsonLd,
    this.ogImage,
    this.ogType = 'website',
    this.noindex = false,
    this.meta = const [],
  });

  final SiteIdentity site;
  final String title;
  final String description;

  /// Its path, which makes its canonical URL.
  final String path;

  /// Its JSON-LD graph (see `JsonLd.graph`).
  final Map<String, Object?>? jsonLd;

  /// Its share picture: a path or a URL; the site's default when null.
  final String? ogImage;
  final String ogType;

  /// Keeps it out of search results.
  final bool noindex;

  /// Extra tags (`article:published_time`, say).
  final List<MetaTag> meta;

  String get canonical => site.absolute(path);
  String get ogImageUrl => site.absolute(ogImage ?? site.defaultOgImage);

  /// The tags, one per line.
  String render() {
    final robots = noindex
        ? 'noindex, nofollow'
        : 'index, follow, max-image-preview:large';
    final b = StringBuffer()
      ..writeln('  <title>${esc(title)}</title>')
      ..writeln('  <meta name="description" content="${esc(description)}">')
      ..writeln('  <meta name="robots" content="$robots">')
      ..writeln('  <link rel="canonical" href="${esc(canonical)}">')
      ..writeln('  <meta property="og:type" content="${esc(ogType)}">')
      ..writeln('  <meta property="og:site_name" content="${esc(site.name)}">')
      ..writeln('  <meta property="og:locale" content="${esc(site.ogLocale)}">')
      ..writeln('  <meta property="og:title" content="${esc(title)}">')
      ..writeln(
        '  <meta property="og:description" content="${esc(description)}">',
      )
      ..writeln('  <meta property="og:url" content="${esc(canonical)}">')
      ..writeln('  <meta property="og:image" content="${esc(ogImageUrl)}">')
      ..writeln('  <meta property="og:image:width" content="1200">')
      ..writeln('  <meta property="og:image:height" content="630">')
      ..writeln('  <meta name="twitter:card" content="summary_large_image">')
      ..writeln('  <meta name="twitter:title" content="${esc(title)}">')
      ..writeln(
        '  <meta name="twitter:description" content="${esc(description)}">',
      )
      ..writeln('  <meta name="twitter:image" content="${esc(ogImageUrl)}">');
    for (final m in meta) {
      b.writeln('  ${m.render()}');
    }
    final ld = jsonLd;
    if (ld != null) {
      b
        ..writeln('  <script type="application/ld+json">')
        ..writeln(
          escJsonForScript(const JsonEncoder.withIndent('  ').convert(ld)),
        )
        ..writeln('  </script>');
    }
    return b.toString();
  }
}

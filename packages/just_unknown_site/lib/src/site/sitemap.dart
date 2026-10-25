import 'html_escape.dart';
import 'site_identity.dart';

/// One `<url>` of a sitemap.
final class SitemapEntry {
  /// The page at [path], changed on [lastmod], ranked [priority] (0–1).
  const SitemapEntry(this.path, {required this.lastmod, this.priority = 0.5});

  final String path;
  final DateTime lastmod;
  final double priority;
}

/// `sitemap.xml` for [entries] on [site].
String buildSitemap(SiteIdentity site, List<SitemapEntry> entries) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">');
  for (final e in entries) {
    b
      ..writeln('  <url>')
      ..writeln('    <loc>${esc(site.absolute(e.path))}</loc>')
      ..writeln('    <lastmod>${isoDate(e.lastmod)}</lastmod>')
      ..writeln('    <priority>${e.priority.toStringAsFixed(1)}</priority>')
      ..writeln('  </url>');
  }
  b.writeln('</urlset>');
  return b.toString();
}

/// `robots.txt` for [site], keeping crawlers out of [disallow].
String buildRobots(
  SiteIdentity site, {
  List<String> disallow = const ['/404'],
}) {
  final b = StringBuffer()
    ..writeln('User-agent: *')
    ..writeln('Allow: /');
  for (final d in disallow) {
    b.writeln('Disallow: $d');
  }
  b
    ..writeln()
    ..writeln('Sitemap: ${site.absolute('/sitemap.xml')}');
  return b.toString();
}

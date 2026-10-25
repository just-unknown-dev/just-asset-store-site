import 'assets.dart';

/// Whether [href] leaves the site.
bool isExternalHref(String href) =>
    href.startsWith('http://') ||
    href.startsWith('https://') ||
    href.startsWith('mailto:');

/// The small picture drawn beside a link.
enum LinkGlyph { none, home, github, docs, mail, external }

/// A link: [label] going to [href]. Pure Dart, so the Flutter chrome and the
/// static shell draw the same links.
final class SiteLink {
  /// A link to [href]; [primary] draws it as the filled button among
  /// several.
  const SiteLink(
    this.label,
    this.href, {
    this.primary = false,
    this.glyph = LinkGlyph.none,
    this.also = const [],
  });

  /// What it says.
  final String label;

  /// Where it goes: a path on this site, or an `https:`/`mailto:` URL.
  final String href;

  /// Whether it is the main action among several.
  final bool primary;

  /// The picture beside it, where there is room for one.
  final LinkGlyph glyph;

  /// Other paths it is the navigation entry for, with what is under them
  /// (`/items` under "Browse", say).
  final List<String> also;

  /// Whether it leaves the site.
  bool get isExternal => isExternalHref(href);
}

/// A titled list of links in the footer.
final class FooterColumn {
  /// [links] under [title].
  const FooterColumn(this.title, this.links);

  /// The heading.
  final String title;

  /// The links, in order.
  final List<SiteLink> links;
}

/// What a site's chrome shows: its name, logo, navigation and footer.
final class SiteChrome {
  /// The chrome of the site called [name].
  const SiteChrome({
    required this.name,
    required this.tagline,
    required this.nav,
    this.home = '/',
    this.logoAsset = JuAssets.logo,
    this.iconLinks = const [],
    this.footer = const [],
    this.copyright = '',
  });

  /// The wordmark beside the logo.
  final String name;

  /// One line under the wordmark in the footer.
  final String tagline;

  /// Where the logo goes.
  final String home;

  /// The logo's asset key.
  final String logoAsset;

  /// The main navigation.
  final List<SiteLink> nav;

  /// Links drawn as icons beside the navigation (GitHub, say), and listed in
  /// the drawer.
  final List<SiteLink> iconLinks;

  /// The footer's link columns.
  final List<FooterColumn> footer;

  /// The footer's last line; `{year}` becomes the year.
  final String copyright;

  /// [copyright] for [year].
  String copyrightFor(int year) => copyright.replaceAll('{year}', '$year');

  /// The navigation entry [location] is in: the one with the longest href
  /// (or [SiteLink.also] path) that is a prefix of it. `/` is active only on
  /// `/` itself.
  SiteLink? activeFor(String location) {
    final path = location.split('?').first.split('#').first;
    bool under(String prefix) => prefix == '/'
        ? path == '/' || path.isEmpty
        : path == prefix ||
              path.startsWith(prefix.endsWith('/') ? prefix : '$prefix/');
    SiteLink? best;
    var bestLength = -1;
    for (final link in nav) {
      if (link.isExternal) continue;
      for (final prefix in [link.href, ...link.also]) {
        if (under(prefix) && prefix.length > bestLength) {
          best = link;
          bestLength = prefix.length;
        }
      }
    }
    return best;
  }
}

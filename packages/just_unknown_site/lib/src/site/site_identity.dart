/// [path] on the site at [base] as an absolute URL; full URLs pass through.
String absoluteUrl(String base, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  if (path.isEmpty || path == '/') return b;
  return path.startsWith('/') ? '$b$path' : '$b/$path';
}

/// [d] as `yyyy-mm-dd`.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Who runs a site, for its JSON-LD.
final class SiteOrganization {
  /// The organisation [name] at [url].
  const SiteOrganization({
    required this.name,
    required this.url,
    this.logoUrl,
    this.email,
    this.sameAs = const [],
    this.foundingYear,
    this.description,
  });

  final String name;

  /// Its home page, without a final `/`.
  final String url;

  /// An absolute URL of a square logo.
  final String? logoUrl;
  final String? email;

  /// Its other profiles (GitHub, pub.dev).
  final List<String> sameAs;
  final int? foundingYear;
  final String? description;

  /// Its JSON-LD node id.
  String get id => '$url/#organization';
}

/// A site's name, address and defaults for its `<head>`.
final class SiteIdentity {
  /// The site [name] at [baseUrl], run by [organization].
  const SiteIdentity({
    required this.name,
    required this.baseUrl,
    required this.description,
    required this.organization,
    this.locale = 'en',
    this.ogLocale = 'en_US',
    this.defaultOgImage = '/og/default.png',
  });

  final String name;

  /// Its address, without a final `/`.
  final String baseUrl;

  /// The description pages without their own use.
  final String description;
  final SiteOrganization organization;

  /// The `lang` of its pages.
  final String locale;

  /// Its `og:locale`.
  final String ogLocale;

  /// The share picture pages without their own use: a path or a URL.
  final String defaultOgImage;

  /// Its JSON-LD node id.
  String get id => '$baseUrl/#website';

  /// [path] on this site as an absolute URL.
  String absolute(String path) => absoluteUrl(baseUrl, path);

  /// The same site served from [base] instead (a preview channel).
  SiteIdentity at(String base) => SiteIdentity(
    name: name,
    baseUrl: base.endsWith('/') ? base.substring(0, base.length - 1) : base,
    description: description,
    organization: organization,
    locale: locale,
    ogLocale: ogLocale,
    defaultOgImage: defaultOgImage,
  );
}

import 'site_identity.dart';

/// JSON-LD graph builders. Everything returns plain maps; the caller encodes.
abstract final class JsonLd {
  /// [org] as an `Organization`.
  static Map<String, Object?> organization(SiteOrganization org) => {
    '@type': 'Organization',
    '@id': org.id,
    'name': org.name,
    'url': org.url,
    if (org.logoUrl != null)
      'logo': {
        '@type': 'ImageObject',
        'url': org.logoUrl,
        'width': 512,
        'height': 512,
      },
    'email': ?org.email,
    if (org.foundingYear != null) 'foundingDate': '${org.foundingYear}',
    if (org.sameAs.isNotEmpty) 'sameAs': org.sameAs,
    'description': ?org.description,
  };

  /// [site] as a `WebSite` its organisation publishes.
  static Map<String, Object?> website(SiteIdentity site) => {
    '@type': 'WebSite',
    '@id': site.id,
    'url': site.baseUrl,
    'name': site.name,
    'description': site.description,
    'publisher': {'@id': site.organization.id},
    'inLanguage': site.locale,
  };

  /// The page at [path] on [site]; [type] is its schema.org type
  /// (`WebPage`, `CollectionPage`, `AboutPage`…).
  static Map<String, Object?> webPage(
    SiteIdentity site,
    String path, {
    required String title,
    required String description,
    String type = 'WebPage',
  }) => {
    '@type': type,
    '@id': '${site.absolute(path)}/#webpage',
    'url': site.absolute(path),
    'name': title,
    'description': description,
    'isPartOf': {'@id': site.id},
    'about': {'@id': site.organization.id},
    'inLanguage': site.locale,
  };

  /// A `BreadcrumbList` of (name, path) pairs, outermost first.
  static Map<String, Object?> breadcrumbs(
    SiteIdentity site,
    List<(String, String)> trail,
  ) => {
    '@type': 'BreadcrumbList',
    'itemListElement': [
      for (var i = 0; i < trail.length; i++)
        {
          '@type': 'ListItem',
          'position': i + 1,
          'name': trail[i].$1,
          'item': site.absolute(trail[i].$2),
        },
    ],
  };

  /// An `ItemList` of (name, path) pairs, in order.
  static Map<String, Object?> itemList(
    SiteIdentity site,
    String path,
    List<(String, String)> entries,
  ) => {
    '@type': 'ItemList',
    '@id': '${site.absolute(path)}/#list',
    'numberOfItems': entries.length,
    'itemListElement': [
      for (var i = 0; i < entries.length; i++)
        {
          '@type': 'ListItem',
          'position': i + 1,
          'name': entries[i].$1,
          'url': site.absolute(entries[i].$2),
        },
    ],
  };

  /// The nodes as one graph.
  static Map<String, Object?> graph(List<Map<String, Object?>> nodes) => {
    '@context': 'https://schema.org',
    '@graph': nodes,
  };
}

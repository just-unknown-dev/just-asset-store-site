import 'access.dart';

/// What a page's `<head>` says.
final class PageHead {
  const PageHead({
    required this.title,
    required this.description,
    required this.path,
    this.noindex = false,
    this.ogImage,
  });

  final String title;
  final String description;

  /// Its canonical path.
  final String path;
  final bool noindex;

  /// Its share picture; the site's default when null.
  final String? ogImage;
}

/// The store's URLs.
///
/// The site is static pages built from the catalog, with a small Flutter
/// app for what needs signing in: Publish, a report, and My packages
/// ([appPaths]). A link from the app to any other page loads that page.
/// Every page is one file at the top of its folder (`report.html`, not
/// `publish/report.html` beside `publish.html`), so Cloudflare Pages serves
/// each path from exactly one file.
abstract final class StoreRoutes {
  static const String homePath = '/';
  static const String searchPath = '/search';
  static const String policyPath = '/policy';
  static const String publishPath = '/publish';
  static const String reportPath = '/report';
  static const String minePath = '/me';

  static String item(String id) => '/items/$id';
  static String category(String id) => '/categories/$id';
  static String publisher(String id) => '/publishers/$id';

  /// The pages the publish app draws.
  static const List<String> appPaths = [publishPath, reportPath, minePath];

  /// Whether [location] is one of the publish app's pages.
  static bool isAppPath(String location) =>
      appPaths.contains(normalize(location));

  /// The location's path without its query, fragment or final `/`.
  static String normalize(String location) {
    var p = location.split('?').first.split('#').first;
    if (p.isEmpty) return '/';
    while (p.length > 1 && p.endsWith('/')) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }

  static const _site = 'Just Asset Store';

  static const PageHead home = PageHead(
    title: 'Just Asset Store — art, kits and tools for the Just Game Engine',
    description:
        'Art, genre kits, editor tools and project templates for the Just Game '
        'Engine. Every package installs with one command, or from the editor’s '
        'store window.',
    path: homePath,
  );

  static const PageHead search = PageHead(
    title: 'Search — $_site',
    description: 'Search every package in the Just Asset Store.',
    path: searchPath,
  );

  static const PageHead publish = PageHead(
    title: 'Publish a package — $_site',
    description:
        'Release your package on GitHub, submit its repository here, and the '
        'store checks it and lists it for every Just Game Engine developer.',
    path: publishPath,
    // Not offered to everyone yet: kept out of search results.
    noindex: !StoreAccess.openPublishing,
  );

  static const PageHead report = PageHead(
    title: 'Report a package — $_site',
    description: 'Tell the store’s maintainers about a package.',
    path: reportPath,
    noindex: true,
  );

  static const PageHead mine = PageHead(
    title: 'My packages — $_site',
    description: 'The packages you submitted to the Just Asset Store.',
    path: minePath,
    noindex: true,
  );

  static const PageHead policy = PageHead(
    title: 'Content policy — $_site',
    description:
        'What may be listed in the Just Asset Store, how packages are checked, '
        'and how to report one.',
    path: policyPath,
  );

  static const PageHead notFound = PageHead(
    title: 'Page not found — $_site',
    description: 'The page you were looking for does not exist.',
    path: '/404',
    noindex: true,
  );

  /// The head of the publish app's page at [location]; [notFound] for
  /// anything else.
  static PageHead appHead(String location) => switch (normalize(location)) {
    publishPath => publish,
    reportPath => report,
    minePath => mine,
    _ => notFound,
  };
}

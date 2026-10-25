import 'package:just_unknown_site/just_unknown_site.dart';

import 'access.dart';
import 'links.dart';
import 'routes.dart';

/// The store's identity and chrome, the same on the static pages and in
/// the publish app.
abstract final class StoreMeta {
  static const String name = 'Just Asset Store';
  static const String baseUrl = 'https://store.justunknown.com';
  static const String tagline =
      'Art, kits and editor tools for the Just Game Engine, installed with one '
      'command.';
  static const String description =
      'The Just Asset Store: art, genre kits, editor tools and project '
      'templates for the Just Game Engine. Install any of them with one '
      'command, or from the editor’s store window.';

  /// The `localStorage` key of the theme choice (`just_storage:` + this),
  /// which the static pages and the app share.
  static const String themeKey = 'theme_mode';

  static const SiteIdentity identity = SiteIdentity(
    name: name,
    baseUrl: baseUrl,
    description: description,
    defaultOgImage: '/og/default.png',
    organization: SiteOrganization(
      name: 'Just Unknown',
      url: StoreLinks.justUnknown,
      logoUrl:
          '${StoreLinks.justUnknown}/assets/assets/logo/just_unknown_logo.png',
      email: StoreLinks.email,
      sameAs: [StoreLinks.githubOrg],
      foundingYear: 2026,
    ),
  );

  static const SiteChrome chrome = SiteChrome(
    name: name,
    tagline: tagline,
    nav: [
      SiteLink(
        'Browse',
        StoreRoutes.homePath,
        also: ['/items', '/categories', '/publishers', StoreRoutes.searchPath],
      ),
      // Not offered while only Just Unknown publishes (StoreAccess); the
      // page is still at /publish for its account.
      if (StoreAccess.openPublishing)
        SiteLink(
          'Publish',
          StoreRoutes.publishPath,
          also: [StoreRoutes.minePath, StoreRoutes.reportPath],
        ),
      SiteLink('Policy', StoreRoutes.policyPath),
    ],
    iconLinks: [
      SiteLink('GitHub', StoreLinks.githubOrg, glyph: LinkGlyph.github),
    ],
    footer: [
      FooterColumn('Store', [
        SiteLink('Browse packages', StoreRoutes.homePath),
        SiteLink('Search', StoreRoutes.searchPath),
        if (StoreAccess.openPublishing) ...[
          SiteLink('Publish a package', StoreRoutes.publishPath),
          SiteLink('My packages', StoreRoutes.minePath),
        ],
        SiteLink('Content policy', StoreRoutes.policyPath),
      ]),
      FooterColumn('Just Unknown', [
        SiteLink('justunknown.com', StoreLinks.justUnknown),
        SiteLink('Just Game Engine', StoreLinks.engine),
        SiteLink('Engine docs', StoreLinks.engineDocs),
        SiteLink('The just CLI', StoreLinks.justCli),
        SiteLink('GitHub', StoreLinks.githubOrg),
      ]),
    ],
    copyright:
        '© {year} Just Unknown. Packages belong to their publishers and come '
        'under their own licences.',
  );
}

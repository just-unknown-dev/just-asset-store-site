import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../content/labels.dart';
import '../content/routes.dart';
import '../content/site_meta.dart';
import 'page_html.dart' show safeHref;
import 'store_catalog_view.dart';

/// Each static page's `<head>`, with a JSON-LD graph.
final class PageSeo {
  /// Heads for the store at [site] (its own address by default; a preview
  /// deploy's otherwise).
  const PageSeo([this.site = StoreMeta.identity]);

  final SiteIdentity site;

  static const String _name = StoreMeta.name;

  List<Map<String, Object?>> get _base => [
    JsonLd.organization(site.organization),
    JsonLd.website(site),
  ];

  SeoHead _head(
    PageHead h,
    List<Map<String, Object?>> nodes, {
    String type = 'WebPage',
  }) => SeoHead(
    site: site,
    title: h.title,
    description: h.description,
    path: h.path,
    noindex: h.noindex,
    ogImage: h.ogImage,
    jsonLd: JsonLd.graph([
      ..._base,
      JsonLd.webPage(
        site,
        h.path,
        title: h.title,
        description: h.description,
        type: type,
      ),
      ...nodes,
    ]),
  );

  static List<(String, String)> _list(Iterable<StoreItem> items) => [
    for (final i in items) (i.name, StoreRoutes.item(i.id)),
  ];

  SeoHead home(StoreCatalogView c) => _head(StoreRoutes.home, [
    JsonLd.itemList(site, StoreRoutes.homePath, _list(c.recent)),
  ], type: 'CollectionPage');

  SeoHead search() => _head(StoreRoutes.search, const [], type: 'SearchResultsPage');

  SeoHead policy() => _head(StoreRoutes.policy, const []);

  /// The head of a publish-app page, written into its static shell.
  SeoHead app(PageHead h) => _head(h, const []);

  SeoHead category(StoreCatalogView c, StoreCategory cat) {
    final items = c.inCategory(cat.id);
    final h = PageHead(
      title: '${cat.label} — $_name',
      description:
          '${cat.label} for the Just Game Engine: ${items.length} '
          '${items.length == 1 ? 'package' : 'packages'}, each installed with '
          'one command.',
      path: StoreRoutes.category(cat.id),
    );
    return _head(h, [
      JsonLd.itemList(site, h.path, _list(items)),
      JsonLd.breadcrumbs(site, [('Browse', '/'), (cat.label, h.path)]),
    ], type: 'CollectionPage');
  }

  SeoHead publisher(StorePublisherView p) {
    final h = PageHead(
      title: '${p.id} — $_name',
      description:
          'Packages by ${p.id} in the Just Asset Store: ${p.items.length} '
          '${p.items.length == 1 ? 'package' : 'packages'}.',
      path: StoreRoutes.publisher(p.id),
    );
    return _head(h, [
      JsonLd.itemList(site, h.path, _list(p.items)),
      JsonLd.breadcrumbs(site, [('Browse', '/'), (p.id, h.path)]),
    ], type: 'ProfilePage');
  }

  SeoHead item(StoreItem i, StoreCatalogView c) {
    final kind = kindLabel(i.kind);
    final h = PageHead(
      title: '${i.name} — $kind for the Just Game Engine | $_name',
      description: i.summary.isEmpty
          ? '${i.name}, a ${kind.toLowerCase()} for the Just Game Engine.'
          : i.summary,
      path: StoreRoutes.item(i.id),
      ogImage: c.pictureUrl(i.thumbnail),
    );
    final cat = c.index.category(i.category);
    final latest = i.latest;
    final updated = c.updated(i);
    final url = site.absolute(h.path);
    return _head(h, [
      {
        '@type': 'SoftwareApplication',
        '@id': '$url/#software',
        'name': i.name,
        'description': i.description ?? i.summary,
        'url': url,
        'applicationCategory': 'DeveloperApplication',
        'applicationSubCategory': kind,
        'operatingSystem': i.kind == ItemKind.editorExtension
            ? 'Windows, macOS, Linux'
            : 'Android, iOS, Web, Windows, macOS, Linux',
        if (latest != null) 'softwareVersion': '${latest.version}',
        if (updated != null) 'dateModified': isoDate(updated),
        if (i.license != null)
          'license': 'https://spdx.org/licenses/${i.license!.spdx}.html',
        if (i.tags.isNotEmpty) 'keywords': i.tags.join(', '),
        if (c.pictureUrl(i.thumbnail) case final String image)
          'image': site.absolute(image),
        if (safeHref(i.sourceRepo) case final String repo) 'sameAs': repo,
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD'},
        if (i.author != null)
          'author': {
            '@type': 'Organization',
            'name': i.author!.name,
            'url': ?safeHref(i.author!.url),
          },
        'publisher': {'@type': 'Organization', 'name': i.publisher},
      },
      JsonLd.breadcrumbs(site, [
        ('Browse', '/'),
        if (cat != null) (cat.label, StoreRoutes.category(cat.id)),
        (i.name, h.path),
      ]),
    ]);
  }

  /// The page of an item the store took down: kept for old links, out of
  /// search results.
  SeoHead removed(RemovedItem r) => _head(
    PageHead(
      title: '${r.id} was taken down — $_name',
      description: 'The store took ${r.id} down: ${r.reason}',
      path: StoreRoutes.item(r.id),
      noindex: true,
    ),
    const [],
  );

  SeoHead notFound() => SeoHead(
    site: site,
    title: StoreRoutes.notFound.title,
    description: StoreRoutes.notFound.description,
    path: StoreRoutes.notFound.path,
    noindex: true,
    jsonLd: JsonLd.graph(_base),
  );
}

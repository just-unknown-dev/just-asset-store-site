import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../content/access.dart';
import '../content/routes.dart';
import '../content/site_meta.dart';
import 'assets.dart';
import 'cloudflare.dart';
import 'fonts.dart';
import 'page_html.dart';
import 'page_seo.dart';
import 'search_index.dart';
import 'store_catalog_view.dart';

/// The store's static site, built from its catalog: a page for the home,
/// search, the policy, every category, item and publisher (and every item
/// the store took down), `404.html`, `search.json`, the pages' CSS and
/// script, `sitemap.xml`, `robots.txt`, and Cloudflare Pages' `_headers`
/// and `_redirects`. Pure: [files] is a map, written by `SiteBuild`.
final class StorePages {
  /// The pages of [index], for the store at [site] (its own address unless
  /// a preview deploy's), dated [buildDate] where nothing newer is known.
  StorePages(
    StoreIndex index, {
    SiteIdentity site = StoreMeta.identity,
    DateTime? buildDate,
  }) : view = StoreCatalogView(index),
       seo = PageSeo(site),
       buildDate = buildDate ?? DateTime.now().toUtc();

  final StoreCatalogView view;
  final PageSeo seo;
  final DateTime buildDate;

  /// The file the page at [routePath] is served from: `/items/x` is
  /// `items/x.html`, which Cloudflare Pages serves at `/items/x` itself.
  static String fileFor(String routePath) => routePath == '/'
      ? 'index.html'
      : '${StoreRoutes.normalize(routePath).substring(1)}.html';

  /// Every file, by its path from the site's root.
  Map<String, String> files() {
    final c = view;
    final year = buildDate.year;
    final out = <String, String>{};
    void page(String path, SeoHead head, String main) =>
        out[fileFor(path)] = pageDocument(
          head: head,
          location: path,
          main: main,
          year: year,
        );

    page(StoreRoutes.homePath, seo.home(c), PageHtml.home(c));
    page(StoreRoutes.searchPath, seo.search(), PageHtml.search());
    page(StoreRoutes.policyPath, seo.policy(), PageHtml.policy());
    for (final cat in c.usedCategories) {
      page(
        StoreRoutes.category(cat.id),
        seo.category(c, cat),
        PageHtml.category(c, cat),
      );
    }
    for (final i in c.items) {
      page(StoreRoutes.item(i.id), seo.item(i, c), PageHtml.item(i, c));
    }
    for (final p in c.publishers) {
      page(StoreRoutes.publisher(p.id), seo.publisher(p), PageHtml.publisher(c, p));
    }
    for (final r in c.removedOnly) {
      page(StoreRoutes.item(r.id), seo.removed(r), PageHtml.removed(r));
    }
    out['404.html'] = pageDocument(
      head: seo.notFound(),
      location: '/404',
      main: PageHtml.notFound(),
      year: year,
    );
    out['search.json'] = SearchIndex.of(c);
    out[PageAssets.css.path] = PageAssets.css.text;
    out[PageAssets.js.path] = PageAssets.js.text;
    out['sitemap.xml'] = buildSitemap(seo.site, sitemap());
    out['robots.txt'] = buildRobots(
      seo.site,
      disallow: ['/404', StoreRoutes.minePath, StoreRoutes.reportPath],
    );
    out['_headers'] = CloudflareFiles.headers;
    out['_redirects'] = CloudflareFiles.redirects;
    return out;
  }

  /// The files that aren't text: the pages' fonts, by path.
  Map<String, List<int>> binaryFiles() => PageFonts.files();

  /// The publish app's pages, from its built `index.html` ([template],
  /// with the shell's slots): each with its own `<head>`, and the chrome
  /// and hero it draws, shown until the app does.
  Map<String, String> appPages(String template) {
    final shell = ShellTemplate(template);
    final year = buildDate.year;
    return {
      for (final path in StoreRoutes.appPaths)
        fileFor(path): shell.fill(
          head: seo.app(StoreRoutes.appHead(path)).render(),
          body:
              '${PageHtml.header(path)}<main id="main">'
              '${PageHtml.appShell(path)}</main>'
              '${ShellHtml.footer(StoreMeta.chrome, year: year)}',
          css: PageAssets.css.text,
        ),
    };
  }

  /// Every page search engines should know, with when it last changed.
  List<SitemapEntry> sitemap() {
    final c = view;
    DateTime newest(Iterable<StoreItem> items) =>
        items
            .map(c.updated)
            .whereType<DateTime>()
            .fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a) ??
        buildDate;
    return [
      SitemapEntry('/', lastmod: newest(c.items), priority: 1),
      SitemapEntry(StoreRoutes.searchPath, lastmod: newest(c.items), priority: 0.6),
      for (final cat in c.usedCategories)
        SitemapEntry(
          StoreRoutes.category(cat.id),
          lastmod: newest(c.inCategory(cat.id)),
          priority: 0.8,
        ),
      for (final i in c.items)
        SitemapEntry(
          StoreRoutes.item(i.id),
          lastmod: c.updated(i) ?? buildDate,
          priority: 0.9,
        ),
      for (final p in c.publishers)
        SitemapEntry(
          StoreRoutes.publisher(p.id),
          lastmod: newest(p.items),
          priority: 0.5,
        ),
      if (StoreAccess.openPublishing)
        SitemapEntry(StoreRoutes.publishPath, lastmod: buildDate, priority: 0.6),
      SitemapEntry(StoreRoutes.policyPath, lastmod: buildDate, priority: 0.4),
    ];
  }
}

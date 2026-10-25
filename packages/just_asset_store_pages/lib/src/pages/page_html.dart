import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../content/access.dart';
import '../content/copy.dart';
import '../content/labels.dart';
import '../content/links.dart';
import '../content/routes.dart';
import '../content/site_meta.dart';
import 'assets.dart';
import 'icons.dart';
import 'store_catalog_view.dart';

/// [url] when it is one a page may link to (`https:`, or `http:`), else
/// null: catalog text is plain text, not checked as a link.
String? safeHref(String? url) {
  if (url == null) return null;
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? '$uri' : null;
}

/// A whole static page: its `<head>` ([SeoHead]), the store's CSS and
/// script, the chrome, and [main].
String pageDocument({
  required SeoHead head,
  required String location,
  required String main,
  required int year,
}) {
  final b = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="${esc(head.site.locale)}">')
    ..writeln('<head>')
    ..writeln('  <meta charset="utf-8">')
    ..writeln(
      '  <meta name="viewport" content="width=device-width, initial-scale=1">',
    )
    ..writeln(
      '  <meta http-equiv="Content-Security-Policy" '
      'content="${esc(PageAssets.contentSecurityPolicy)}">',
    )
    ..writeln(
      '  <meta name="theme-color" '
      'content="${JuPalette.hex(JuPalette.background)}">',
    )
    ..writeln('  <script>${PageAssets.themeScript}</script>')
    ..writeln('  <link rel="stylesheet" href="${PageAssets.css.href}">')
    ..writeln(
      '  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">',
    )
    ..writeln(
      '  <link rel="icon" type="image/png" sizes="48x48" href="/favicon.png">',
    )
    ..writeln('  <link rel="apple-touch-icon" href="/apple-touch-icon.png">')
    ..writeln('  <script src="${PageAssets.js.href}" defer></script>')
    ..write(head.render())
    ..writeln('</head>')
    ..writeln('<body class="s-page">')
    ..write(PageHtml.header(location))
    ..write('<main id="main">$main</main>')
    ..write(ShellHtml.footer(StoreMeta.chrome, year: year))
    ..writeln()
    ..writeln('</body>')
    ..writeln('</html>');
  return '$b';
}

/// The bodies of the static pages.
abstract final class PageHtml {
  static const SiteChrome _chrome = StoreMeta.chrome;

  /// The header: brand, navigation ([location]'s entry marked), the theme
  /// switch, and a menu for narrow screens that works without script.
  static String header(String location) {
    final active = _chrome.activeFor(location);
    String links() => [
      for (final l in _chrome.nav)
        '<a href="${esc(l.href)}"'
            '${identical(l, active) ? ' aria-current="page"' : ''}'
            '${ShellHtml.ext(l.href)}>${esc(l.label)}</a>',
      for (final l in _chrome.iconLinks) ShellHtml.a(l.label, l.href),
    ].join();
    return '<a class="s-skip" href="#main">Skip to content</a>'
        '<header class="s-wrap s-header">'
        '<a class="s-brand" href="${esc(_chrome.home)}">'
        '<img src="${esc(JuAssets.url(_chrome.logoAsset))}" alt="" width="28" '
        'height="28">${esc(_chrome.name)}</a>'
        '<div class="s-tools">'
        '<nav class="s-nav" aria-label="Main">${links()}</nav>'
        '<button type="button" class="s-theme" data-theme-toggle '
        'aria-label="Switch between light and dark">Theme</button>'
        '<details class="s-menu"><summary>Menu</summary>'
        '<nav aria-label="Menu">${links()}</nav></details>'
        '</div></header>';
  }

  static String _searchForm({String query = ''}) =>
      '<form class="s-search" action="${StoreRoutes.searchPath}" method="get" '
      'role="search"><label class="s-sr" for="home-q">Search packages'
      '</label><input id="home-q" name="q" type="search" '
      'placeholder="${esc(SearchCopy.placeholder)}" value="${esc(query)}">'
      '<button type="submit">Search</button></form>';

  static String _command(String command) =>
      '<div class="s-cmd"><pre class="s-code"><code>${esc(command)}</code>'
      '</pre><button type="button" class="s-copy-btn" '
      'data-copy="${esc(command)}">Copy</button></div>';

  // ── Home ─────────────────────────────────────────────────────────────────

  /// The shelves to show after the newest: one per kind, each leading to
  /// every package of its kind.
  static const List<(ItemKind, String)> _kindShelves = [
    (ItemKind.editorExtension, HomeCopy.toolsTitle),
    (ItemKind.kit, HomeCopy.kitsTitle),
    (ItemKind.content, HomeCopy.artTitle),
    (ItemKind.template, HomeCopy.templatesTitle),
  ];

  /// The home page: a search, the featured packages, the categories, then a
  /// shelf of the newest and one per kind, and how the store works.
  static String home(StoreCatalogView c) {
    final b = StringBuffer()
      ..write(
        ShellHtml.hero(
          eyebrow: HomeCopy.eyebrow,
          title: HomeCopy.title,
          lede: HomeCopy.lede,
          actions: const [
            if (StoreAccess.openPublishing)
              SiteLink('Publish a package', StoreRoutes.publishPath),
          ],
          extra: _searchForm(),
        ).replaceFirst('class="s-hero"', 'class="s-hero s-hero-home"'),
      );
    if (c.items.isEmpty) {
      b.write(
        ShellHtml.section(
          title: 'Nothing is listed yet',
          body: StoreAccess.openPublishing
              ? 'The store is open for packages. Be the first to publish one.'
              : 'Just Unknown’s first packages are on their way.',
        ),
      );
    } else {
      if (c.featured.isNotEmpty) b.write(_featured(c));
      b
        ..write(_categoryTiles(c))
        ..write(
          _shelf(
            c,
            HomeCopy.recentTitle,
            c.recent,
            '${StoreRoutes.searchPath}?sort=updated',
          ),
        );
      for (final (kind, title) in _kindShelves) {
        b.write(
          _shelf(
            c,
            title,
            c.newest(4, kind: kind),
            '${StoreRoutes.searchPath}?kind=${kind.id}',
          ),
        );
      }
    }
    b
      ..write(
        ShellHtml.section(
          eyebrow: HomeCopy.howEyebrow,
          title: HomeCopy.howTitle,
          content: '<div class="s-grid">${HomeCopy.how.map(_point).join()}</div>',
        ),
      )
      ..write(
        ShellHtml.section(
          title: HomeCopy.cliTitle,
          body: HomeCopy.cliBody,
          content:
              '${_command(StoreLinks.justCliInstall)}'
              '<p>${ShellHtml.more(const SiteLink('just on pub.dev', StoreLinks.justCli))}</p>',
        ),
      );
    return '$b';
  }

  /// The first featured package as a banner, the others as cards under it.
  static String _featured(StoreCatalogView c) {
    final first = c.featured.first;
    final rest = c.featured.skip(1).toList();
    final gallery = c.galleryOf(first);
    final b = StringBuffer()
      ..write(
        '<section class="s-shelf s-featured" aria-labelledby="featured-h">'
        '<div class="s-wrap"><h2 id="featured-h" class="s-sr">'
        '${esc(HomeCopy.featuredTitle)}</h2>',
      )
      ..write(
        '<a class="s-banner" href="${StoreRoutes.item(first.id)}">'
        '${_pic(first, gallery.isEmpty ? null : gallery.first, eager: true, width: 1280, height: 720)}'
        '<span class="s-banner-body">'
        '<span class="s-eyebrow">${esc(HomeCopy.featuredTitle)}</span>'
        '${_badges(first)}<h3>${esc(first.name)}</h3>'
        '<span class="s-sum">${esc(first.summary)}</span>'
        '<span class="s-meta">${esc(_meta(first))}</span>'
        '<span class="s-btn primary s-go">${esc(HomeCopy.seeIt)} &rarr;</span>'
        '</span></a>',
      );
    if (rest.isNotEmpty) {
      b.write(
        '<div class="s-row s-row-${rest.length}">'
        '${rest.map((i) => card(c, i)).join()}</div>',
      );
    }
    b.write('</div></section>');
    return '$b';
  }

  /// A tile with its icon for each category that holds something.
  static String _categoryTiles(StoreCatalogView c) {
    final b = StringBuffer()
      ..write(
        '<section class="s-shelf"><div class="s-wrap"><div class="s-shelf-head">'
        '<h2>${esc(HomeCopy.categoriesTitle)}</h2></div><div class="s-tiles">',
      );
    for (final cat in c.usedCategories) {
      final n = c.inCategory(cat.id).length;
      b.write(
        '<a class="s-tile" href="${StoreRoutes.category(cat.id)}">'
        '${PageIcons.html(c.iconFor(cat))}'
        '<span class="s-tile-name">${esc(cat.label)}</span>'
        '<span class="s-count">$n ${n == 1 ? 'package' : 'packages'}</span></a>',
      );
    }
    b.write('</div></div></section>');
    return '$b';
  }

  /// A row of [items] under [title], with "See all" leading to [all];
  /// nothing when there are none.
  static String _shelf(
    StoreCatalogView c,
    String title,
    List<StoreItem> items,
    String all,
  ) {
    if (items.isEmpty) return '';
    return '<section class="s-shelf"><div class="s-wrap"><div class="s-shelf-head">'
        '<h2>${esc(title)}</h2>'
        '${ShellHtml.more(SiteLink(HomeCopy.seeAll, all))}</div>'
        '<div class="s-row">${items.map((i) => card(c, i)).join()}</div>'
        '</div></section>';
  }

  // ── Lists ────────────────────────────────────────────────────────────────

  static String search() {
    final kinds = [
      '<option value="">All kinds</option>',
      for (final k in ItemKind.values)
        '<option value="${esc(k.id)}">${esc(kindLabel(k))}</option>',
    ].join();
    return '${ShellHtml.hero(eyebrow: 'Browse', title: SearchCopy.title, lede: SearchCopy.lede)}'
        '<section class="s-section"><div class="s-wrap">'
        '<form id="search-form" class="s-search" action="${StoreRoutes.searchPath}" '
        'method="get" role="search"><label class="s-sr" for="search-q">'
        'Search packages</label><input id="search-q" name="q" type="search" '
        'placeholder="${esc(SearchCopy.placeholder)}">'
        '<button type="submit">Search</button></form>'
        '<div class="s-filters">'
        '<label>Kind<select id="search-kind" name="kind">$kinds</select></label>'
        '<label>Order<select id="search-sort" name="sort">'
        '<option value="name">Name</option>'
        '<option value="updated">Recently updated</option></select></label>'
        '<label class="s-check"><input type="checkbox" id="search-exp" '
        'name="experimental" value="1"> Show experimental</label>'
        '</div>'
        '<p id="search-status" class="s-status" role="status" aria-live="polite"></p>'
        '<div id="search-results" class="s-grid s-cards" '
        'data-empty="${esc(SearchCopy.empty)}"></div>'
        '<noscript><p class="s-notice">${esc(SearchCopy.noScript)}</p></noscript>'
        '</div></section>';
  }

  static String category(StoreCatalogView c, StoreCategory cat) {
    final items = c.inCategory(cat.id);
    final n = items.length;
    return '${ShellHtml.hero(eyebrow: 'Category', title: cat.label, lede: '$n ${n == 1 ? 'package' : 'packages'} for the Just Game Engine, each installed with one command.')}'
        '<section class="s-section"><div class="s-wrap">'
        '${_chips(c, cat.id)}${_grid(c, items)}</div></section>';
  }

  static String publisher(StoreCatalogView c, StorePublisherView p) {
    final n = p.items.length;
    final github = p.githubUrl;
    return '${ShellHtml.hero(eyebrow: 'Publisher', title: p.id, lede: '${sourceLabel(p.trust)} publisher. $n ${n == 1 ? 'package' : 'packages'} in the store.', actions: [if (github != null) SiteLink('On GitHub', github)])}'
        '<section class="s-section"><div class="s-wrap">'
        '${_grid(c, p.items)}</div></section>';
  }

  // ── An item ──────────────────────────────────────────────────────────────

  /// An item's page: its pictures, a panel beside them (what it is, how to
  /// install it, the facts), and below them what it does and its versions.
  static String item(StoreItem i, StoreCatalogView c) {
    final cat = c.index.category(i.category);
    final b = StringBuffer()
      ..write('<article class="s-item"><div class="s-wrap">')
      ..write('<p class="s-crumbs"><a href="/">Browse</a>');
    if (cat != null) {
      b.write(
        ' › <a href="${StoreRoutes.category(cat.id)}">${esc(cat.label)}</a>',
      );
    }
    b
      ..write(' › ${esc(i.name)}</p>')
      ..write('<div class="s-item-grid">')
      ..write(_gallery(i, c))
      ..write(_panel(i, c))
      ..write('<div class="s-item-body">')
      ..write(_body(i, c))
      ..write('</div></div></div></article>');
    return '$b';
  }

  static String _pictureAlt(StoreItem i, int n, int of) =>
      of == 1 ? 'A picture of ${i.name}' : 'Picture $n of $of: ${i.name}';

  /// The item's main picture, and a strip to pick another (script swaps
  /// them in place; without it, each opens).
  static String _gallery(StoreItem i, StoreCatalogView c) {
    final pictures = c.galleryOf(i);
    if (pictures.isEmpty) {
      return '<div class="s-gallery">${_pic(i, null)}</div>';
    }
    final b = StringBuffer()
      ..write(
        '<div class="s-gallery"><span class="s-pic">'
        '<img id="gallery-main" src="${esc(pictures.first)}" '
        'alt="${esc(_pictureAlt(i, 1, pictures.length))}" width="1280" '
        'height="720"></span>',
      );
    if (pictures.length > 1) {
      b.write('<ul class="s-strip" aria-label="Pictures">');
      for (var n = 0; n < pictures.length; n++) {
        final alt = _pictureAlt(i, n + 1, pictures.length);
        b.write(
          '<li><a href="${esc(pictures[n])}" data-gallery '
          'data-alt="${esc(alt)}"${n == 0 ? ' aria-current="true"' : ''}>'
          '<img src="${esc(pictures[n])}" alt="${esc(alt)}" width="160" '
          'height="90" loading="lazy"></a></li>',
        );
      }
      b.write('</ul>');
    }
    b.write('</div>');
    return '$b';
  }

  /// What it is, how to install it, and the facts: beside the pictures,
  /// staying in view as the page scrolls.
  static String _panel(StoreItem i, StoreCatalogView c) {
    final latest = i.latest;
    final b = StringBuffer()
      ..write('<aside class="s-panel" aria-label="Install and details">')
      ..write('<p class="s-eyebrow">${esc(kindLabel(i.kind))}</p>')
      ..write('<h1>${esc(i.name)}</h1>');
    if (i.summary.isNotEmpty) {
      b.write('<p class="s-panel-sum">${esc(i.summary)}</p>');
    }
    b
      ..write('<div class="s-badges">')
      ..write(
        '<span class="s-badge">${esc(i.unavailable ? 'Unavailable' : sourceLabel(i.trust))}</span>',
      );
    if (stageBadge(i.stage) case final stage?) {
      b.write('<span class="s-badge s-stage">${esc(stage)}</span>');
    }
    if (latest != null) {
      b.write('<span class="s-badge">v${esc('${latest.version}')}</span>');
    }
    b.write('</div>');
    if (i.unavailable) {
      b.write(
        '<p class="s-notice warn">This package is unavailable: its repository '
        'was removed or changed hands. Copies already installed keep working; '
        'nothing new installs.</p>',
      );
    } else if (latest == null) {
      b.write(
        '<p class="s-notice warn">No version of this package can be '
        'installed now: each one was withdrawn or taken down.</p>',
      );
    }
    switch (i.stage) {
      case ItemStage.experimental:
        b.write(
          '<p class="s-notice warn">Experimental: it may change or break '
          'between versions.</p>',
        );
      case ItemStage.deprecated:
        final by = i.replacedBy;
        final next = by == null ? null : c.index.item(by);
        b.write(
          '<p class="s-notice warn">Deprecated: it is no longer developed.'
          '${by == null ? '' : ' Use ${next == null ? '<code>${esc(by)}</code>' : ShellHtml.a(next.name, StoreRoutes.item(by))} instead.'}'
          '</p>',
        );
      case ItemStage.stable || ItemStage.beta || null:
        break;
    }
    if (i.trust != TrustLevel.official) {
      b.write(
        '<p class="s-notice">A community package: checked by the store’s '
        'automatic tests, not reviewed by a person. Read what it does before '
        'you install it.</p>',
      );
    }
    if (!i.unavailable && latest != null) b.write(_install(i));
    b
      ..write(_facts(i, c))
      ..write('</aside>');
    return '$b';
  }

  /// Installing it: from the editor or with the just tool, a tab each
  /// (radio buttons, so it works without script).
  static String _install(StoreItem i) {
    final cli =
        '${_command(installCommand(i))}'
        '<p class="s-hint">${esc(ItemCopy.cliHint)} ${esc(ItemCopy.noJust)} '
        '${ShellHtml.a(ItemCopy.getJust, StoreLinks.justCli)}: '
        '<code>${esc(StoreLinks.justCliInstall)}</code></p>';
    final head =
        '<div class="s-install"><h2 class="s-install-h">'
        '${esc(ItemCopy.installTitle)}</h2>';
    // A project template starts a project: only the just tool does that.
    if (i.kind == ItemKind.template) return '$head$cli</div>';
    final steps = ItemCopy.editorSteps(i.name).map((s) => '<li>${esc(s)}</li>');
    return '$head<div class="s-tabs">'
        '<input type="radio" name="install-how" id="how-editor" checked>'
        '<label for="how-editor">${esc(ItemCopy.editorTab)}</label>'
        '<input type="radio" name="install-how" id="how-cli">'
        '<label for="how-cli">${esc(ItemCopy.cliTab)}</label>'
        '<div class="s-pane s-pane-editor"><ol class="s-mini-steps">'
        '${steps.join()}</ol></div>'
        '<div class="s-pane s-pane-cli">$cli</div>'
        '</div></div>';
  }

  /// The facts: version, dates, sizes, licence, people, what it needs.
  static String _facts(StoreItem i, StoreCatalogView c) {
    final latest = i.latest;
    final archive = latest?.archive;
    final updated = c.updated(i);
    final author = i.author;
    final authorUrl = safeHref(author?.url);
    final source = safeHref(i.sourceRepo);
    final discussion = safeHref(i.discussionUrl);
    final license = i.license;
    final rows = <(String, String)>[
      if (latest != null) ('Version', '<code>${esc('${latest.version}')}</code>'),
      if (updated != null) ('Updated', isoDate(updated)),
      if (archive != null) ('Download', sizeLabel(archive.size)),
      if (archive?.unpackedSize case final int unpacked)
        ('Installed', sizeLabel(unpacked)),
      if (license != null)
        (
          'Licence',
          '<code>${esc(license.spdx)}</code>'
              '${license.attribution == null ? '' : '<br>Credit: ${esc(license.attribution!)}'}',
        ),
      if (author != null)
        (
          'Author',
          authorUrl == null ? esc(author.name) : ShellHtml.a(author.name, authorUrl),
        ),
      (
        'Publisher',
        c.hasPublisherPage(i.publisher)
            ? ShellHtml.a(i.publisher, StoreRoutes.publisher(i.publisher))
            : esc(i.publisher),
      ),
      if (c.index.category(i.category) case final cat?)
        ('Category', ShellHtml.a(cat.label, StoreRoutes.category(cat.id))),
      ('Id', '<code>${esc(i.id)}</code>'),
      if (latest != null && latest.requires.isNotEmpty)
        (
          'Needs',
          latest.requires.entries
              .map((e) => '<code>${esc('${e.key} ${e.value}')}</code>')
              .join('<br>'),
        ),
      if (latest != null && latest.dependencies.isNotEmpty)
        (
          'Depends on',
          latest.dependencies.entries
              .map(
                (e) => c.index.item(e.key) == null
                    ? '<code>${esc('${e.key} ${e.value}')}</code>'
                    : ShellHtml.a(
                        '${c.index.item(e.key)!.name} ${e.value}',
                        StoreRoutes.item(e.key),
                      ),
              )
              .join('<br>'),
        ),
      if (latest != null && latest.pubDependencies.isNotEmpty)
        (
          'From pub.dev',
          latest.pubDependencies.entries
              .map(
                (e) => '${ShellHtml.a(e.key, StoreLinks.pub(e.key))} '
                    '<code>${esc('${e.value}')}</code>',
              )
              .join('<br>'),
        ),
      if (archive != null)
        (
          'SHA-256',
          '<span class="s-sha">${esc(archive.sha256)}</span> '
              '<button type="button" class="s-copy-btn" '
              'data-copy="${esc(archive.sha256)}">Copy</button>',
        ),
    ];
    final b = StringBuffer()..write('<dl class="s-facts">');
    for (final (k, v) in rows) {
      b.write('<dt>${esc(k)}</dt><dd>$v</dd>');
    }
    b.write('</dl><div class="s-panel-links">');
    if (source != null) {
      b.write(ShellHtml.button(SiteLink('View source', source)));
    }
    if (discussion != null) {
      b.write(ShellHtml.more(SiteLink('Discussion', discussion)));
    }
    b
      ..write(ShellHtml.more(SiteLink('Report this package', StoreLinks.report(i.id))))
      ..write('</div>');
    final users = c.dependents(i.id);
    if (users.isNotEmpty) {
      b
        ..write('<p class="s-hint"><b>Used by</b> ')
        ..write(
          users.map((u) => ShellHtml.a(u.name, StoreRoutes.item(u.id))).join(', '),
        )
        ..write('</p>');
    }
    return '$b';
  }

  /// Under the pictures: about it, its tags, what it does, and its
  /// versions.
  static String _body(StoreItem i, StoreCatalogView c) {
    final latest = i.latest;
    final b = StringBuffer();
    if (i.description != null) {
      b.write(
        '<h2>About</h2><p class="s-body s-body-text">${esc(i.description!)}</p>',
      );
    }
    if (i.tags.isNotEmpty) {
      b.write('<nav class="s-chips s-tags" aria-label="Tags">');
      for (final t in i.tags) {
        b.write(
          '<a href="${StoreRoutes.searchPath}?q=${esc(Uri.encodeQueryComponent(t))}">'
          '#${esc(t)}</a>',
        );
      }
      b.write('</nav>');
    }
    if (i.kind == ItemKind.runtimeLibrary && i.pubPackage != null) {
      b.write(
        '<p class="s-hint">It comes from pub.dev: '
        '${ShellHtml.a(i.pubPackage!, StoreLinks.pub(i.pubPackage!))}.</p>',
      );
    }
    if (latest != null && latest.permissions.isNotEmpty) {
      b
        ..write('<h2>What it does</h2><ul class="s-perms">')
        ..write(
          [
            for (final p in ItemPermission.values)
              if (latest.permissions.contains(p)) '<li>${esc(p.label)}</li>',
          ].join(),
        )
        ..write(
          '</ul><p class="s-hint">As it declares. The store shows this before '
          'every install.</p>',
        );
    }
    if (latest != null && latest.nativePlugins.isNotEmpty) {
      final plugins = latest.nativePlugins
          .map((p) => '<code>${esc(p)}</code>')
          .join(', ');
      b.write(
        '<h2>Native code</h2><p class="s-body">It brings Flutter plugins with '
        'native code: $plugins. '
        '${i.kind == ItemKind.editorExtension ? 'Installed on its own, it is a dev dependency, so release builds leave them out.' : 'They build into every version of the game.'}'
        '</p>',
      );
    }
    b.write('<h2>Versions</h2><ul class="s-versions">');
    for (final v in [...i.versions]..sort((a, b) => b.version.compareTo(a.version))) {
      b.write('<li><div class="s-vhead"><code>${esc('${v.version}')}</code>');
      if (v.published != null) {
        b.write('<span class="s-meta">${isoDate(v.published!)}</span>');
      }
      if (v.archive != null) {
        b.write('<span class="s-meta">${sizeLabel(v.archive!.size)}</span>');
      }
      if (stageBadge(v.stage) case final stage?) {
        b.write('<span class="s-badge s-stage">${esc(stage)}</span>');
      }
      if (v.blocked) {
        b.write('<span class="s-badge">Taken down</span>');
      } else if (v.yanked) {
        b.write('<span class="s-badge">Withdrawn</span>');
      }
      b.write('</div>');
      if (v.notes != null) {
        b.write('<p class="s-vnotes s-body-text">${esc(v.notes!)}</p>');
      }
      b.write('</li>');
    }
    b.write('</ul>');
    return '$b';
  }

  // ── Other pages ──────────────────────────────────────────────────────────

  static String removed(RemovedItem r) => ShellHtml.hero(
    eyebrow: 'Taken down',
    title: r.id,
    lede: 'The store took this package down: ${r.reason}',
    actions: const [
      SiteLink('Browse packages', StoreRoutes.homePath, primary: true),
    ],
    extra:
        '<p class="s-notice">Copies already installed keep working, and '
        'projects that have it are warned. Nothing new installs.</p>',
  );

  static String policy() {
    final b = StringBuffer()
      ..write(
        ShellHtml.hero(
          eyebrow: PolicyCopy.eyebrow,
          title: PolicyCopy.title,
          lede: PolicyCopy.lede,
        ),
      )
      ..write('<div class="s-wrap"><div class="s-prose">');
    if (PolicyCopy.draft) {
      b.write('<p class="s-notice warn">${esc(PolicyCopy.draftNotice)}</p>');
    }
    for (final s in PolicyCopy.sections) {
      b.write('<h2>${esc(s.heading)}</h2>');
      for (final p in s.paragraphs) {
        b.write('<p>${esc(p)}</p>');
      }
      if (s.bullets.isNotEmpty) {
        b.write('<ul>${s.bullets.map((x) => '<li>${esc(x)}</li>').join()}</ul>');
      }
    }
    b.write('</div></div>');
    return '$b';
  }

  static String notFound() => ShellHtml.hero(
    eyebrow: '404',
    title: 'Page not found',
    lede: 'The page you were looking for does not exist. The package may have '
        'been renamed or taken down.',
    actions: const [
      SiteLink('Browse packages', StoreRoutes.homePath, primary: true),
      SiteLink('Search', StoreRoutes.searchPath),
    ],
  );

  /// What the publish app's page at [path] shows until the app draws:
  /// the same hero, and what the page is for.
  static String appShell(String path) => switch (path) {
    StoreRoutes.publishPath => ShellHtml.hero(
      eyebrow: PublishCopy.eyebrow,
      title: PublishCopy.title,
      lede: PublishCopy.lede,
    ),
    StoreRoutes.reportPath => ShellHtml.hero(
      eyebrow: ReportCopy.eyebrow,
      title: ReportCopy.title,
      lede: ReportCopy.lede,
    ),
    _ => ShellHtml.hero(
      eyebrow: MineCopy.eyebrow,
      title: MineCopy.title,
      lede: MineCopy.lede,
    ),
  };

  // ── Pieces ───────────────────────────────────────────────────────────────

  static String _chips(StoreCatalogView c, String? active) {
    String chip(String label, String href, bool on) =>
        '<a href="$href"${on ? ' aria-current="page"' : ''}>${esc(label)}</a>';
    return '<nav class="s-chips" aria-label="Categories">'
        '${chip('All', StoreRoutes.searchPath, active == null)}'
        '${c.usedCategories.map((x) => chip(x.label, StoreRoutes.category(x.id), x.id == active)).join()}'
        '</nav>';
  }

  static String _grid(StoreCatalogView c, List<StoreItem> items) {
    if (items.isEmpty) {
      return '<p class="s-body">Nothing is listed here yet.</p>';
    }
    return '<div class="s-grid s-cards">${items.map((i) => card(c, i)).join()}</div>';
  }

  /// A 16:9 picture at [url], or [i]'s kind's icon when it has none.
  static String _pic(
    StoreItem i,
    String? url, {
    bool eager = false,
    int width = 640,
    int height = 360,
  }) => url == null
      ? '<span class="s-pic s-ph">${PageIcons.html(PageIcons.forKind(i.kind))}</span>'
      : '<span class="s-pic"><img src="${esc(url)}" alt="" width="$width" '
            'height="$height"${eager ? '' : ' loading="lazy"'}></span>';

  /// Where [i] comes from and how finished it is.
  static String _badges(StoreItem i) =>
      '<span class="s-badges">'
      '<span class="s-badge">${esc(i.unavailable ? 'Unavailable' : sourceLabel(i.trust))}</span>'
      '${switch (stageBadge(i.stage)) {
        final stage? => '<span class="s-badge s-stage">${esc(stage)}</span>',
        null => '',
      }}</span>';

  /// Its kind, newest version and publisher.
  static String _meta(StoreItem i) => [
    kindLabel(i.kind),
    if (i.latest case final v?) 'v${v.version}',
    i.publisher,
  ].join(' · ');

  /// [i]'s card: its picture (or its kind's icon), source and stage, name,
  /// summary, kind, version and publisher.
  static String card(StoreCatalogView c, StoreItem i) =>
      '<a class="s-card s-pcard" href="${StoreRoutes.item(i.id)}">'
      '${_pic(i, c.pictureUrl(i.thumbnail))}'
      '<span class="s-pbody">${_badges(i)}'
      '<h3>${esc(i.name)}</h3><span class="s-sum">${esc(i.summary)}</span>'
      '<span class="s-meta">${esc(_meta(i))}</span></span></a>';

  static String _point(CopyPoint p) =>
      '<div class="s-card s-point">'
      '${p.icon == null || !PageIcons.paths.containsKey(p.icon) ? '' : PageIcons.html(p.icon!)}'
      '<h3>${esc(p.title)}</h3><p>${esc(p.body)}</p>'
      '${p.code == null ? '' : '<pre class="s-code"><code>${esc(p.code!)}</code></pre>'}'
      '</div>';
}

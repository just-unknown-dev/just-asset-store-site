// The static pages: what each shows, that catalog text never becomes
// markup, and the files Cloudflare Pages needs.
import 'dart:convert';
import 'dart:io';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_asset_store_pages/just_asset_store_pages.dart';
import 'package:just_unknown_site/just_unknown_site.dart' show esc;
import 'package:test/test.dart';

import 'support/catalog.dart';

void main() {
  final index = testCatalog();
  final pages = StorePages(index, buildDate: DateTime.utc(2026, 10, 23));
  final files = pages.files();

  test('a page for everything, at the path Cloudflare Pages serves it', () {
    expect(StorePages.fileFor('/'), 'index.html');
    expect(StorePages.fileFor('/items/x'), 'items/x.html');
    expect(StorePages.fileFor('/report/'), 'report.html');
    expect(
      files.keys,
      containsAll([
        'index.html',
        'search.html',
        'policy.html',
        '404.html',
        'categories/characters.html',
        'categories/kits.html',
        'categories/libraries.html',
        'items/just_art_knight.html',
        'items/their_kit.html',
        'items/just_tiled.html',
        'items/gone_kit.html',
        'items/bad_pack.html',
        'publishers/octocat.html',
        'publishers/just.html',
        'search.json',
        'sitemap.xml',
        'robots.txt',
        '_headers',
        '_redirects',
        PageAssets.css.path,
        PageAssets.js.path,
      ]),
    );
    expect(files, isNot(contains('categories/empty.html')));
    // A publisher name that isn't a GitHub login gets no page.
    expect(files.keys.where((k) => k.contains('evil')), isEmpty);
  });

  test('an item page shows what the catalog says about it', () {
    final knight = files['items/just_art_knight.html']!;
    for (final text in [
      '<h1>Knight</h1>',
      'A pixel knight with run and attack clips.',
      'v1.1.0',
      'Official',
      'just add just_art_knight',
      'data-copy="just add just_art_knight"',
      shaB,
      '2.5 MB',
      '4.1 MB',
      'CC-BY-4.0',
      'Credit: Art by Just Unknown',
      'just_game_engine ^2.0.0',
      'Withdrawn',
      'An attack clip.',
      'href="/report?item=just_art_knight"',
      'href="https://pub.dev/packages/just_core_cli"',
      'href="/categories/characters"',
      'href="https://github.com/just-unknown-dev/knight"',
      'Eight animations.\nAll at 32 px.',
      'Used by',
      // Its pictures: the first large, a strip to pick one.
      '<img id="gallery-main" src="/previews/fedcba9876543210.jpg" '
          'alt="Picture 1 of 2: Knight"',
      'href="https://github.com/just-unknown-dev/knight/releases/download/v1.1.0/run.png" '
          'data-gallery data-alt="Picture 2 of 2: Knight"',
      // Installing it: from the editor, or the command line.
      '<input type="radio" name="install-how" id="how-editor" checked>',
      '<label for="how-cli">Command line</label>',
      'Search for “Knight” and press Install.',
      // Its tags lead to a search.
      'href="/search?q=pixel-art">#pixel-art</a>',
    ]) {
      expect(knight, contains(text), reason: text);
    }
    expect(RegExp('data-gallery ').allMatches(knight), hasLength(2));
    // One picture: no strip. None: its kind's icon.
    final fresh = files['items/their_new_kit.html']!;
    expect(fresh, isNot(contains('data-gallery')));
    expect(fresh, contains('<span class="s-pic s-ph"><span class="s-ico s-ico-puzzle"'));

    final kit = files['items/their_kit.html']!;
    for (final text in [
      'Third Party',
      '<span class="s-badge s-stage">Beta</span>',
      'not reviewed by a person',
      'What it does',
      'Connects to the internet',
      'Brings native code (Flutter plugins)',
      '<code>camera_x</code>',
      'They build into every version of the game.',
      'href="https://pub.dev/packages/nice_lib"',
      'href="/items/just_art_knight"',
      'href="/publishers/octocat"',
    ]) {
      expect(kit, contains(text), reason: text);
    }

    final lib = files['items/just_tiled.html']!;
    expect(lib, contains('It comes from pub.dev'));
    expect(lib, contains('href="https://pub.dev/packages/just_tiled"'));

    expect(files['items/gone_kit.html'], contains('This package is unavailable'));
    expect(
      files['items/bad_pack.html'],
      allOf(contains('It held a stolen tileset.'), contains('noindex')),
    );
  });

  test('catalog text never becomes markup, and only web links are links', () {
    for (final e in files.entries) {
      if (!e.key.endsWith('.html')) continue;
      final html = e.value;
      expect(html, isNot(contains('<script>alert')), reason: e.key);
      expect(html, isNot(contains('<img src=x')), reason: e.key);
      expect(html, isNot(contains('javascript:')), reason: e.key);
    }
    final sneaky = files['items/sneaky.html']!;
    expect(sneaky, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    // Mallory's name stays, without her link; the bad source isn't linked.
    expect(sneaky, contains('Mallory'));
    expect(sneaky, isNot(contains('View source')));
    expect(sneaky, contains('evil/../x'));
    expect(sneaky, isNot(contains('href="/publishers/evil')));
  });

  test('every static page carries the policy, which allows its script', () {
    final hash = PageAssets.themeScriptHash;
    expect(hash, matches(RegExp(r"^'sha256-[A-Za-z0-9+/]{43}='$")));
    for (final e in files.entries) {
      if (!e.key.endsWith('.html')) continue;
      final html = e.value;
      expect(html, contains('http-equiv="Content-Security-Policy"'), reason: e.key);
      expect(html, contains(esc(hash)), reason: e.key);
      expect(html, contains('<script>${PageAssets.themeScript}</script>'));
      expect(html, contains('src="${PageAssets.js.href}" defer'));
      expect(html, contains('href="${PageAssets.css.href}"'));
      // The only inline script is the theme's.
      final inline = RegExp(r'<script>').allMatches(html).length;
      expect(inline, 1, reason: e.key);
    }
    // Content-hashed names: the same text, the same name.
    expect(PageAssets.css.path, matches(RegExp(r'^static/store\.[0-9a-f]{12}\.css$')));
    // The pages' own small fonts, not the app's.
    expect(PageAssets.css.text, isNot(contains('.ttf')));
    final fonts = pages.binaryFiles();
    expect(fonts.keys.where((k) => k.endsWith('.woff2')), hasLength(6));
    expect(fonts.keys, contains('static/fonts/OFL-Inter.txt'));
    for (final f in PageFonts.all) {
      expect(PageAssets.css.text, contains('url(/${f.path})'));
      expect(f.bytes.length, lessThan(40 * 1024), reason: f.path);
    }
  });

  test('the home page: search, featured, categories, then shelves', () {
    final home = files['index.html']!;
    expect(home, contains('action="/search"'));
    // Featured: the first a banner, the rest cards; nothing experimental,
    // and nothing the catalog doesn't list.
    expect(home, contains('<a class="s-banner" href="/items/their_kit">'));
    final featured = home.substring(
      home.indexOf('class="s-shelf s-featured"'),
      home.indexOf('Browse by category'),
    );
    expect(featured, contains('href="/items/just_art_knight"'));
    expect(featured, isNot(contains('their_new_kit')));
    expect(featured, isNot(contains('missing_one')));
    // Category tiles, with their icons.
    expect(
      home,
      contains(
        '<a class="s-tile" href="/categories/kits"><span class="s-ico s-ico-puzzle"',
      ),
    );
    expect(home, contains('<span class="s-ico s-ico-person"'));
    expect(home, contains('2 packages'));
    // Shelves: the newest, then one per kind, each leading to all of it.
    expect(home, contains('New &amp; updated'));
    expect(home, contains('href="/search?sort=updated"'));
    expect(home, contains('Genre kits'));
    expect(home, contains('href="/search?kind=kit"'));
    expect(home, contains('href="/search?kind=content"'));
    // No shelf for a kind with nothing offered.
    expect(home, isNot(contains('href="/search?kind=template"')));
    expect(home, contains('dart pub global activate just_core_cli'));
    // Newest first on its shelf: the kit (10 Oct) before the knight (1 Oct).
    final shelf = home.substring(home.indexOf('New &amp; updated'));
    expect(
      shelf.indexOf('href="/items/their_kit"'),
      lessThan(shelf.indexOf('href="/items/just_art_knight"')),
    );
  });

  test("icons are masks the page's policy allows", () {
    final css = PageAssets.css.text;
    expect(css, contains('.s-ico{'));
    expect(css, contains('.s-ico-puzzle{--i:url("data:image/svg+xml,%3Csvg'));
    expect(PageAssets.contentSecurityPolicy, contains("img-src 'self' https: data:"));
    expect(PageAssets.js.text, contains('data-gallery'));
    expect(files['_headers'], contains('/previews/*\n  Cache-Control: public, max-age=31536000, immutable'));
  });

  test('search.json lists what can be installed, in short keys', () {
    final json = jsonDecode(files['search.json']!) as Map<String, Object?>;
    expect(json['v'], 1);
    final items = (json['items']! as List).cast<Map<String, Object?>>();
    expect(items.map((i) => i['id']), isNot(contains('gone_kit')));
    final kit = items.firstWhere((i) => i['id'] == 'their_kit');
    expect(kit, {
      'id': 'their_kit',
      'n': 'Their Kit',
      's': 'Platformer bits.',
      'k': 'kit',
      'kl': 'Kit',
      'c': 'kits',
      'p': 'octocat',
      't': <Object?>[],
      'tr': 'Third Party',
      'st': 'beta',
      'stl': 'Beta',
      'v': '0.2.0',
      'u': '2026-10-10',
    });
    expect(
      items.firstWhere((i) => i['id'] == 'just_art_knight')['th'],
      '/thumbs/0123456789abcdef.jpg',
    );
    expect(files['search.html'], contains('id="search-results"'));
  });

  test('experimental and deprecated items: said, and not offered first', () {
    final fresh = files['items/their_new_kit.html']!;
    expect(fresh, contains('<span class="s-badge s-stage">Experimental</span>'));
    expect(fresh, contains('Experimental: it may change or break'));
    final old = files['items/their_old_kit.html']!;
    expect(old, contains('Deprecated: it is no longer developed.'));
    expect(old, contains('Use <a href="/items/their_kit">Their Kit</a> instead.'));
    // The newest on the home page are neither, though they came out last.
    final home = files['index.html']!;
    expect(home, isNot(contains('href="/items/their_new_kit"')));
    expect(home, isNot(contains('href="/items/their_old_kit"')));
    // The category lists the experimental one (with its badge), not the
    // deprecated one.
    final kits = files['categories/kits.html']!;
    expect(kits, contains('href="/items/their_new_kit"'));
    expect(kits, isNot(contains('href="/items/their_old_kit"')));
    // Search has both, marked, for the page's own rules to hide.
    final items = ((jsonDecode(files['search.json']!) as Map)['items']! as List)
        .cast<Map<String, Object?>>();
    Map<String, Object?> one(String id) => items.firstWhere((i) => i['id'] == id);
    expect(one('their_new_kit')['st'], 'experimental');
    expect(one('their_old_kit')['rb'], 'their_kit');
    expect(one('just_tiled'), isNot(contains('st')));
    expect(files['search.html'], contains('id="search-exp"'));
    expect(PageAssets.js.text, contains("i.st === 'experimental' && !experimental.checked"));
  });

  test('sitemap, robots, headers and redirects', () {
    final sitemap = files['sitemap.xml']!;
    expect(sitemap, contains('<loc>https://asset.justunknown.com/items/their_kit</loc>'));
    expect(sitemap, contains('<lastmod>2026-10-10</lastmod>'));
    expect(sitemap, isNot(contains('bad_pack')));
    expect(files['robots.txt'], contains('Disallow: /me'));
    final headers = files['_headers']!;
    expect(headers, contains('/catalog/*\n  Cache-Control: public, max-age=31536000, immutable'));
    expect(headers, contains('/index.json\n  Cache-Control: public, max-age=60, must-revalidate'));
    expect(headers, contains('X-Content-Type-Options: nosniff'));
    expect(files['_redirects'], contains('/items /search 301'));
  });

  test("the publish app's pages, from its built index.html", () {
    final template = File('../../web/index.html').readAsStringSync();
    final app = pages.appPages(template);
    expect(app.keys, ['publish.html', 'report.html', 'me.html']);
    // No page shares a name with a folder: each path is one file.
    final all = {...files.keys, ...app.keys};
    for (final f in all.where((f) => f.endsWith('.html'))) {
      final folder = f.substring(0, f.length - '.html'.length);
      expect(all.any((g) => g.startsWith('$folder/')), isFalse, reason: f);
    }
    expect(app['publish.html'], contains('<title>Publish a package'));
    expect(app['report.html'], contains('noindex'));
    expect(app['me.html'], contains('My packages'));
    expect(app['publish.html'], contains('flutter_bootstrap.js'));
    expect(app['publish.html'], contains(PublishCopy.title));
    expect(
      files['sitemap.xml']!.contains('/publish<'),
      StoreAccess.openPublishing,
    );
  });

  test('a preview deploy names its own address', () {
    final preview = StorePages(
      index,
      site: StoreMeta.identity.at('https://abc.just-asset-store.pages.dev'),
    ).files();
    expect(
      preview['items/their_kit.html'],
      contains('href="https://abc.just-asset-store.pages.dev/items/their_kit"'),
    );
  });

  test('an empty catalog still makes a site', () {
    final empty = StorePages(
      StoreIndex(
        source: const StoreSourceInfo('just-official', 'Just Asset Store'),
        categories: const [],
        items: const [],
      ),
    ).files();
    expect(empty['index.html'], contains('Nothing is listed yet'));
    expect(jsonDecode(empty['search.json']!), containsPair('items', isEmpty));
  });
}

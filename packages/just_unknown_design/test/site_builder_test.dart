import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:just_unknown_design/just_unknown_design.dart' show JuColors, JuColorsLight;
import 'package:just_unknown_design/site_builder.dart';

const _site = SiteIdentity(
  name: 'Test Site',
  baseUrl: 'https://example.com',
  description: 'A test site.',
  organization: SiteOrganization(name: 'Org', url: 'https://org.example'),
);

const _chrome = SiteChrome(
  name: 'Test Site',
  tagline: 'Tests & more',
  nav: [
    SiteLink('Home', '/'),
    SiteLink('Items', '/items', also: ['/things']),
    SiteLink('Docs', 'https://docs.example'),
  ],
  footer: [
    FooterColumn('More', [SiteLink('About', '/about')]),
  ],
  copyright: '© {year} Org.',
);

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

void main() {
  test('the site builder is a package without Flutter', () {
    // tool/ scripts and the page generator run it on the plain Dart VM: as
    // a package of its own that doesn't depend on Flutter, it can't use it.
    final pubspec = File('../just_unknown_site/pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter')));
    expect(
      File('lib/site_builder.dart').readAsStringSync(),
      contains("export 'package:just_unknown_site/just_unknown_site.dart';"),
    );
  });

  test('the Flutter colours and the shell CSS share one palette', () {
    final css = shellCss();
    for (final c in [
      JuColors.primary,
      JuColors.background,
      JuColors.surface,
      JuColors.text,
      JuColors.border,
      JuColorsLight.background,
      JuColorsLight.text,
      JuColorsLight.primary,
      JuColorsLight.onPrimary,
    ]) {
      expect(css, contains(_hex(c)));
    }
    expect(JuPalette.hex(JuPalette.primary), '#F5746F');
    expect(JuPalette.rgba(JuPalette.primary, .2), 'rgba(245,116,111,0.2)');
  });

  test('the CSS loads every bundled face from where Flutter serves it', () {
    final css = shellCss(extra: '.mine{}');
    for (final f in [
      'SpaceGrotesk-Bold',
      'SpaceGrotesk-Medium',
      'Inter-Regular',
      'Inter-Medium',
      'Inter-SemiBold',
      'JetBrainsMono-Regular',
    ]) {
      expect(css, contains('${JuAssets.fontBase}/$f.ttf'));
      expect(File('assets/fonts/$f.ttf').existsSync(), isTrue, reason: f);
    }
    expect(css, contains('#static-shell.is-hidden'));
    expect(css.trimRight(), endsWith('.mine{}'));
  });

  test('the logo asset exists where the key says', () {
    final path = JuAssets.logo.replaceFirst('packages/${JuAssets.package}/', '');
    expect(File(path).existsSync(), isTrue);
    expect(JuAssets.url(JuAssets.logo), startsWith('/assets/packages/'));
  });

  group('SiteChrome', () {
    test('picks the longest matching entry; / only matches itself', () {
      expect(_chrome.activeFor('/')?.label, 'Home');
      expect(_chrome.activeFor('/items')?.label, 'Items');
      expect(_chrome.activeFor('/items/a_b?x=1')?.label, 'Items');
      expect(_chrome.activeFor('/itemsx'), isNull);
      expect(_chrome.activeFor('/about'), isNull);
      expect(_chrome.activeFor('/things/x')?.label, 'Items');
    });

    test('fills the year into the copyright line', () {
      expect(_chrome.copyrightFor(2030), '© 2030 Org.');
    });
  });

  group('SeoHead', () {
    test('escapes text and builds absolute URLs', () {
      final head = SeoHead(
        site: _site,
        title: 'A <b> & "c"',
        description: 'd',
        path: '/items/x',
        noindex: true,
        meta: const [MetaTag.property('article:tag', 'x')],
        jsonLd: JsonLd.graph([
          JsonLd.website(_site),
          {'name': '</script><script>'},
        ]),
      ).render();
      expect(head, contains('<title>A &lt;b&gt; &amp; &quot;c&quot;</title>'));
      expect(head, contains('href="https://example.com/items/x"'));
      expect(head, contains('content="https://example.com/og/default.png"'));
      expect(head, contains('noindex, nofollow'));
      expect(head, contains('<meta property="article:tag" content="x">'));
      expect(head, isNot(contains('</script><script>')));
    });

    test('absolute URLs join cleanly and pass full URLs through', () {
      expect(absoluteUrl('https://a.b/', '/'), 'https://a.b');
      expect(absoluteUrl('https://a.b', 'x/y'), 'https://a.b/x/y');
      expect(absoluteUrl('https://a.b', 'https://c.d/e'), 'https://c.d/e');
      expect(_site.at('https://preview.example/').baseUrl, 'https://preview.example');
    });
  });

  test('ShellHtml draws the chrome with the current entry marked', () {
    final header = ShellHtml.header(_chrome, location: '/items/a');
    expect(header, contains('<a href="/items" aria-current="page">Items</a>'));
    expect(header, contains('href="https://docs.example" rel="noopener" target="_blank"'));
    final footer = ShellHtml.footer(_chrome, year: 2031);
    expect(footer, contains('Tests &amp; more'));
    expect(footer, contains('<h4>More</h4><a href="/about">About</a>'));
    expect(footer, contains('© 2031 Org.'));
  });

  test('sitemap and robots', () {
    final xml = buildSitemap(_site, [
      SitemapEntry('/', lastmod: DateTime.utc(2026, 1, 2), priority: 1),
    ]);
    expect(xml, contains('<loc>https://example.com</loc>'));
    expect(xml, contains('<lastmod>2026-01-02</lastmod>'));
    expect(xml, contains('<priority>1.0</priority>'));
    final robots = buildRobots(_site, disallow: ['/404', '/me']);
    expect(robots, contains('Disallow: /me'));
    expect(robots, contains('Sitemap: https://example.com/sitemap.xml'));
  });

  group('ShellTemplate', () {
    const html =
        '<style>/*SHELL_CSS*//*/SHELL_CSS*/</style><!--SEO_HEAD-->old<!--/SEO_HEAD-->'
        '<div><!--SEO_BODY--><!--/SEO_BODY--></div><script src="flutter_bootstrap.js"></script>';

    test('fills every slot', () {
      final out = ShellTemplate(html).fill(head: 'H', body: 'B', css: 'C');
      expect(out, contains('<!--SEO_HEAD-->\nH\n<!--/SEO_HEAD-->'));
      expect(out, contains('<!--SEO_BODY-->\nB\n<!--/SEO_BODY-->'));
      expect(out, contains('/*SHELL_CSS*/\nC\n/*/SHELL_CSS*/'));
      expect(out, isNot(contains('old')));
    });

    test('refuses a template without its markers', () {
      expect(() => ShellTemplate('<html></html>'), throwsStateError);
    });
  });
}

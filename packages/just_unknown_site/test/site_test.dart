import 'package:just_unknown_site/just_unknown_site.dart';
import 'package:test/test.dart';

const _site = SiteIdentity(
  name: 'Site',
  baseUrl: 'https://example.com',
  description: 'A site.',
  organization: SiteOrganization(name: 'Org', url: 'https://org.example'),
);

void main() {
  test('text is escaped for HTML, JSON for a script tag', () {
    expect(esc('<a href="x">\'&'), '&lt;a href=&quot;x&quot;&gt;&#39;&amp;');
    expect(escJsonForScript('{"a":"</script>"}'), isNot(contains('</')));
  });

  test('paths become absolute URLs', () {
    expect(_site.absolute('/'), 'https://example.com');
    expect(_site.absolute('/a'), 'https://example.com/a');
    expect(_site.absolute('https://other.example/x'), 'https://other.example/x');
    expect(_site.at('https://preview.example/').absolute('/a'), 'https://preview.example/a');
    expect(isoDate(DateTime(2026, 3, 4)), '2026-03-04');
  });

  test('the chrome marks the entry a location is under', () {
    const chrome = SiteChrome(
      name: 'Site',
      tagline: 't',
      nav: [
        SiteLink('Home', '/', also: ['/items']),
        SiteLink('Docs', '/docs'),
        SiteLink('Out', 'https://out.example'),
      ],
    );
    expect(chrome.activeFor('/')?.label, 'Home');
    expect(chrome.activeFor('/items/x')?.label, 'Home');
    expect(chrome.activeFor('/docs/a')?.label, 'Docs');
    expect(chrome.activeFor('/docsy'), isNull);
    expect(const SiteLink('x', 'mailto:a@b.c').isExternal, isTrue);
  });

  test('sitemap and robots', () {
    final map = buildSitemap(_site, [
      SitemapEntry('/a', lastmod: DateTime(2026, 1, 2), priority: 0.8),
    ]);
    expect(map, contains('<loc>https://example.com/a</loc>'));
    expect(map, contains('<lastmod>2026-01-02</lastmod>'));
    expect(
      buildRobots(_site, disallow: ['/me']),
      contains('Disallow: /me\n\nSitemap: https://example.com/sitemap.xml'),
    );
  });

  test('a head carries the canonical URL and its graph', () {
    final head = SeoHead(
      site: _site,
      title: 'T <x>',
      description: 'D',
      path: '/p',
      noindex: true,
      jsonLd: JsonLd.graph([JsonLd.website(_site)]),
    ).render();
    expect(head, contains('<title>T &lt;x&gt;</title>'));
    expect(head, contains('<link rel="canonical" href="https://example.com/p">'));
    expect(head, contains('noindex, nofollow'));
    expect(head, contains('"@type": "WebSite"'));
  });

  test('light mode darkens the coral so it reads as text', () {
    final css = shellCss();
    expect(css, contains('html.light{--primary:${JuPalette.hex(JuPalette.lightPrimary)}'));
    expect(css, contains(JuPalette.hex(JuPalette.primary)));
  });

  test('the template slots are filled, and missing ones are named', () {
    const page =
        '<head><!--SEO_HEAD--><!--/SEO_HEAD--><style>/*SHELL_CSS*//*/SHELL_CSS*/'
        '</style></head><body><!--SEO_BODY--><!--/SEO_BODY-->'
        '<script src="flutter_bootstrap.js"></script></body>';
    final out = ShellTemplate(page).fill(head: 'H', body: 'B', css: 'C');
    expect(out, contains('<!--SEO_HEAD-->\nH\n<!--/SEO_HEAD-->'));
    expect(out, contains('/*SHELL_CSS*/\nC\n/*/SHELL_CSS*/'));
    expect(() => ShellTemplate('<html></html>'), throwsStateError);
  });
}

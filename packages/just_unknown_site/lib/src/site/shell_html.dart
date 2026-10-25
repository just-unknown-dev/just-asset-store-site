import '../model/assets.dart';
import '../model/site_chrome.dart';
import 'html_escape.dart';

/// The static shell's shared pieces, mirroring the Flutter chrome
/// (`TopNav`, `PageHero`, `SectionBlock`, `SiteFooter`) with the classes
/// `shellCss` styles.
abstract final class ShellHtml {
  /// The header: logo, wordmark and [chrome]'s navigation, [location]'s
  /// entry marked current.
  static String header(SiteChrome chrome, {String? location}) {
    final active = location == null ? null : chrome.activeFor(location);
    final b = StringBuffer()
      ..write('<header class="s-wrap s-header">')
      ..write(
        '<a class="s-brand" href="${esc(chrome.home)}">'
        '<img src="${esc(JuAssets.url(chrome.logoAsset))}" alt="" width="28" '
        'height="28">${esc(chrome.name)}</a>',
      )
      ..write('<nav class="s-nav" aria-label="Main">');
    for (final l in chrome.nav) {
      final current = identical(l, active) ? ' aria-current="page"' : '';
      b.write('<a href="${esc(l.href)}"$current${ext(l.href)}>${esc(l.label)}</a>');
    }
    for (final l in chrome.iconLinks) {
      b.write(a(l.label, l.href));
    }
    b.write('</nav></header>');
    return b.toString();
  }

  /// The footer: brand and tagline, then [chrome]'s link columns, then the
  /// copyright line for [year].
  static String footer(SiteChrome chrome, {required int year}) {
    final b = StringBuffer()
      ..write('<footer class="s-footer"><div class="s-wrap">')
      ..write('<div class="s-footer-cols">')
      ..write(
        '<div><a class="s-brand" href="${esc(chrome.home)}">'
        '${esc(chrome.name)}</a><p>${esc(chrome.tagline)}</p></div>',
      );
    for (final c in chrome.footer) {
      b.write('<div><h4>${esc(c.title)}</h4>');
      for (final l in c.links) {
        b.write(a(l.label, l.href));
      }
      b.write('</div>');
    }
    b.write('</div>');
    final copy = chrome.copyrightFor(year);
    if (copy.isNotEmpty) b.write('<p class="s-copy">${esc(copy)}</p>');
    b.write('</div></footer>');
    return b.toString();
  }

  /// A page's opening: [eyebrow], the `<h1>` [title], the [lede] and its
  /// [actions]; [extra] is HTML placed after them.
  static String hero({
    String? eyebrow,
    required String title,
    required String lede,
    List<SiteLink> actions = const [],
    String extra = '',
  }) {
    final b = StringBuffer()
      ..write('<section class="s-hero"><div class="s-wrap">');
    if (eyebrow != null) b.write('<p class="s-eyebrow">${esc(eyebrow)}</p>');
    b
      ..write('<h1>${esc(title)}</h1>')
      ..write('<p class="s-lede">${esc(lede)}</p>');
    if (actions.isNotEmpty) {
      b.write('<div class="s-actions">${actions.map(button).join()}</div>');
    }
    b
      ..write(extra)
      ..write('</div></section>');
    return b.toString();
  }

  /// A section: [eyebrow], the `<h2>` [title] and [body], then [content]
  /// (HTML).
  static String section({
    String? id,
    String? eyebrow,
    required String title,
    String? body,
    String content = '',
  }) {
    final b = StringBuffer()
      ..write(
        '<section class="s-section"${id == null ? '' : ' id="${esc(id)}"'}>'
        '<div class="s-wrap">',
      );
    if (eyebrow != null) b.write('<p class="s-eyebrow">${esc(eyebrow)}</p>');
    b.write('<h2>${esc(title)}</h2>');
    if (body != null) b.write('<p class="s-body">${esc(body)}</p>');
    b
      ..write(content)
      ..write('</div></section>');
    return b.toString();
  }

  /// [l] as a button.
  static String button(SiteLink l) =>
      '<a class="s-btn${l.primary ? ' primary' : ''}" href="${esc(l.href)}"'
      '${ext(l.href)}>${esc(l.label)}</a>';

  /// [l] as a "Label →" link.
  static String more(SiteLink l) =>
      '<a class="s-more" href="${esc(l.href)}"${ext(l.href)}>${esc(l.label)} '
      '&rarr;</a>';

  /// A plain link.
  static String a(String label, String href) =>
      '<a href="${esc(href)}"${ext(href)}>${esc(label)}</a>';

  /// The attributes an external link gets.
  static String ext(String href) =>
      href.startsWith('http') ? ' rel="noopener" target="_blank"' : '';
}

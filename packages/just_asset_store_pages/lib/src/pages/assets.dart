import 'dart:convert';

import 'package:just_asset_store/just_asset_store.dart' show Sha256;
import 'package:just_unknown_site/just_unknown_site.dart';

import 'fonts.dart';
import 'icons.dart';

/// A file whose name carries its content's hash, so it is cached for ever:
/// `static/store.1a2b3c4d5e6f.css`.
final class HashedAsset {
  HashedAsset(String stem, String ext, this.text)
    : path = 'static/$stem.${Sha256.hexOf(utf8.encode(text)).substring(0, 12)}.$ext';

  /// Where it is served, from the site's root, without a leading `/`.
  final String path;

  /// Its content.
  final String text;

  /// Its URL on the site.
  String get href => '/$path';
}

/// The CSS, script and inline theme snippet every static page uses.
abstract final class PageAssets {
  /// The stylesheet: the shared shell's (with the pages' own fonts), then
  /// the store's, then the icons.
  static final HashedAsset css = HashedAsset(
    'store',
    'css',
    shellCss(
      fontFaces: PageFonts.css,
      extra: '$_storeCss$_pagesCss${PageIcons.css}',
    ),
  );

  /// The script: the theme switch, copy buttons, the item page's pictures,
  /// and search.
  static final HashedAsset js = HashedAsset('store', 'js', _script);

  /// Sets the theme before the page draws (so a light-mode reader never
  /// sees it dark first). Inline, allowed by its hash in the page's
  /// Content-Security-Policy ([themeScriptHash]).
  static const String themeScript =
      "try{if(localStorage.getItem('just_storage:theme_mode')==='light')"
      "{document.documentElement.classList.add('light')}}catch(e){}";

  /// [themeScript]'s CSP source: `'sha256-…'`.
  static final String themeScriptHash =
      "'sha256-${base64.encode(Sha256.of(utf8.encode(themeScript)))}'";

  /// The policy every static page carries: its own files only, pictures
  /// from anywhere over https (a catalog may point at a full URL; the
  /// icons are `data:` masks), and no script but [js] and [themeScript].
  static final String contentSecurityPolicy = [
    "default-src 'self'",
    "img-src 'self' https: data:",
    "style-src 'self'",
    "script-src 'self' $themeScriptHash",
    "font-src 'self'",
    "connect-src 'self'",
    "base-uri 'none'",
    "form-action 'self'",
    "object-src 'none'",
    "frame-ancestors 'none'",
  ].join('; ');
}

/// The store's own rules, also on the publish app's static shell.
const String _storeCss = '''
.s-wrap a.s-card{display:block;text-decoration:none;color:inherit}
.s-card h3{margin-top:12px}
.s-notice{margin:24px 0;padding:12px 16px;border:1px solid var(--border);border-radius:8px;background:var(--surface-soft);font-size:14px}
.s-notice.warn{border-color:var(--primary);color:var(--text)}
.s-badges{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}
.s-hint{color:var(--muted);font-size:14px;margin:12px 0 0}
.s-steps{list-style:none;counter-reset:step;margin:32px 0 0;padding:0;max-width:760px}
.s-steps li{counter-increment:step;position:relative;padding:0 0 24px 56px}
.s-steps li::before{content:counter(step);position:absolute;left:0;top:0;width:36px;height:36px;border-radius:10px;background:var(--surface-soft);color:var(--primary);font-weight:700;display:flex;align-items:center;justify-content:center}
.s-steps h3{margin:4px 0 4px}
.s-steps p{color:var(--muted);margin:0}
.s-steps .s-code{margin-top:12px}
''';

/// What only the static pages need: their header, search, cards with
/// pictures, the home page's shelves, the item page, and keyboard focus.
const String _pagesCss = '''
:where(.s-page) a{color:inherit}
.s-skip{position:absolute;left:-9999px;top:8px;z-index:10;background:var(--primary);color:var(--on-primary);padding:8px 16px;border-radius:8px;font-weight:600}
.s-skip:focus{left:16px}
.s-sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0);white-space:nowrap}
a:focus-visible,button:focus-visible,input:focus-visible,select:focus-visible,summary:focus-visible{outline:2px solid var(--primary);outline-offset:2px;border-radius:4px}
.s-tools{display:flex;align-items:center;gap:8px}
.s-theme{background:none;border:1px solid var(--border);border-radius:8px;color:var(--text);min-width:44px;min-height:44px;cursor:pointer;font:inherit;font-weight:600;font-size:13px}
.s-menu{position:relative}
@media(min-width:1024px){.s-menu{display:none}}
.s-menu summary{list-style:none;cursor:pointer;padding:10px 14px;border:1px solid var(--border);border-radius:8px;font-weight:600;font-size:14px}
.s-menu summary::-webkit-details-marker{display:none}
.s-menu nav{position:absolute;right:0;top:52px;background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:8px;display:flex;flex-direction:column;min-width:220px;z-index:5}
.s-menu nav a{padding:12px;text-decoration:none;font-weight:600}
.s-search{display:flex;flex-wrap:wrap;gap:8px;margin-top:24px;max-width:640px}
.s-search input{flex:1;min-width:200px;padding:12px 14px;border-radius:8px;border:1px solid var(--border);background:var(--surface);color:var(--text);font:inherit}
.s-search button{padding:12px 18px;border-radius:8px;border:1px solid var(--primary);background:var(--primary);color:var(--on-primary);font:inherit;font-weight:600;cursor:pointer}
.s-filters{display:flex;flex-wrap:wrap;gap:12px;margin-top:16px;align-items:center}
.s-filters label{font-size:14px;color:var(--muted);font-weight:600}
.s-filters select{margin-left:6px;padding:8px 10px;border-radius:8px;border:1px solid var(--border);background:var(--surface);color:var(--text);font:inherit}
.s-check{display:inline-flex;align-items:center;gap:6px;cursor:pointer}
.s-status{margin-top:16px;color:var(--muted);font-size:14px;min-height:1.5em}
.s-cmd{display:flex;align-items:stretch;gap:8px;margin-top:12px}
.s-cmd .s-code{margin:0;flex:1}
.s-copy-btn{padding:8px 12px;border-radius:8px;border:1px solid var(--border);background:var(--surface-soft);color:var(--text);font:inherit;font-size:13px;font-weight:600;cursor:pointer}
.s-sha{font-family:'JetBrainsMono',ui-monospace,monospace;font-size:12px;word-break:break-all}
.s-count{color:var(--muted);font-size:13px;font-weight:600;margin:4px 0 0}
.s-body-text{white-space:pre-line}
.s-stage{border-color:var(--primary);color:var(--primary)}
.s-page main{overflow-wrap:anywhere}
.s-cmd .s-code,.s-header>*{min-width:0}
.s-header{gap:12px}
.s-brand{min-width:0}
@media(max-width:599px){.s-cmd{flex-wrap:wrap}.s-theme{min-width:44px;padding:0 8px}}
.s-pic{display:block;position:relative;aspect-ratio:16/9;overflow:hidden;background:var(--surface-soft)}
.s-pic img{display:block;width:100%;height:100%;object-fit:cover}
.s-ph{display:flex;align-items:center;justify-content:center;color:var(--muted)}
.s-ph .s-ico{width:44px;height:44px;opacity:.5}
.s-sum{color:var(--muted);font-size:14px;line-height:1.45;margin:0;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden}
.s-pcard{padding:0;overflow:hidden;display:flex;flex-direction:column;transition:border-color .15s,transform .15s}
.s-wrap a.s-pcard{display:flex}
.s-pcard:hover{border-color:var(--primary);transform:translateY(-2px)}
.s-pbody{display:flex;flex-direction:column;gap:6px;padding:14px 16px 16px;flex:1}
.s-pcard h3{margin:2px 0 0;font-size:18px}
.s-pbody .s-meta,.s-banner .s-meta{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.s-pbody .s-meta{margin-top:auto;padding-top:4px}
.s-pcard .s-badges,.s-banner .s-badges{margin:0;gap:6px}
.s-pcard .s-badge,.s-banner .s-badge{float:none;font-size:12px;padding:2px 9px}
.s-cards{grid-template-columns:repeat(auto-fill,minmax(240px,1fr))}
.s-hero.s-hero-home{padding:72px 0 24px}
.s-shelf{padding:28px 0}
.s-shelf-head{display:flex;align-items:baseline;justify-content:space-between;gap:16px;margin-bottom:18px}
.s-shelf-head h2{font-size:clamp(22px,2.6vw,28px)}
.s-shelf-head .s-more{margin:0;white-space:nowrap}
.s-row{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:20px}
.s-row-1,.s-row-2{grid-template-columns:repeat(2,minmax(0,1fr))}
.s-row-3{grid-template-columns:repeat(3,minmax(0,1fr))}
@media(max-width:1023px){.s-row,.s-row-3{grid-template-columns:repeat(2,minmax(0,1fr))}}
@media(max-width:599px){.s-row,.s-row-1,.s-row-2,.s-row-3{grid-template-columns:none;grid-auto-flow:column;grid-auto-columns:82%;overflow-x:auto;scroll-snap-type:x mandatory;padding-bottom:8px}.s-row>*{scroll-snap-align:start}}
.s-tiles{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px}
.s-wrap a.s-tile{display:flex;flex-direction:column;gap:4px;padding:16px;border:1px solid var(--border);border-radius:12px;background:var(--surface);text-decoration:none;transition:border-color .15s}
.s-tile:hover{border-color:var(--primary)}
.s-tile .s-ico{color:var(--primary);width:28px;height:28px;margin-bottom:6px}
.s-tile-name{font-weight:600}
.s-tile .s-count{margin:0}
.s-featured{padding-top:8px}
.s-wrap a.s-banner{display:grid;grid-template-columns:minmax(0,3fr) minmax(0,2fr);background:var(--surface);border:1px solid var(--border);border-radius:18px;overflow:hidden;text-decoration:none;color:inherit;transition:border-color .15s}
.s-banner:hover{border-color:var(--primary)}
.s-banner .s-pic{height:100%}
.s-banner-body{display:flex;flex-direction:column;justify-content:center;gap:10px;padding:28px 32px}
.s-banner .s-eyebrow{margin:0}
.s-banner h3{font-size:clamp(26px,3.2vw,38px);font-weight:700;margin:0}
.s-banner .s-sum{font-size:16px;-webkit-line-clamp:4}
.s-banner .s-go{align-self:flex-start;margin-top:8px;padding:10px 18px}
.s-featured .s-row{margin-top:20px}
@media(max-width:1023px){.s-wrap a.s-banner{grid-template-columns:1fr}.s-banner .s-pic{height:auto}.s-banner-body{padding:20px}}
.s-point .s-ico{color:var(--primary);width:28px;height:28px}
.s-point h3{margin-top:10px}
.s-item{padding:32px 0 64px}
.s-crumbs{font-size:13px;font-weight:600;color:var(--muted);margin:0 0 20px}
.s-crumbs a{color:var(--primary);text-decoration:none}
.s-item-grid{display:grid;grid-template-columns:minmax(0,1fr) 360px;grid-template-rows:auto 1fr;grid-template-areas:"gal panel" "body panel";gap:28px 40px;align-items:start}
.s-gallery{grid-area:gal;min-width:0}
.s-gallery>.s-pic{border-radius:16px;border:1px solid var(--border)}
.s-gallery .s-ph .s-ico{width:80px;height:80px}
.s-strip{list-style:none;display:flex;gap:10px;margin:12px 0 0;padding:0 0 4px;overflow-x:auto}
.s-strip a{display:block;width:128px;aspect-ratio:16/9;border-radius:8px;overflow:hidden;border:2px solid var(--border);opacity:.7;transition:opacity .15s,border-color .15s}
.s-strip a[aria-current=true],.s-strip a:hover{border-color:var(--primary);opacity:1}
.s-strip img{display:block;width:100%;height:100%;object-fit:cover}
.s-panel{grid-area:panel;position:sticky;top:20px;background:var(--surface);border:1px solid var(--border);border-radius:16px;padding:24px;min-width:0}
.s-panel h1{font-size:clamp(28px,3.2vw,36px)}
.s-panel .s-eyebrow{margin:0 0 8px}
.s-panel-sum{color:var(--muted);margin:10px 0 0}
.s-panel .s-badges{margin-top:14px}
.s-panel .s-notice{margin:14px 0 0;font-size:13px}
.s-item-body{grid-area:body;min-width:0}
.s-item-body h2{font-size:22px;margin:36px 0 12px}
.s-item-body h2:first-child{margin-top:4px}
.s-item-body .s-body{font-size:16px;max-width:none}
@media(max-width:1023px){.s-item-grid{grid-template-columns:minmax(0,1fr);grid-template-rows:none;grid-template-areas:"gal" "panel" "body"}.s-panel{position:static}}
.s-install{margin-top:20px;padding-top:20px;border-top:1px solid var(--border)}
.s-install-h{font-size:16px;font-weight:600;letter-spacing:0;margin:0 0 12px}
.s-tabs{display:flex;flex-wrap:wrap}
.s-tabs input{position:absolute;opacity:0;width:1px;height:1px;margin:0}
.s-tabs label{flex:1;text-align:center;padding:8px 10px;border:1px solid var(--border);cursor:pointer;font-weight:600;font-size:14px;color:var(--muted);background:var(--surface-soft)}
.s-tabs label:first-of-type{border-radius:8px 0 0 8px;border-right:0}
.s-tabs label:last-of-type{border-radius:0 8px 8px 0}
.s-tabs input:checked+label{background:var(--primary);border-color:var(--primary);color:var(--on-primary)}
.s-tabs input:focus-visible+label{outline:2px solid var(--primary);outline-offset:2px}
.s-pane{display:none;flex-basis:100%;padding-top:12px;min-width:0}
#how-editor:checked~.s-pane-editor,#how-cli:checked~.s-pane-cli{display:block}
.s-mini-steps{margin:0;padding-left:20px;font-size:14px}
.s-mini-steps li{margin:6px 0}
.s-pane .s-code{font-size:13px;padding:10px 14px}
.s-facts{display:grid;grid-template-columns:minmax(76px,auto) minmax(0,1fr);gap:8px 12px;margin:20px 0 0;padding-top:20px;border-top:1px solid var(--border);font-size:14px}
.s-facts dt{color:var(--muted)}
.s-facts dd{margin:0;overflow-wrap:anywhere}
.s-facts a{color:var(--primary);text-decoration:none}
.s-facts code,.s-versions code{font-family:'JetBrainsMono',ui-monospace,monospace;font-size:13px}
.s-panel-links{display:flex;flex-wrap:wrap;align-items:center;gap:8px 16px;margin-top:20px}
.s-panel-links .s-btn{padding:10px 16px}
.s-panel-links .s-more{margin:0;font-size:14px}
.s-tags{margin-top:16px}
.s-perms{list-style:none;padding:0;margin:8px 0 0}
.s-perms li{padding:6px 0 6px 28px;position:relative}
.s-perms li::before{content:'!';position:absolute;left:0;top:8px;width:18px;height:18px;border-radius:50%;background:var(--primary);color:var(--on-primary);font-size:12px;font-weight:700;text-align:center;line-height:18px}
.s-versions{list-style:none;margin:0;padding:0}
.s-versions li{padding:12px 0;border-bottom:1px solid var(--border)}
.s-versions .s-vhead{display:flex;flex-wrap:wrap;gap:12px;align-items:center}
.s-versions .s-badge{font-size:12px;padding:2px 9px}
.s-vnotes{color:var(--muted);font-size:14px;margin:4px 0 0}
''';

/// The pages' only script: the theme switch, copy buttons, the item page's
/// pictures, and the search page. Text from the catalog goes in with
/// `textContent`, never as HTML.
const String _script = r'''
(function () {
  'use strict';
  var root = document.documentElement;
  var KEY = 'just_storage:theme_mode';
  document.addEventListener('click', function (e) {
    var toggle = e.target.closest('[data-theme-toggle]');
    if (toggle) {
      var light = !root.classList.contains('light');
      root.classList.toggle('light', light);
      try { localStorage.setItem(KEY, light ? 'light' : 'dark'); } catch (_) {}
      return;
    }
    var shot = e.target.closest('[data-gallery]');
    var main = document.getElementById('gallery-main');
    if (shot && main) {
      e.preventDefault();
      main.src = shot.getAttribute('href');
      main.alt = shot.getAttribute('data-alt') || '';
      var all = document.querySelectorAll('[data-gallery]');
      for (var n = 0; n < all.length; n++) all[n].removeAttribute('aria-current');
      shot.setAttribute('aria-current', 'true');
      return;
    }
    var copy = e.target.closest('[data-copy]');
    if (copy && navigator.clipboard) {
      navigator.clipboard.writeText(copy.getAttribute('data-copy')).then(function () {
        var was = copy.textContent;
        copy.textContent = 'Copied';
        setTimeout(function () { copy.textContent = was; }, 1500);
      });
    }
  });

  var results = document.getElementById('search-results');
  if (!results) return;
  var form = document.getElementById('search-form');
  var input = document.getElementById('search-q');
  var kind = document.getElementById('search-kind');
  var sort = document.getElementById('search-sort');
  var experimental = document.getElementById('search-exp');
  var status = document.getElementById('search-status');
  var params = new URLSearchParams(location.search);
  input.value = params.get('q') || '';
  if (params.get('kind')) kind.value = params.get('kind');
  if (params.get('sort')) sort.value = params.get('sort');
  experimental.checked = params.get('experimental') === '1';
  var data = null;
  // A card without a picture shows its kind's icon.
  var ICONS = {
    'content': 'image', 'editor-extension': 'wrench', 'kit': 'puzzle',
    'runtime-library': 'code', 'template': 'dashboard'
  };

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function card(i) {
    var a = el('a', 's-card s-pcard');
    a.href = '/items/' + encodeURIComponent(i.id);
    var pic = el('span', 's-pic');
    if (i.th) {
      var img = el('img');
      img.src = i.th;
      img.alt = '';
      img.loading = 'lazy';
      img.width = 640;
      img.height = 360;
      pic.appendChild(img);
    } else {
      pic.className = 's-pic s-ph';
      var icon = el('span', 's-ico s-ico-' + (ICONS[i.k] || 'shapes'));
      icon.setAttribute('aria-hidden', 'true');
      pic.appendChild(icon);
    }
    a.appendChild(pic);
    var body = el('span', 's-pbody');
    var badges = el('span', 's-badges');
    badges.appendChild(el('span', 's-badge', i.tr));
    if (i.stl) badges.appendChild(el('span', 's-badge s-stage', i.stl));
    body.appendChild(badges);
    body.appendChild(el('h3', null, i.n));
    body.appendChild(el('span', 's-sum', i.s));
    body.appendChild(el('span', 's-meta', [i.kl, i.v ? 'v' + i.v : '', i.p].filter(Boolean).join(' · ')));
    a.appendChild(body);
    return a;
  }

  function render() {
    if (!data) return;
    var words = input.value.toLowerCase().split(/\s+/).filter(Boolean);
    var k = kind.value;
    var found = data.items.filter(function (i) {
      if (k && i.k !== k) return false;
      // As in the editor: experimental items only when asked, deprecated
      // ones only to a search.
      if (i.st === 'experimental' && !experimental.checked) return false;
      if (i.st === 'deprecated' && words.length === 0) return false;
      var hay = (i.id + ' ' + i.n + ' ' + i.s + ' ' + i.p + ' ' + i.t.join(' ')).toLowerCase();
      return words.every(function (w) { return hay.indexOf(w) >= 0; });
    });
    if (sort.value === 'updated') {
      found.sort(function (a, b) { return (b.u || '').localeCompare(a.u || ''); });
    }
    results.textContent = '';
    found.slice(0, 200).forEach(function (i) { results.appendChild(card(i)); });
    status.textContent = found.length === 0
      ? results.getAttribute('data-empty')
      : found.length + (found.length === 1 ? ' package' : ' packages') +
        (found.length > 200 ? ' (the first 200 shown)' : '');
    var q = new URLSearchParams();
    if (input.value) q.set('q', input.value);
    if (k) q.set('kind', k);
    if (sort.value !== 'name') q.set('sort', sort.value);
    if (experimental.checked) q.set('experimental', '1');
    var next = location.pathname + (q.toString() ? '?' + q : '');
    history.replaceState(null, '', next);
  }

  form.addEventListener('submit', function (e) { e.preventDefault(); render(); });
  input.addEventListener('input', render);
  kind.addEventListener('change', render);
  sort.addEventListener('change', render);
  experimental.addEventListener('change', render);
  status.textContent = 'Loading…';
  fetch('/search.json').then(function (r) {
    if (!r.ok) throw new Error(r.status);
    return r.json();
  }).then(function (json) {
    data = json;
    render();
  }).catch(function () {
    status.textContent = 'The catalog could not be loaded. Browse the categories instead.';
  });
})();
''';

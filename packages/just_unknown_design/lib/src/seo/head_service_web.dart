import 'package:web/web.dart' as web;

import 'head_service.dart';

HeadService createHeadService() => WebHeadService();

/// Upserts `<title>`, description, canonical, Open Graph and Twitter tags in
/// the live document using `package:web` (wasm-compatible).
class WebHeadService implements HeadService {
  @override
  void apply(PageMeta meta) {
    web.document.title = meta.title;
    _meta('name', 'description', meta.description);
    _meta(
      'name',
      'robots',
      meta.noindex ? 'noindex, nofollow' : 'index, follow',
    );
    _meta('property', 'og:title', meta.title);
    _meta('property', 'og:description', meta.description);
    _meta('property', 'og:url', meta.canonicalUrl);
    _meta('property', 'og:image', meta.ogImageUrl);
    _meta('property', 'og:site_name', meta.siteName);
    _meta('name', 'twitter:title', meta.title);
    _meta('name', 'twitter:description', meta.description);
    _meta('name', 'twitter:image', meta.ogImageUrl);
    _link('canonical', meta.canonicalUrl);
  }

  void _meta(String attr, String key, String value) {
    final head = web.document.head;
    if (head == null) return;
    var el = head.querySelector('meta[$attr="$key"]') as web.HTMLMetaElement?;
    if (el == null) {
      el = web.document.createElement('meta') as web.HTMLMetaElement;
      el.setAttribute(attr, key);
      head.append(el);
    }
    el.content = value;
  }

  void _link(String rel, String href) {
    final head = web.document.head;
    if (head == null) return;
    var el = head.querySelector('link[rel="$rel"]') as web.HTMLLinkElement?;
    if (el == null) {
      el = web.document.createElement('link') as web.HTMLLinkElement;
      el.rel = rel;
      head.append(el);
    }
    el.href = href;
  }
}

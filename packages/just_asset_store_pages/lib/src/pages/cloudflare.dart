/// Cloudflare Pages' own files: response headers (`_headers`) and
/// redirects (`_redirects`).
abstract final class CloudflareFiles {
  /// `_headers`.
  ///
  /// - Every response: no type sniffing, no framing, a strict referrer.
  /// - `index.json`: asked again after a minute (its ETag makes that one
  ///   small request), readable from any site — the editor on the web,
  ///   say.
  /// - `catalog/*`, `thumbs/*` and `previews/*`: named by their content, so cached for
  ///   ever.
  /// - `static/*`: the pages' CSS, script and fonts, also named by their
  ///   content.
  /// - `search.json`: five minutes.
  /// - The publish app's fonts: a month.
  static const String headers = '''
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()

/index.json
  Cache-Control: public, max-age=60, must-revalidate
  Access-Control-Allow-Origin: *

/catalog/*
  Cache-Control: public, max-age=31536000, immutable
  Access-Control-Allow-Origin: *

/thumbs/*
  Cache-Control: public, max-age=31536000, immutable
  Access-Control-Allow-Origin: *

/previews/*
  Cache-Control: public, max-age=31536000, immutable
  Access-Control-Allow-Origin: *

/static/*
  Cache-Control: public, max-age=31536000, immutable

/search.json
  Cache-Control: public, max-age=300, must-revalidate

/assets/packages/just_unknown_design/assets/fonts/*
  Cache-Control: public, max-age=2592000
''';

  /// `_redirects`: the lists that have no page of their own, to the pages
  /// that list them.
  static const String redirects = '''
/items /search 301
/categories / 301
/publishers / 301
''';
}

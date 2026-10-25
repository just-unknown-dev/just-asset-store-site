/// The Just Unknown look for static pages, in pure Dart (no Flutter): the
/// palette ([JuPalette]), the chrome's model ([SiteChrome], [SiteLink]),
/// and the builders of a crawlable page — the template slots
/// ([ShellTemplate]), the CSS ([shellCss]), the shared HTML ([ShellHtml]),
/// the `<head>` ([SeoHead], [JsonLd]) and `sitemap.xml` / `robots.txt`.
///
/// just_unknown_design re-exports it and draws the same chrome in Flutter,
/// so a static page and the app can't drift apart.
library;

export 'src/model/assets.dart';
export 'src/model/palette.dart';
export 'src/model/site_chrome.dart';
export 'src/site/html_escape.dart';
export 'src/site/json_ld.dart';
export 'src/site/seo_head.dart';
export 'src/site/shell_css.dart';
export 'src/site/shell_html.dart';
export 'src/site/shell_template.dart';
export 'src/site/site_identity.dart';
export 'src/site/sitemap.dart';

# just_unknown_site

The Just Unknown look for static pages, in pure Dart: the palette
(`JuPalette`, which the Flutter theme uses too), the site chrome's model
(`SiteChrome`, `SiteLink`, `FooterColumn`), and the builders of a crawlable
page — `shellCss`, `ShellHtml`, `SeoHead`, `JsonLd`, `buildSitemap`,
`buildRobots`, and `ShellTemplate` for a Flutter build's `index.html`.

It doesn't depend on Flutter, so plain-Dart tools (the store's page builder,
`tool/` scripts) use it. just_unknown_design builds the same chrome in
Flutter on it, and re-exports it as `package:just_unknown_design/site_builder.dart`.

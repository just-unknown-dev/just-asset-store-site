# just_unknown_design

The Just Unknown look for Flutter web sites, shared by
[store.justunknown.com](https://store.justunknown.com) and (later)
[justunknown.com](https://justunknown.com), which it was taken from.

- **Theme:** `JuTheme.dark()` / `JuTheme.light()` (Material 3), the `JuTokens`
  extension (`context.tokens`), `JuSpacing`, `JuRadii`, `JuDurations`, and
  the type scale in Space Grotesk, Inter and JetBrains Mono (`JuFonts`,
  bundled). `ThemeController` keeps the choice in just_storage.
- **Layout:** `Breakpoints` (600 / 1024, a 1120 px column) and the
  `context.isMobile` / `context.gutter` helpers.
- **Chrome:** `SiteScaffold` — the frosted top nav, the drawer, the footer —
  drawn from a `SiteChrome` (name, navigation, icon links, footer columns).
- **Pieces:** `PageHero`, `SectionBlock`, `ContentColumn`, `ResponsiveGrid`,
  `HoverCard`, `FeatureCard`, `IconTile`, `StatusBadge`, `CodeCard`,
  `GlowContainer`, `AppLink`, `LinkButton`, `InlineLink`. An app that is
  one part of a site (static pages around it) puts `AppRoutes` above its
  pages: links to the paths it doesn't own load those pages.
- **Static pages** (just_unknown_site, pure Dart, re-exported as
  `package:just_unknown_design/site_builder.dart`): `ShellTemplate` fills
  the `<!--SEO_HEAD-->`, `<!--SEO_BODY-->` and `/*SHELL_CSS*/` slots of the
  built `index.html`; `shellCss`, `ShellHtml`, `SeoHead`, `JsonLd`,
  `buildSitemap`, `buildRobots`, and the palette and chrome model.
- **Live `<head>`:** `createHeadService()` updates title, description,
  canonical and Open Graph tags as the app navigates (`package:web`).

One palette (`JuPalette`, ARGB ints) feeds both the Flutter colours and the
shell CSS, so the crawlable page and the app can't drift apart.

## Using it

```dart
MaterialApp.router(
  theme: JuTheme.light(),
  darkTheme: JuTheme.dark(),
  themeMode: controller.mode.value,
  routerConfig: router,
);

// In the router's ShellRoute:
SiteScaffold(chrome: myChrome, theme: controller, location: path, child: page);
```

Fonts and the logo are this package's assets: Flutter web serves them under
`/assets/packages/just_unknown_design/…` (`JuAssets.fontBase`), which is where
the shell CSS points too. Preload the two main faces from `web/index.html`:

```html
<link rel="preload" href="assets/packages/just_unknown_design/assets/fonts/SpaceGrotesk-Bold.ttf" as="font" type="font/ttf" crossorigin>
<link rel="preload" href="assets/packages/just_unknown_design/assets/fonts/Inter-Regular.ttf" as="font" type="font/ttf" crossorigin>
```

and read the theme before the first paint, with the key you gave
`ThemeController` (`theme_mode` by default):

```html
<script>try{if(localStorage.getItem('just_storage:theme_mode')==='light'){document.documentElement.classList.add('light')}}catch(e){}</script>
```

## Rules

- The static half is its own package, just_unknown_site, which doesn't
  depend on Flutter, so it can't use it.
- Light mode darkens the brand coral (`JuPalette.lightPrimary`) so it reads
  as text on the light surfaces.
- DOM access is `package:web` only (wasm), never `dart:html`.
- The fonts are under the SIL Open Font License (`assets/fonts/OFL-*.txt`).

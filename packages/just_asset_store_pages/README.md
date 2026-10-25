# just_asset_store_pages

The Just Asset Store website's static pages, built from the catalog the
backend exports, in pure Dart (no Flutter: the Publish workflow runs it on
plain Dart).

```text
dart run bin/pages.dart --catalog <folder with index.json>
    [--app <the publish app's build>] --out <folder> [--base-url <address>]
```

It writes, ready for Cloudflare Pages:

- a page for the home, search, the policy, every category, item and
  publisher, every item the store took down, and `404.html` — each one
  file (`/items/x` is `items/x.html`), with its own `<head>` and JSON-LD and
  a strict Content-Security-Policy;
- `search.json`, which the search page filters in the browser;
- the pages' CSS and script and their fonts (Latin WOFF2 subsets, from
  `tool/subset_fonts.py`), under `static/`, named by their content's hash;
- `sitemap.xml`, `robots.txt`, `_headers` and `_redirects`;
- the catalog's own files (`index.json`, `catalog/`, and the pictures the
  backend made: `thumbs/` for cards, `previews/` for galleries), as the
  editor and `just store` read them;
- with `--app`: the publish app's build, and its three pages (`publish.html`,
  `report.html`, `me.html`) with their static shells. Flutter's engine comes
  from Google's CDN, so the build's `canvaskit/` is left out.

`--out` is emptied first when it holds an earlier build, and refused when it
holds anything else.

`package:just_asset_store_pages/content.dart` — the store's words, links,
routes and chrome — runs on the web too: the publish app uses it, so the
pages and the app say the same things.

Try it on the example catalog:

```text
dart run bin/pages.dart --catalog example/catalog --out build/site
npx wrangler pages dev build/site
```

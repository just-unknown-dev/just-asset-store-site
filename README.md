# Just Asset Store

The Just Game Engine's Asset Store: the website at
[asset.justunknown.com](https://asset.justunknown.com), the catalog it
publishes, and the code that keeps them.

| Path | What it is |
|---|---|
| `/` (`just_asset_store_site`) | The publish app (Flutter web): `/publish`, `/report` and `/me`, the pages that need GitHub sign-in. |
| `packages/just_asset_store_pages` | The rest of the website: static pages built from the catalog in pure Dart (home, search, categories, items, publishers, policy), and the whole site assembled for Cloudflare Pages. Also the words, links and routes the publish app shares (`content.dart`). |
| `just_asset_store` (not in this repository) | The store's core, [just-asset-store](https://github.com/just-unknown-dev/just-asset-store) (pure Dart, on pub.dev): catalogs, downloads checked by SHA-256, installs into a project. Its commands are `just store …` (a just_core_cli plugin). Its working copy is in the engine workspace, at `JustGameEngineTemplates/just_platformer_template/packages/just_asset_store`. The backend uses it from pub.dev, or that working copy through the backend's gitignored `pubspec_overrides.yaml`. |
| `packages/just_asset_store_backend` | GitHub Actions code, the only writer of the store's records: answers submissions and reports, checks releases, keeps Firestore, exports the catalog. |
| `packages/just_unknown_site` | The Just Unknown look for static pages, in pure Dart: palette, chrome, HTML, CSS, `<head>`, sitemap. |
| `packages/just_unknown_design` | The Just Unknown theme and site chrome in Flutter, on just_unknown_site, shared with justunknown.com. |

This repository is private (`just-unknown-dev/just-asset-store-site`); the
store's core and its templates are public.

## Who publishes

**Version 1: only Just Unknown.** The store lists only Just Unknown's own
packages, released from the `just-unknown-dev` GitHub account
(dev@justunknown.com; numeric id 262105023). Nobody else can submit: the
website shows them a note instead of the form, Firestore's rules refuse
their submissions, and the backend refuses them and any release they
claim. The site doesn't offer Publish in its navigation; the page is still
at `/publish` for that account. Reports stay open to everyone signed in with
GitHub.

**Version 2: everyone.** One switch, in three places a test keeps in step:

- `openPublishing` in `packages/just_asset_store_backend/catalog.json`;
- `mayPublish()` in `firestore.rules` (return `true`);
- `StoreAccess.openPublishing` in
  `packages/just_asset_store_pages/lib/src/content/access.dart` (the
  navigation, the Publish page's words, the policy).

Everything for community publishers — claim codes, holds for a maintainer,
look-alike ids, pub.dev name and native-code checks, reports — is built and
tested already; the backend's tests run with publishing open. Before
switching, see "Before community submissions open" below.

## How it fits together

```text
creator's repo (public, release immutability on)       private repo: GitHub Actions
  release v1.2.0:  <id>-1.2.0.zip  (GitHub records      Publish, hourly at :17
                   its SHA-256), just_release.json       answer submissions and reports
                   (with the creator's claim code)       sweep every watched repository's
website /publish (Flutter, GitHub sign-in) --+           new releases (one GraphQL query
                                             v           per hundred) and check them
                                Firestore: submissions,  --> records in Firestore
                                reports, records         if anything changed: export the
                                                         catalog in pieces + card pictures,
                                                         build the website, deploy --> Cloudflare Pages
editor, `just store`, the website <-- index.json + changed pieces ---------------------+
  (zips download straight from the GitHub release, checked against the pinned SHA-256)
```

- **Submitting.** A creator signs in with GitHub (Firebase Auth, public
  profile only) and submits a repository. That files a pending
  `submissions/{id}`, at most one every ten minutes, and Firestore's rules
  allow little else: a report about an item, reading one's own
  submissions, and the store's notices to one's own GitHub account.
- **Checking** (`release_check.dart`). The backend looks the signer's
  GitHub account up itself, never trusting what the browser wrote. The
  release must be immutable; its `just_release.json` must carry the
  signer's claim code (`claimCode(githubId)`: only someone who can push to
  the repository can put it there); the id must be free, and `just_*` only
  for official publishers. A listed version never changes. The archive's
  directory and its two small files are read in parts and checked by the
  installer's own rules, then the archive is downloaded once, compared with
  the SHA-256 GitHub recorded, and checked whole. pub.dev is asked too
  (`pub_dev.dart`): a new community item may not take a name pub.dev has
  (projects using that package would get the item instead), and the native
  code an item's pub.dev packages bring — Flutter plugins, build hooks,
  however indirectly, but not what the engine brings anyway — is added to
  its `nativePlugins` whatever the release says, and must be declared
  `native`.
- **Holding.** Some versions wait for a maintainer: for community
  publishers, an id that looks like another publisher's, a first version
  with native code, and an update that adds native code, pub.dev packages or
  permissions; for everyone but official publishers, a change of kind or of
  the repository's owner. Each opens a "Review" issue.
- **Moderating.** Maintainers (by numeric GitHub id) comment on any issue:
  `/store block|unblock|approve|reject <id>`,
  `/store block:<v>|unblock:<v>|yank:<v>|unyank:<v> <id>`,
  `/store trust:<level> <id>`. Taken-down items stay named in the catalog's
  `removed` list, so projects that have them are warned. Website reports
  become "Report" issues.
- **Publishing.** When something changed (and once a day regardless), the
  catalog is exported from what changed since the last deploy: a small
  `index.json` naming content-hashed pieces, which editors fetch only when
  they change. Card pictures are made once and kept. The website is built
  around the catalog and deployed to Cloudflare Pages (static files: free,
  without a bandwidth limit). The previous deploy's pieces stay one more
  deploy, for editors that read the old `index.json` a moment ago.
- **The website.** Every page but three is static HTML made from the
  catalog (`packages/just_asset_store_pages`): about 7 KB of HTML, CSS and
  script, plus about 110 KB of fonts the first time, with a strict
  Content-Security-Policy. Search filters a small `search.json` in the
  browser. Each path is one file (`/items/x` is `items/x.html`). The publish
  app — Flutter, for `/publish`, `/report` and `/me` — loads only there,
  starts Firebase in the background, and takes Flutter's engine from
  Google's CDN. `_headers` caches the catalog's pieces, card pictures and
  the pages' CSS, script and fonts for ever (their names are their content's
  hash) and `index.json` for a minute.
- **Budgets (free plans).** Firestore's 50k reads a day: a quiet run reads
  about a dozen documents, an export only what changed. GitHub Actions'
  2,000 minutes a month on a private repository: a quiet hourly run is one
  short job (a cached compiled backend, no Flutter). GitHub's API: about a
  GraphQL point per hundred repositories a sweep.

## Working on the site

```text
# the publish app
flutter pub get
flutter run -d chrome                                             # opens /publish
flutter test
dart run tool/build.dart --out build/app                           # release build

# the static pages, around the example catalog, with the app
cd packages/just_asset_store_pages
dart pub get
dart test
dart run bin/pages.dart --catalog example/catalog --app ../../build/app --out build/site
npx wrangler pages dev build/site                                  # serve it as Cloudflare does
```

- `packages/just_asset_store_pages/example/catalog` is a small catalog (the
  three editors, placeholder fingerprints) for trying the pages; the
  Publish workflow builds them around the catalog the backend exported.
  `--app` is optional: without it the site has no `/publish`.
- The pages' fonts are Latin subsets of the design's, as WOFF2, in
  `packages/just_asset_store_pages/lib/src/fonts` (committed). Make them
  again when the design's fonts change: `python tool/subset_fonts.py` there
  (needs `pip install fonttools brotli`).
- `lib/firebase_options.dart` is gitignored. Make it with `flutterfire
  configure`, or copy `lib/firebase_options.dart.example` (the app says
  sign-in isn't set up).
- The app, the pages and the backend use `just_asset_store` from pub.dev;
  for development, each has a gitignored `pubspec_overrides.yaml` pointing
  at the engine workspace's working copy (see "Setting it up", step 8).
- House rules (as on justunknown.com): `just_signals` for state, `just_di`
  for services (`lib/core/di/app_config.dart`), `just_storage` for the
  theme (the static pages read the same `localStorage` key), `package:web`
  only. Words, links and routes live in the pages package's `content.dart`,
  so a static page and the app say the same thing; it runs on the web, and
  a test checks it stays that way. Links from the app to a static page load
  that page (`AppRoutes` in just_unknown_design).

## Setting it up (once)

1. **GitHub.** Make this repository `just-unknown-dev/just-asset-store-site`
   (private) and point `origin` at it; `just-asset-store` (public) holds the
   core. Labels: `report`, `review`, `publish-failed`. In each first-party
   package's repository: turn on release immutability (Settings > General >
   Releases) and set the Actions variable `JUST_STORE_CLAIM` to its
   publisher's claim code.
2. **Firebase project** `just-asset-store` (Spark): turn on Firestore
   (production mode) and Authentication. No Hosting: the website is on
   Cloudflare.
3. **GitHub sign-in.** Create a GitHub OAuth App (callback
   `https://just-asset-store.firebaseapp.com/__/auth/handler`), and in
   Authentication > Sign-in method turn on GitHub with its client id and
   secret. Add `asset.justunknown.com` to the authorised domains.
4. **Service accounts**, each with no more than it needs:
   - Publish: *Cloud Datastore User* and *Firebase Authentication Viewer*;
   - Moderate: *Cloud Datastore User*;
   - Firestore rules: *Firebase Rules Admin* and *Cloud Datastore Index
     Admin*.
5. **Workload identity.** A pool and provider for GitHub
   (`token.actions.githubusercontent.com`), limited to this repository,
   allowed to impersonate those accounts. No key file is stored anywhere.
6. **Cloudflare.** A free account, and a Pages project (Direct Upload) named
   `just-asset-store-site`; an API token with *Cloudflare Pages:
   Edit*. Add the custom domain `asset.justunknown.com` to the project (a
   CNAME to `<project>.pages.dev`; the DNS can stay where it is): the
   address `SourceConfig.official` reads the catalog from.
7. **Repository settings** (Settings > Secrets and variables > Actions):
   - variables `FIREBASE_PROJECT`, `GCP_WORKLOAD_IDENTITY_PROVIDER`,
     `GCP_SERVICE_ACCOUNT`, `GCP_MODERATE_SERVICE_ACCOUNT`,
     `GCP_RULES_SERVICE_ACCOUNT`, `CLOUDFLARE_ACCOUNT_ID`,
     `CLOUDFLARE_PAGES_PROJECT`, and `MAINTAINER_IDS` (a JSON list of
     numeric GitHub ids, like `[263049034]`: the same as `maintainerIds` in
     `packages/just_asset_store_backend/catalog.json`);
   - secrets `CLOUDFLARE_API_TOKEN` and `FIREBASE_OPTIONS_DART` (the whole
     real `lib/firebase_options.dart`).
8. **Publish the store's packages** to pub.dev, in order: just_deflate,
   just_game_engine_formats, just_core_cli 0.1.2, just_asset_store 0.2.0.
   Then, in the repository's root (`flutter pub get`),
   `packages/just_asset_store_pages` and `packages/just_asset_store_backend`
   (`dart pub get`): move `pubspec_overrides.yaml` aside, get, commit
   `pubspec.lock` (the workflows install exactly what it names), and put
   the overrides file back. Set the variable `STORE_DEPS_PUBLISHED=true` so
   CI tests the app, the pages and the backend too.
9. **Rules.** Run the *Firestore rules* workflow once (it runs again when
   `firestore.rules` or `firestore.indexes.json` change).
10. **Seed the official packages.** Release each first-party package from
    its repository under `just-unknown-dev` (with that account's claim code
    in `JUST_STORE_CLAIM`), then submit it on `/publish`, signed in with
    GitHub as `just-unknown-dev` (dev@justunknown.com), the one account in
    `officialPublishers`. Its packages are official from their first
    version, and may use `just_*` ids. `maintainerIds` (`ju-skb`) moderate:
    approve, block, yank.
11. **Featured.** `featured` in `catalog.json` lists the item ids the home
    page shows first, in order (the first as a banner); an id the catalog
    doesn't list, or an experimental, deprecated or unavailable item, is
    left out. Edit it and the next export carries it.

On the first deploy, check that `/items/<id>` is served without a redirect,
that an unknown path answers 404, that `/index.json` answers 304 to a
request with its ETag, and that signing in on `/publish` works. Sign-in
opens a pop-up on `just-asset-store.firebaseapp.com`; if a browser blocks
its third-party storage, serve Firebase's `/__/auth/*` from
`asset.justunknown.com` (a Pages Function proxying to the firebaseapp.com
handler) and set `authDomain` to it.

## Before community submissions open

- Turn the workflows back on. For now the store is published by hand from
  a computer: `dart tool/publish_local.dart` runs the Publish workflow's
  steps with your own gcloud, wrangler and GitHub logins, and `.env` holds
  `GITHUB_TOKEN` and `CLOUDFLARE_PAGES_PROJECT=just-asset-store-site`;
  `--rules` deploys the Firestore rules and indexes. The Publish and
  Firestore rules workflows run only by hand, so other publishers'
  submissions would wait. Do "Setting it up" steps 4, 5 and 7, then
  uncomment the hourly schedule and push trigger in `publish.yml` and the
  push trigger in `rules.yml`.

- Review the content policy
  (`packages/just_asset_store_pages/lib/src/content/copy.dart`,
  `PolicyCopy`; the page says DRAFT until `PolicyCopy.draft` is false) and
  confirm the takedown contact (`StoreLinks.email`).

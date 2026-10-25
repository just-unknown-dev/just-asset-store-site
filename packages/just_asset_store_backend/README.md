# just_asset_store_backend

The Just Asset Store's backend: the only writer of the store's records. It
runs in GitHub Actions (the repository's `Publish` and `Moderate` workflows);
see the [repository README](../../README.md) for how it fits with the website
and for the one-time setup.

| Command | What it does |
|---|---|
| `process` | Answers the website's pending `submissions/{id}`: looks the signer's GitHub account up with Firebase Auth (`accounts:lookup`, then GitHub's `/user/{id}`), checks the package as `submit` does, and writes `status`, `message`, `itemId` back on the submission. At most `--per-user` (3) each run. |
| `refresh` | Checks every listed package again: a new release is checked and added; a repository that is gone, or is another repository now (its numeric id changed), marks the item **unavailable**. |
| `moderate` | A maintainer's `block`, `unblock`, `yank:<v>`, `unyank:<v>` or `trust:<level>`. |
| `export` | Writes `index.json` (catalog schema 1) into `--out` (`build/catalog`); the website is built from it. |
| `submit` | Checks and lists one package by hand (`--repo`, `--category`, `--submitter`). |

Every package is checked as an install would check it: the submitter
administers the repository; its release has a `just_release.json`; its id is a
package name, free, and not reserved (`just_*` is for official packages); the
archive downloads, matches the SHA-256 the release file names, and passes the
store's package check. The SHA-256 recorded then is the one every install
checks — a release changed afterwards is refused.

Records (Firestore, flat fields; nested data is JSON text):

- `submissions/{id}` — written by the website, answered by `process`.
- `items/{id}` — repository, its numeric id, owner, category, status
  (`listed`, `blocked`, `unavailable`), the catalog entry.
- `items/{id}/versions/{version}` — the version's entry, pinned by tag and
  SHA-256; `yanked`.
- `publishers/{login}` — name and trust (`official`, `verified`,
  `community`).

## Trying it locally

```text
dart run bin/backend.dart submit --repo https://github.com/you/pkg \
    --category characters --submitter you --memory store.json
dart run bin/backend.dart process --memory store.json --identities ids.json
dart run bin/backend.dart export --memory store.json --out build/catalog
```

`--memory` keeps the records in a JSON file instead of Firestore;
`--identities` maps Firebase uids to GitHub ids (`{"uid": 583231}`) instead of
asking Firebase Auth. GitHub calls still go to GitHub (set `GITHUB_TOKEN` for
the permission check).

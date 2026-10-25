/// The Just Asset Store's backend: the only writer of the store's records.
///
/// Runs in GitHub Actions, every hour ([StoreBackend.run]): the website's
/// submissions are answered — the signer's GitHub account looked up by the
/// backend itself, the repository's latest release checked by
/// [ReleaseCheck] — its reports become issues, and every watched
/// repository's new releases are checked in one GraphQL sweep. Maintainers
/// take down, withdraw, approve and set trust ([StoreBackend.moderate]).
/// When anything changed, the catalog is exported in pieces
/// ([StoreBackend.export]), with card pictures ([Thumbnails]), for the
/// website on Cloudflare Pages. The records are in Firestore
/// ([FirestoreDocumentStore]); browsers may only file a submission or a
/// report, and read their own submissions and notices.
library;

export 'src/backend.dart';
export 'src/commands.dart';
export 'src/documents.dart';
export 'src/firestore.dart';
export 'src/github.dart';
export 'src/identity.dart';
export 'src/pub_dev.dart';
export 'src/records.dart';
export 'src/release_check.dart';
export 'src/thumbnails.dart';

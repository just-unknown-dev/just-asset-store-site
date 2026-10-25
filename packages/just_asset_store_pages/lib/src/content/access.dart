/// Who may publish to the store.
///
/// The store's first version lists only Just Unknown's own packages,
/// released from the just-unknown-dev GitHub account; publishing opens to
/// everyone in a later version. The same switch is `openPublishing` in the
/// backend's `catalog.json` and `mayPublish` in `firestore.rules` (tests
/// keep the three in step).
abstract final class StoreAccess {
  /// Whether anyone may publish. Off in the first version.
  static const bool openPublishing = false;

  /// The GitHub account that publishes while [openPublishing] is off, by
  /// login (for show) and number (what is checked: a login can change
  /// hands).
  static const String officialLogin = 'just-unknown-dev';
  static const Set<String> officialIds = {'262105023'};

  /// Whether the GitHub account numbered [githubId] may publish.
  static bool mayPublish(String? githubId) =>
      openPublishing || officialIds.contains(githubId);
}

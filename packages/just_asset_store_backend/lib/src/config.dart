/// The backend's settings: `catalog.json` in the backend repository.
library;

import 'package:just_asset_store/just_asset_store.dart';

/// The backend's settings.
final class BackendConfig {
  /// The catalog's [source] and [categories]; who may moderate
  /// ([maintainerIds]) and who publishes officially ([officialPublishers]),
  /// by numeric GitHub id; whether anyone else may publish
  /// ([openPublishing]); the id prefixes only official publishers may use;
  /// the [site]'s address and the [backendRepo] issues go to.
  const BackendConfig({
    required this.source,
    required this.categories,
    required this.maintainerIds,
    required this.officialPublishers,
    required this.reservedPrefixes,
    required this.site,
    required this.backendRepo,
    this.openPublishing = false,
    this.maxArchiveBytes = defaultMaxArchiveBytes,
    this.featured = const [],
  });

  /// What a publisher hears while [openPublishing] is off.
  static const String closedMessage =
      'The Just Asset Store lists only Just Unknown\'s own packages for now. '
      'Publishing opens to everyone in a later version.';

  /// The largest archive the store lists: 512 MiB.
  static const int defaultMaxArchiveBytes = 512 * 1024 * 1024;

  /// Reads `catalog.json`.
  factory BackendConfig.parse(String text) {
    final json = JsonFields.parse(text);
    List<int> ids(String key) {
      final raw = json.raw(key);
      if (raw is! List || raw.any((v) => v is! int || v < 1)) {
        throw json.error(key, 'Expected a list of numeric GitHub ids.');
      }
      return raw.cast<int>();
    }

    return BackendConfig(
      source: StoreSourceInfo.fromJson(json.object('source')),
      categories: [
        for (final c in json.objects('categories')) StoreCategory.fromJson(c),
      ],
      maintainerIds: ids('maintainerIds'),
      officialPublishers: ids('officialPublishers'),
      reservedPrefixes: json.strings('reservedPrefixes'),
      site: json.string('site'),
      backendRepo: json.string('backendRepo'),
      openPublishing: json.flag('openPublishing'),
      maxArchiveBytes:
          json.optInt('maxArchiveBytes', min: 1) ?? defaultMaxArchiveBytes,
      featured: [
        for (final id in json.strings('featured'))
          StoreNames.isId(id)
              ? id
              : throw json.error('featured', '"$id" is not an item id.'),
      ],
    );
  }

  /// Who serves the catalog.
  final StoreSourceInfo source;

  /// The categories, in order.
  final List<StoreCategory> categories;

  /// The numeric GitHub ids allowed to block, yank, approve and set trust.
  /// Ids, not logins: a login can be given up and taken by someone else.
  final List<int> maintainerIds;

  /// The numeric GitHub ids whose packages are official: trusted as such
  /// from their first submission, and the only ones that may use
  /// [reservedPrefixes].
  final List<int> officialPublishers;

  /// Id prefixes only official publishers may use (`just_`).
  final List<String> reservedPrefixes;

  /// The website's address, without a final `/`.
  final String site;

  /// The store's private repository, `owner/name`, where reports and
  /// reviews are issues and maintainers moderate.
  final String backendRepo;

  /// Whether anyone may publish. Off in the store's first version: only
  /// [officialPublishers] publish, and everyone else's submissions and
  /// releases are refused ([closedMessage]).
  final bool openPublishing;

  /// The largest archive the store lists.
  final int maxArchiveBytes;

  /// The items the maintainers show first on the website, in order. One
  /// the catalog doesn't list is left out.
  final List<String> featured;

  /// Whether [id] may only be used by official publishers.
  bool isReserved(String id) => reservedPrefixes.any(id.startsWith);

  /// Whether the GitHub account numbered [githubId] may publish.
  bool mayPublish(int githubId) =>
      openPublishing || officialPublishers.contains(githubId);

  /// These settings with publishing [open] to everyone, or not.
  BackendConfig withPublishing({required bool open}) => BackendConfig(
    source: source,
    categories: categories,
    maintainerIds: maintainerIds,
    officialPublishers: officialPublishers,
    reservedPrefixes: reservedPrefixes,
    site: site,
    backendRepo: backendRepo,
    openPublishing: open,
    maxArchiveBytes: maxArchiveBytes,
    featured: featured,
  );
}

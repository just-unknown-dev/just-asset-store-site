/// The store's records, typed: how each Firestore document reads and is
/// written. Nested data is kept as JSON text, times as milliseconds since
/// 1970 (UTC) — numbers that sort, unlike ISO text of varying precision.
library;

import 'dart:convert';

import 'documents.dart';

Map<String, Object?> _map(Object? text) {
  if (text is! String || text.isEmpty) return {};
  final v = jsonDecode(text);
  return v is Map ? v.cast<String, Object?>() : {};
}

int _int(Object? v, [int fallback = 0]) => v is int ? v : fallback;

/// Where an item stands.
enum ItemStatus {
  /// In the catalog.
  listed,

  /// Its first version waits for a maintainer: not in the catalog yet.
  held,

  /// Taken down: in the catalog's `removed` list.
  blocked,

  /// Its repository is gone, private, or another one now: listed, but
  /// nothing new installs.
  unavailable;

  /// The status written [name]; [listed] for anything else.
  static ItemStatus of(Object? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => listed);
}

/// One version as the store keeps it.
final class VersionRecord {
  /// Its catalog [entry], its archive's [sha256], from release [releaseId].
  const VersionRecord({
    required this.entry,
    required this.sha256,
    required this.releaseId,
    required this.publishedMs,
    this.permissions = const [],
    this.yanked = false,
    this.blocked = false,
  });

  /// Reads one.
  factory VersionRecord.fromJson(Map<String, Object?> json) => VersionRecord(
    entry: (json['entry'] as Map? ?? const {}).cast<String, Object?>(),
    sha256: '${json['sha256'] ?? ''}',
    releaseId: _int(json['releaseId']),
    publishedMs: _int(json['publishedMs']),
    permissions: [
      for (final p in (json['permissions'] as List? ?? const [])) '$p',
    ],
    yanked: json['yanked'] == true,
    blocked: json['blocked'] == true,
  );

  /// The version's catalog entry, its archive pinned by tag and SHA-256.
  final Map<String, Object?> entry;

  /// Its archive's SHA-256.
  final String sha256;

  /// The GitHub release it came from.
  final int releaseId;

  /// When the store listed it.
  final int publishedMs;

  /// The permissions its manifest declared.
  final List<String> permissions;

  /// Withdrawn by a maintainer: kept where installed.
  final bool yanked;

  /// Taken down: projects that have it are warned.
  final bool blocked;

  /// This record, [yanked] and [blocked] as given.
  VersionRecord copyWith({bool? yanked, bool? blocked}) => VersionRecord(
    entry: entry,
    sha256: sha256,
    releaseId: releaseId,
    publishedMs: publishedMs,
    permissions: permissions,
    yanked: yanked ?? this.yanked,
    blocked: blocked ?? this.blocked,
  );

  /// This record as JSON.
  Map<String, Object?> toJson() => {
    'entry': entry,
    'sha256': sha256,
    'releaseId': releaseId,
    'publishedMs': publishedMs,
    if (permissions.isNotEmpty) 'permissions': permissions,
    if (yanked) 'yanked': true,
    if (blocked) 'blocked': true,
  };
}

/// A version waiting for a maintainer's `/store approve`.
final class PendingVersion {
  /// [version], held for [reasons]; [item] is the item's entry it brings.
  const PendingVersion({
    required this.version,
    required this.record,
    required this.item,
    required this.reasons,
    this.ownerId,
  });

  /// Reads one.
  factory PendingVersion.fromJson(Map<String, Object?> json) => PendingVersion(
    version: '${json['version']}',
    record: VersionRecord.fromJson(
      (json['record'] as Map? ?? const {}).cast<String, Object?>(),
    ),
    item: (json['item'] as Map? ?? const {}).cast<String, Object?>(),
    reasons: [for (final r in (json['reasons'] as List? ?? const [])) '$r'],
    ownerId: json['ownerId'] is int ? json['ownerId'] as int : null,
  );

  /// The version number.
  final String version;

  /// The version, as it will be listed.
  final VersionRecord record;

  /// The item's entry (without versions) this version brings.
  final Map<String, Object?> item;

  /// Why it waits.
  final List<String> reasons;

  /// Who owned the repository when it was checked: approving it accepts
  /// them.
  final int? ownerId;

  /// This pending version as JSON.
  Map<String, Object?> toJson() => {
    'version': version,
    'record': record.toJson(),
    'item': item,
    'reasons': reasons,
    'ownerId': ?ownerId,
  };
}

/// Where one of an item's pictures comes from: a release file, pinned.
typedef ThumbSource = ({Uri url, String sha256});

List<ThumbSource> _pictures(Object? text) {
  if (text is! String || text.isEmpty) return const [];
  final v = jsonDecode(text);
  return [
    if (v is List)
      for (final p in v)
        if (p is Map && p['url'] is String && p['sha256'] is String)
          (url: Uri.parse('${p['url']}'), sha256: '${p['sha256']}'),
  ];
}

/// An item: `items/{id}`.
final class ItemRecord {
  /// The record of item [id].
  ItemRecord({
    required this.id,
    required this.repo,
    required this.repoId,
    required this.repoNode,
    required this.ownerId,
    required this.claimant,
    required this.status,
    required this.item,
    this.versions = const {},
    this.pending,
    this.blockedReason,
    this.pictures = const [],
    this.attempts = 0,
    this.nextTryMs = 0,
    this.lastError,
    this.createdMs = 0,
    this.updatedMs = 0,
  });

  /// Reads `items/[id]`.
  factory ItemRecord.fromDoc(String id, Map<String, Object?> doc) {
    return ItemRecord(
      id: id,
      repo: '${doc['repo']}',
      repoId: _int(doc['repoId']),
      repoNode: '${doc['repoNode'] ?? ''}',
      ownerId: _int(doc['ownerId']),
      claimant: _int(doc['claimant']),
      status: ItemStatus.of(doc['status']),
      item: _map(doc['item']),
      versions: {
        for (final e in _map(doc['versions']).entries)
          e.key: VersionRecord.fromJson(
            (e.value as Map? ?? const {}).cast<String, Object?>(),
          ),
      },
      pending: doc['pending'] is String && (doc['pending'] as String).isNotEmpty
          ? PendingVersion.fromJson(_map(doc['pending']))
          : null,
      blockedReason: doc['blockedReason'] as String?,
      pictures: _pictures(doc['pictures']),
      attempts: _int(doc['attempts']),
      nextTryMs: _int(doc['nextTryMs']),
      lastError: doc['lastError'] as String?,
      createdMs: _int(doc['createdMs']),
      updatedMs: _int(doc['updatedMs']),
    );
  }

  /// Its id.
  final String id;

  /// Its repository, `owner/name`, as last seen.
  String repo;

  /// Its repository's numeric id.
  final int repoId;

  /// Its repository's GraphQL node id.
  final String repoNode;

  /// The numeric id of the account that owned the repository when it was
  /// listed: a transfer holds its next version for a maintainer.
  int ownerId;

  /// The numeric GitHub id of its publisher: the account whose claim code
  /// its releases carry.
  final int claimant;

  /// Where it stands.
  ItemStatus status;

  /// Its catalog entry, without versions, trust, publisher or repoId.
  Map<String, Object?> item;

  /// Its listed versions, by version number.
  Map<String, VersionRecord> versions;

  /// A version waiting for a maintainer.
  PendingVersion? pending;

  /// Why it was taken down.
  String? blockedReason;

  /// Its pictures' sources, the first its card picture: the newest
  /// version's, pinned.
  List<ThumbSource> pictures;

  /// Failed tries at its newest release (a network problem, say).
  int attempts;

  /// When to try again.
  int nextTryMs;

  /// The last failure, for its publisher.
  String? lastError;

  /// When it was first listed.
  final int createdMs;

  /// When it last changed: the export rebuilds what changed since it last
  /// ran.
  int updatedMs;

  /// Its document.
  Map<String, Object?> toDoc() => {
    'repo': repo,
    'repoId': repoId,
    'repoNode': repoNode,
    'ownerId': ownerId,
    'claimant': claimant,
    'status': status.name,
    'item': jsonEncode(item),
    'versions': jsonEncode({
      for (final e in versions.entries) e.key: e.value.toJson(),
    }),
    'pending': pending == null ? null : jsonEncode(pending!.toJson()),
    'blockedReason': blockedReason,
    'pictures': pictures.isEmpty
        ? null
        : jsonEncode([
            for (final p in pictures) {'url': '${p.url}', 'sha256': p.sha256},
          ]),
    'attempts': attempts,
    'nextTryMs': nextTryMs,
    'lastError': lastError,
    'createdMs': createdMs,
    'updatedMs': updatedMs,
  };
}

/// What the sweep knows of one repository.
final class RepoWatch {
  /// Repository [node] holds item [item]; [seen] are the releases already
  /// handled, [refused] those refused (and why).
  RepoWatch({
    required this.node,
    required this.item,
    required this.claimant,
    this.repo = '',
    this.gone = false,
    List<int>? seen,
    Map<int, String>? refused,
  }) : seen = seen ?? [],
       refused = refused ?? {};

  /// Reads one.
  factory RepoWatch.fromJson(Map<String, Object?> json) => RepoWatch(
    node: '${json['node']}',
    item: '${json['item']}',
    claimant: _int(json['claimant']),
    repo: '${json['repo'] ?? ''}',
    gone: json['gone'] == true,
    seen: [for (final s in (json['seen'] as List? ?? const [])) _int(s)],
    refused: {
      for (final e in ((json['refused'] as Map?) ?? const {}).entries)
        int.tryParse('${e.key}') ?? 0: '${e.value}',
    },
  );

  /// The most releases remembered of each kind: a sweep looks at the five
  /// newest only.
  static const int memory = 20;

  /// The repository's GraphQL node id.
  final String node;

  /// The item it holds.
  final String item;

  /// The numeric GitHub id of the item's publisher.
  final int claimant;

  /// `owner/name` as the sweep last saw it.
  String repo;

  /// Whether the sweep last found the repository gone (or private).
  bool gone;

  /// Releases handled.
  final List<int> seen;

  /// Releases refused, and why.
  final Map<int, String> refused;

  /// Records release [id] as handled.
  void sawRelease(int id) {
    seen
      ..remove(id)
      ..add(id);
    while (seen.length > memory) {
      seen.removeAt(0);
    }
    refused.remove(id);
  }

  /// Records release [id] as refused for [reason].
  void refusedRelease(int id, String reason) {
    refused
      ..remove(id)
      ..[id] = reason;
    while (refused.length > memory) {
      refused.remove(refused.keys.first);
    }
  }

  /// Whether release [id] was handled or refused already.
  bool knows(int id) => seen.contains(id) || refused.containsKey(id);

  /// This watch as JSON.
  Map<String, Object?> toJson() => {
    'node': node,
    'item': item,
    'claimant': claimant,
    'repo': repo,
    if (gone) 'gone': true,
    'seen': seen,
    'refused': {for (final e in refused.entries) '${e.key}': e.value},
  };
}

/// Every repository the sweep watches, by numeric id: `meta/repos-0` to
/// `meta/repos-7`, a few reads however many items there are.
final class RepoShards {
  RepoShards._(this._shards);

  /// How many documents the watches are spread over.
  static const int count = 8;

  static String _path(int shard) => 'meta/repos-$shard';

  /// Reads them from [store].
  static Future<RepoShards> load(DocumentStore store) async {
    final shards = <int, Map<int, RepoWatch>>{};
    for (var s = 0; s < count; s++) {
      final doc = await store.get(_path(s));
      shards[s] = {
        for (final e in _map(doc?['repos']).entries)
          int.tryParse(e.key) ?? 0: RepoWatch.fromJson(
            (e.value as Map? ?? const {}).cast<String, Object?>(),
          ),
      };
    }
    return RepoShards._(shards);
  }

  final Map<int, Map<int, RepoWatch>> _shards;
  final Set<int> _changed = {};

  /// Every watch, by repository id.
  Map<int, RepoWatch> get all => {
    for (final s in _shards.values) ...s,
  };

  /// The watch of repository [repoId], or null.
  RepoWatch? operator [](int repoId) => _shards[repoId % count]![repoId];

  /// Watches repository [repoId] with [watch].
  void operator []=(int repoId, RepoWatch watch) {
    _shards[repoId % count]![repoId] = watch;
    changed(repoId);
  }

  /// Notes that [repoId]'s watch changed, so its document is written.
  void changed(int repoId) => _changed.add(repoId % count);

  /// Writes the documents that changed to [store].
  Future<void> save(DocumentStore store) async {
    for (final s in _changed) {
      await store.set(_path(s), {
        'repos': jsonEncode({
          for (final e in _shards[s]!.entries) '${e.key}': e.value.toJson(),
        }),
      });
    }
    _changed.clear();
  }
}

/// The catalog's state: `meta/state`.
final class StoreState {
  /// [dirty] when something changed since the last deploy.
  StoreState({
    this.dirty = false,
    this.exportedMs = 0,
    this.lastFullMs = 0,
    this.rootSha,
  });

  /// Reads `meta/state` from [store].
  static Future<StoreState> load(DocumentStore store) async {
    final doc = await store.get(path) ?? const {};
    return StoreState(
      dirty: doc['dirty'] == true,
      exportedMs: _int(doc['exportedMs']),
      lastFullMs: _int(doc['lastFullMs']),
      rootSha: doc['rootSha'] as String?,
    );
  }

  /// Where it is.
  static const String path = 'meta/state';

  /// Whether the records changed since the catalog was last deployed.
  bool dirty;

  /// When the last deployed export started: what changed after it is in
  /// the next one.
  int exportedMs;

  /// When the last full export started.
  int lastFullMs;

  /// The SHA-256 of the deployed `index.json`.
  String? rootSha;

  /// Writes it to [store].
  Future<void> save(DocumentStore store) => store.set(path, {
    'dirty': dirty,
    'exportedMs': exportedMs,
    'lastFullMs': lastFullMs,
    'rootSha': rootSha,
  });
}

/// A publisher: `publishers/{githubId}`.
final class PublisherRecord {
  /// The account numbered [id], called [login], trusted at [trust].
  PublisherRecord({
    required this.id,
    required this.login,
    this.trust = 'community',
    this.updatedMs = 0,
  });

  /// Reads `publishers/[id]`.
  factory PublisherRecord.fromDoc(int id, Map<String, Object?> doc) =>
      PublisherRecord(
        id: id,
        login: '${doc['login'] ?? id}',
        trust: '${doc['trust'] ?? 'community'}',
        updatedMs: _int(doc['updatedMs']),
      );

  /// The account's numeric id: trust follows it, not its login.
  final int id;

  /// Its login, as last seen.
  String login;

  /// `official`, `verified` or `community`.
  String trust;

  /// When it last changed.
  int updatedMs;

  /// Its document.
  Map<String, Object?> toDoc() => {
    'login': login,
    'trust': trust,
    'updatedMs': updatedMs,
  };
}

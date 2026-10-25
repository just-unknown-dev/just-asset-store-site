/// Checking one GitHub release before the store lists it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_core_cli/fetch.dart';

import 'config.dart';
import 'thumbnails.dart';
import 'github.dart';
import 'pub_dev.dart';
import 'records.dart';

/// What checking a release decided.
sealed class Verdict {
  const Verdict();
}

/// The release may be listed — or, with [holds], waits for a maintainer.
final class Accepted extends Verdict {
  /// Version [version] of [item], as [record] keeps it.
  const Accepted({
    required this.item,
    required this.version,
    required this.record,
    this.holds = const [],
    this.pictures = const [],
    this.same = false,
  });

  /// The item's catalog entry, without versions, trust, publisher or
  /// repoId.
  final Map<String, Object?> item;

  /// The version number.
  final String version;

  /// The version, as the store keeps it.
  final VersionRecord record;

  /// Why a maintainer must look first; empty when it may be listed now.
  final List<String> holds;

  /// Its pictures' sources: its first previews whose SHA-256 GitHub
  /// recorded ([Thumbnails.maxPictures] at most), the first its card
  /// picture.
  final List<ThumbSource> pictures;

  /// The version is listed (or waiting) already, with these very bytes:
  /// nothing to do.
  final bool same;
}

/// The release can't be listed, for [message] — its publisher's to fix.
final class Refused extends Verdict {
  /// Refused for [message].
  const Refused(this.message);

  /// Why, for the publisher.
  final String message;
}

/// The release could not be checked now (GitHub or the network failed):
/// try again later.
final class Retry extends Verdict {
  /// Not checked, because of [message].
  const Retry(this.message);

  /// What failed.
  final String message;
}

/// Who a release must be claimed by: the publisher's numeric GitHub id and
/// login, and how far the store trusts them.
typedef Claim = ({int id, String login, TrustLevel trust});

/// Checks releases as [config] says, asking [github].
final class ReleaseCheck {
  /// The checks.
  const ReleaseCheck({
    required this.github,
    required this.config,
    required this.pubDev,
  });

  /// GitHub.
  final GitHubApi github;

  /// pub.dev: names taken there, and what packages bring.
  final PubDevApi pubDev;

  /// The settings.
  final BackendConfig config;

  /// The most a `just_release.json` may be.
  static const int maxReleaseFile = 1 << 20;

  /// Checks [release] of [repo], claimed by [claim], against [existing]
  /// (the item it updates, when there is one) and, for a new item, the ids
  /// of other publishers' items ([otherIds]).
  ///
  /// In order: the release is published and immutable; its
  /// `just_release.json` names its own tag and carries [claim]'s code; the
  /// item's id is a package name (and a reserved one only for official
  /// publishers); a listed version never changes; the archive is the
  /// release file of the size and SHA-256 the release file says; a look at
  /// the archive's directory and two small files, read in parts, passes
  /// the installer's rules; then the archive, downloaded once, matches its
  /// SHA-256 and passes them all. Finally, what a maintainer should see
  /// first holds it ([Accepted.holds]).
  Future<Verdict> check({
    required RepoInfo repo,
    required ReleaseInfo release,
    required Claim claim,
    ItemRecord? existing,
    Set<String> otherIds = const {},
  }) async {
    try {
      return await _check(repo, release, claim, existing, otherIds);
    } on GitHubBusy catch (e) {
      return Retry(e.message);
    } on PubDevBusy catch (e) {
      return Retry(e.message);
    } on FetchException catch (e) {
      final status = e.statusCode;
      if (status == null || status >= 500 || status == 429) {
        return Retry(e.message);
      }
      return Refused('A release file could not be downloaded: $e');
    } on IOException catch (e) {
      return Retry('$e');
    } on TimeoutException catch (e) {
      return Retry('$e');
    }
  }

  Future<Verdict> _check(
    RepoInfo repo,
    ReleaseInfo release,
    Claim claim,
    ItemRecord? existing,
    Set<String> otherIds,
  ) async {
    final tag = release.tag;
    // Also for a repository watched from before publishing closed.
    if (!config.mayPublish(claim.id)) {
      return const Refused(BackendConfig.closedMessage);
    }
    if (release.draft) return Refused('$tag is a draft.');
    if (!release.immutable) {
      return Refused(
        '$tag is not an immutable release. Turn on release immutability '
        '(Settings → General → Releases), then publish a new version: the '
        'store lists only releases whose files can never be swapped.',
      );
    }

    // just_release.json: what the release holds, and who may publish it.
    final fileAsset = release.asset(JustRelease.fileName);
    if (fileAsset == null) {
      return Refused(
        '$tag has no ${JustRelease.fileName}. Make releases with the store\'s '
        'release workflow (`just store pack` writes the file).',
      );
    }
    if (fileAsset.size > maxReleaseFile) {
      return Refused('Its ${JustRelease.fileName} is too large.');
    }
    final fileBytes = await github.download(
      fileAsset.url,
      maxBytes: maxReleaseFile,
    );
    if (fileAsset.sha256 != null &&
        Sha256.hexOf(fileBytes) != fileAsset.sha256) {
      return const Refused(
        'Its just_release.json is not the file GitHub recorded.',
      );
    }
    final JustRelease file;
    try {
      file = JustRelease.parse(utf8.decode(fileBytes));
    } on StoreFormatException catch (e) {
      return Refused('Its ${JustRelease.fileName} is not valid: $e');
    } on FormatException {
      return Refused('Its ${JustRelease.fileName} is not UTF-8 text.');
    }
    if (file.tag != tag) {
      return Refused(
        'Its ${JustRelease.fileName} was made for ${file.tag}, not $tag.',
      );
    }
    final code = claimCode(claim.id);
    if (file.claim != code) {
      return Refused(
        'Its ${JustRelease.fileName} does not carry @${claim.login}\'s claim '
        'code. Set the repository variable JUST_STORE_CLAIM to $code (the '
        'Publish page shows it), and publish a new version.',
      );
    }

    final manifest = file.manifest;
    final idProblem = StoreNames.idProblem(manifest.id);
    if (idProblem != null) return Refused('`${manifest.id}`: $idProblem');
    if (config.isReserved(manifest.id) &&
        !config.officialPublishers.contains(claim.id)) {
      return Refused(
        'Ids starting with "${config.reservedPrefixes.firstWhere(manifest.id.startsWith)}" '
        'are kept for the official packages. Choose another id.',
      );
    }
    if (!config.categories.any((c) => c.id == manifest.category)) {
      return Refused('"${manifest.category}" is not one of the store\'s categories.');
    }
    if (existing != null && existing.id != manifest.id) {
      return Refused(
        'This repository holds `${existing.id}`; this release is '
        '`${manifest.id}`.',
      );
    }

    final StoreItem item;
    try {
      item = GitHubSource(repo.repo).indexFor(file).items.single;
    } on StoreFormatException catch (e) {
      return Refused('Its ${JustRelease.fileName} is not valid: $e');
    }
    var version = item.versions.single;
    final number = '${version.version}';
    final pin = version.archive;
    if (pin == null) return const Refused('The release names no archive.');
    if (pin.size > config.maxArchiveBytes) {
      return Refused(
        'Its archive is ${pin.size} bytes; the store lists archives of up to '
        '${config.maxArchiveBytes >> 20} MiB.',
      );
    }

    // A listed version never changes: the same bytes again are nothing to
    // do, other bytes are refused.
    final listed = existing?.versions[number];
    final waiting = existing?.pending?.version == number
        ? existing!.pending!.record
        : null;
    final known = listed ?? waiting;
    if (known != null) {
      if (known.sha256 == pin.sha256) {
        return Accepted(item: const {}, version: number, record: known, same: true);
      }
      return Refused(
        '$number is ${listed != null ? 'listed' : 'waiting for review'} '
        'already, with other bytes. A version never changes: publish a new '
        'one.',
      );
    }

    // What pub.dev knows. A name taken there is not a new community item
    // (the store's own team is trusted with its names). The native code an
    // item's packages bring is listed whatever its release says, and its
    // manifest must declare it (the package check below).
    final pubHolds = <String>[];
    if (claim.trust != TrustLevel.official &&
        existing == null &&
        item.kind.isVendored &&
        await pubDev.versions(item.id) != null) {
      return Refused(
        'A package called "${item.id}" is on pub.dev. The store installs an '
        'item as the package of its name, for the whole project, so it '
        "would take that one's place: choose another id.",
      );
    }
    if (version.pubDependencies.isNotEmpty) {
      final scan = await PubNativeScan.of(
        pubDev,
        version.pubDependencies,
        provided: {...version.requires, ...version.dependencies},
      );
      final unlisted = [
        for (final name in scan.native)
          if (!version.nativePlugins.contains(name)) name,
      ];
      if (unlisted.isNotEmpty) {
        version = StoreItemVersion.fromJson(
          JsonFields({
            ...version.toJson(),
            'nativePlugins': [...version.nativePlugins, ...unlisted],
          }),
          item.kind,
        );
      }
      if (!scan.complete) {
        pubHolds.add(
          'It brings more packages from pub.dev than the store checks for '
          'native code (${PubNativeScan.maxPackages}).',
        );
      }
    }

    final archiveAsset = release.asset(pin.url.split('/').last);
    if (archiveAsset == null) {
      return Refused('$tag has no ${pin.url.split('/').last}.');
    }
    if (archiveAsset.size != pin.size ||
        (archiveAsset.sha256 != null && archiveAsset.sha256 != pin.sha256)) {
      return const Refused(
        'The archive is not the file its just_release.json describes (its '
        'size or SHA-256 differs).',
      );
    }

    try {
      // A look first, at a few kilobytes: the directory and the two files
      // the rules read. Only when GitHub recorded the archive's SHA-256, so
      // what is read in parts is the file the catalog will pin.
      if (archiveAsset.sha256 != null) {
        Future<Uint8List> read(int start, int end) =>
            github.readRange(archiveAsset.url, start, end);
        try {
          final dir = await ZipDirectory.fetch(read, pin.size);
          PackageCheck.checkLayout(
            await PackageCheck.layoutOf(dir, read),
            item,
            version,
          );
        } on FetchException catch (e) {
          // A server that can't send parts: the full check decides.
          if (e.statusCode != 200) rethrow;
        }
      }
      final bytes = await github.download(archiveAsset.url, maxBytes: pin.size);
      checkPinned(
        bytes,
        size: pin.size,
        sha256: pin.sha256,
        what: '${item.name} $number',
      );
      PackageCheck.verify(ZipArchive.read(bytes), item, version);
    } on PackageCheckException catch (e) {
      return Refused('$e');
    } on DownloadException catch (e) {
      return Refused(e.message);
    } on ZipFormatException catch (e) {
      return Refused('The archive is not one the store can read: ${e.message}');
    } on UnsafePathException catch (e) {
      return Refused('The archive is not one the store can read: $e');
    }

    // Its pictures are release files beside the archive, pinned to the tag
    // by the SHA-256 GitHub recorded: the store serves copies of them, so
    // pages never load pictures from elsewhere.
    final pictures = <ThumbSource>[];
    for (final path in manifest.previews) {
      if (pictures.length == Thumbnails.maxPictures) break;
      final name = path.split('/').last;
      final sha = release.asset(name)?.sha256;
      if (sha == null) continue;
      pictures.add((url: repo.repo.releaseFile(name, tag: tag), sha256: sha));
    }
    final entry = item.toJson()
      ..remove('versions')
      ..remove('trust')
      ..remove('publisher')
      ..remove('repoId')
      ..remove('unavailable')
      ..remove('thumbnail')
      ..remove('previews');
    return Accepted(
      item: entry,
      version: number,
      record: VersionRecord(
        entry: version.toJson(),
        sha256: pin.sha256,
        releaseId: release.id,
        publishedMs: (release.publishedAt ?? DateTime.now())
            .millisecondsSinceEpoch,
        permissions: [for (final p in manifest.permissions) p.id],
      ),
      holds: [
        ...pubHolds,
        ...holds(
          trust: claim.trust,
          item: item,
          version: version,
          permissions: {for (final p in manifest.permissions) p.id},
          repo: repo,
          existing: existing,
          otherIds: otherIds,
        ),
      ],
      pictures: pictures,
    );
  }

  /// Why a maintainer should look at this version before it is listed.
  ///
  /// Nothing, for an official publisher. For the others: a version that
  /// newly brings native code, a change of kind, or a repository that
  /// changed hands since the item was listed. For community publishers
  /// also: a first version with native code, an id that looks like another
  /// publisher's, and a version that adds pub.dev packages or declares new
  /// permissions — what a harmless package turned harmful would do.
  static List<String> holds({
    required TrustLevel trust,
    required StoreItem item,
    required StoreItemVersion version,
    required Set<String> permissions,
    required RepoInfo repo,
    ItemRecord? existing,
    Set<String> otherIds = const {},
  }) {
    if (trust == TrustLevel.official) return const [];
    final community = trust == TrustLevel.community;
    final out = <String>[];
    if (existing == null) {
      final near = community ? lookAlike(item.id, otherIds) : null;
      if (near != null) {
        out.add('Its id "${item.id}" looks like "$near", another publisher\'s.');
      }
      if (community && version.nativePlugins.isNotEmpty) {
        out.add(
          'It brings native code: ${version.nativePlugins.join(', ')}.',
        );
      }
      return out;
    }
    final previous = _latest(existing);
    final before = previous == null
        ? null
        : StoreItemVersion.fromJson(JsonFields(previous.entry), item.kind);
    final addedNative = version.nativePlugins
        .where((p) => !(before?.nativePlugins.contains(p) ?? false))
        .toList();
    if (addedNative.isNotEmpty) {
      out.add('It adds native code: ${addedNative.join(', ')}.');
    }
    if ('${existing.item['kind']}' != item.kind.id) {
      out.add('It changes kind, from ${existing.item['kind']} to ${item.kind.id}.');
    }
    if (repo.ownerId != existing.ownerId) {
      out.add(
        'Its repository changed hands since it was listed (now '
        '${repo.repo.owner}).',
      );
    }
    if (community) {
      final addedPub = version.pubDependencies.keys
          .where((p) => !(before?.pubDependencies.containsKey(p) ?? false))
          .toList();
      if (addedPub.isNotEmpty) {
        out.add('It adds packages from pub.dev: ${addedPub.join(', ')}.');
      }
      final addedPermissions = permissions
          .where((p) => !(previous?.permissions.contains(p) ?? false))
          .toList();
      if (addedPermissions.isNotEmpty) {
        out.add('It asks for more: ${addedPermissions.join(', ')}.');
      }
    }
    return out;
  }

  static VersionRecord? _latest(ItemRecord item) {
    VersionRecord? best;
    Version? bestVersion;
    for (final e in item.versions.entries) {
      final v = Version.tryParse(e.key);
      if (v == null) continue;
      if (bestVersion == null || v > bestVersion) {
        best = e.value;
        bestVersion = v;
      }
    }
    return best;
  }

  /// The id among [others] that [id] could be mistaken for — the same
  /// once `_` and `-` are dropped and look-alike characters (0/o, 1/l/i,
  /// 5/s) are made one, or one edit apart then — or null.
  static String? lookAlike(String id, Iterable<String> others) {
    final mine = _plain(id);
    for (final other in others) {
      if (other == id) continue;
      final theirs = _plain(other);
      if (mine == theirs || _withinOneEdit(mine, theirs)) return other;
    }
    return null;
  }

  static String _plain(String id) => id
      .toLowerCase()
      .replaceAll(RegExp('[-_]'), '')
      .replaceAll('0', 'o')
      .replaceAll(RegExp('[1i]'), 'l')
      .replaceAll('5', 's');

  static bool _withinOneEdit(String a, String b) {
    if ((a.length - b.length).abs() > 1) return false;
    if (a.length == b.length) {
      var diff = 0;
      for (var i = 0; i < a.length; i++) {
        if (a[i] != b[i] && ++diff > 1) return false;
      }
      return true;
    }
    final (short, long) = a.length < b.length ? (a, b) : (b, a);
    var i = 0;
    var j = 0;
    var skipped = false;
    while (i < short.length && j < long.length) {
      if (short[i] == long[j]) {
        i++;
        j++;
      } else if (skipped) {
        return false;
      } else {
        skipped = true;
        j++;
      }
    }
    return true;
  }
}

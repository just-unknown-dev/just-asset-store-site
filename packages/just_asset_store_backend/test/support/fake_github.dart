// A GitHub in memory for the backend's tests: repositories, releases whose
// files are real packed packages, accounts, and issues.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_asset_store_backend/just_asset_store_backend.dart';
import 'package:just_core_cli/fetch.dart';

/// One repository.
final class FakeRepo {
  FakeRepo(this.repo, {required this.id, required this.ownerId});

  GitHubRepo repo;
  final int id;
  int ownerId;
  bool gone = false;
  bool isPrivate = false;

  /// Oldest first.
  final List<ReleaseInfo> releases = [];

  String get nodeId => 'R_$id';
}

final class FakeGitHub implements GitHubApi {
  final Map<String, FakeRepo> _repos = {};
  final Map<int, String> logins = {};
  final Map<String, Uint8List> files = {};
  final List<({String repo, String title, String body, List<String> labels})>
  issues = [];

  /// Repositories (`owner/name`) whose every call fails as GitHub being
  /// down would.
  final Set<String> busy = {};

  /// Repositories whose calls throw something unexpected.
  final Set<String> broken = {};

  /// Whether file servers refuse ranges (answer 200).
  bool noRanges = false;

  int downloads = 0;
  int rangeReads = 0;
  int rangeBytes = 0;
  int sweeps = 0;

  /// Questions about one repository (its details, a release).
  int calls = 0;
  int _ids = 900;

  FakeRepo addRepo(String full, {required int id, required int ownerId}) =>
      _repos[full] = FakeRepo(GitHubRepo.tryParse(full)!, id: id, ownerId: ownerId);

  FakeRepo repoNamed(String full) => _repos[full]!;

  /// Moves [from] to [to] (a rename or a transfer); its id stays.
  void move(String from, String to, {int? ownerId}) {
    final r = _repos.remove(from)!;
    r.repo = GitHubRepo.tryParse(to)!;
    if (ownerId != null) r.ownerId = ownerId;
    _repos[to] = r;
  }

  FakeRepo? _byFull(GitHubRepo repo) => _repos['$repo'];

  void _check(GitHubRepo repo) {
    if (busy.contains('$repo')) throw const GitHubBusy('GitHub is down.');
    if (broken.contains('$repo')) throw StateError('Something unexpected.');
  }

  /// Packs package [id] at [version] for real and publishes it as a release
  /// of [full], tagged v[version], claimed by [claimant].
  ReleaseInfo publish(
    String full, {
    required String id,
    required String version,
    required int claimant,
    String kind = 'content',
    String category = 'characters',
    bool immutable = true,
    bool digests = true,
    bool draft = false,
    String? claim,
    List<String> nativePlugins = const [],
    Map<String, String> pubDependencies = const {},
    List<String>? permissions,
    String? stage,
    Map<String, String> extraFiles = const {},
    Map<String, Uint8List> previews = const {},
    String? content,
  }) {
    // An honest creator declares the native code they bring.
    permissions ??= nativePlugins.isEmpty ? const [] : const ['native'];
    final repo = _repos[full]!;
    final dir = Directory.systemTemp.createTempSync('pkg_');
    try {
      void write(String path, String text) => File('${dir.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(text);
      final code = kind != 'content';
      write(
        'pubspec.yaml',
        'name: $id\nversion: $version\nenvironment:\n  sdk: ^3.0.0\n'
        '${code ? '' : 'flutter:\n  assets:\n    - sprites/\n'}'
        '${code && pubDependencies.isNotEmpty ? 'dependencies:\n${[for (final e in pubDependencies.entries) "  ${e.key}: '${e.value}'\n"].join()}' : ''}',
      );
      write(
        'just_store.json',
        jsonEncode({
          'schema': 1,
          'id': id,
          'name': 'Knight',
          'summary': 'A knight.',
          'version': version,
          'kind': kind,
          'category': category,
          // Every plugin names its stage.
          'stage': ?(stage ??
              (kind == 'kit' || kind == 'editor-extension' ? 'beta' : null)),
          if (!code)
            'content': {
              'assetFolders': ['sprites/'],
            },
          if (permissions.isNotEmpty) 'permissions': permissions,
          if (previews.isNotEmpty) 'previews': [for (final p in previews.keys) 'sprites/$p'],
        }),
      );
      if (code) {
        write('lib/$id.dart', '// $id $version\n');
      } else {
        write('sprites/knight.png', content ?? 'png-$version');
        for (final p in previews.keys) {
          File('${dir.path}/sprites/$p').writeAsBytesSync(previews[p]!);
        }
      }
      final packed = Packer.pack(dir);
      // Extra files go in after packing, so a package the packer would
      // refuse can be published anyway, as a hostile one would be.
      var archive = packed.bytes;
      if (extraFiles.isNotEmpty) {
        final zip = ZipWriter();
        ZipArchive.read(archive).extractAll().forEach(zip.add);
        extraFiles.forEach((path, text) => zip.add(path, utf8.encode(text)));
        archive = zip.close();
      }
      final tag = 'v$version';
      final versionJson = packed.versionJson(packed.fileName)
        ..['nativePlugins'] = nativePlugins
        ..['pubDependencies'] = pubDependencies;
      (versionJson['archive'] as Map)
        ..['sha256'] = Sha256.hexOf(archive)
        ..['size'] = archive.length;
      final file = JustRelease(
        tag: tag,
        manifest: packed.manifest,
        version: versionJson,
        claim: claim ?? claimCode(claimant),
      );
      final fileBytes = Uint8List.fromList(utf8.encode(file.toText()));
      ReleaseAsset asset(String name, Uint8List bytes) {
        final url = Uri.parse(
          'https://github.com/${repo.repo}/releases/download/$tag/$name',
        );
        files['$url'] = bytes;
        return ReleaseAsset(
          name: name,
          size: bytes.length,
          url: url,
          sha256: digests ? Sha256.hexOf(bytes) : null,
        );
      }

      final release = ReleaseInfo(
        id: _ids++,
        tag: tag,
        immutable: immutable,
        draft: draft,
        publishedAt: DateTime.utc(2026, 10, 9),
        assets: [
          asset(packed.fileName, archive),
          asset(JustRelease.fileName, fileBytes),
          for (final p in previews.entries) asset(p.key, p.value),
        ],
      );
      repo.releases.add(release);
      return release;
    } finally {
      dir.deleteSync(recursive: true);
    }
  }

  @override
  Future<RepoInfo?> repo(GitHubRepo repo) async {
    calls++;
    _check(repo);
    final r = _byFull(repo);
    if (r == null || r.gone || r.isPrivate) return null;
    return RepoInfo(repo: r.repo, id: r.id, nodeId: r.nodeId, ownerId: r.ownerId);
  }

  @override
  Future<List<SweptRepo?>> sweep(List<String> nodeIds) async {
    sweeps++;
    return [
      for (final node in nodeIds)
        switch (_repos.values.where((r) => r.nodeId == node).firstOrNull) {
          final r? when !r.gone && !r.isPrivate => SweptRepo(
            id: r.id,
            repo: r.repo,
            ownerId: r.ownerId,
            releases: [
              for (final rel in r.releases.reversed.take(5))
                (id: rel.id, tag: rel.tag, draft: rel.draft),
            ],
          ),
          _ => null,
        },
    ];
  }

  @override
  Future<ReleaseInfo?> release(GitHubRepo repo, {int? id}) async {
    calls++;
    _check(repo);
    final r = _byFull(repo);
    if (r == null || r.gone) return null;
    if (id == null) {
      return r.releases.where((rel) => !rel.draft).lastOrNull;
    }
    return r.releases.where((rel) => rel.id == id).firstOrNull;
  }

  @override
  Future<String?> login(int id) async => logins[id];

  @override
  Future<Uint8List> download(Uri url, {required int maxBytes}) async {
    final bytes = files['$url'];
    if (bytes == null) {
      throw FetchException('Not found.', uri: url, statusCode: 404);
    }
    if (bytes.length > maxBytes) {
      throw FetchException('The download is larger than expected.', uri: url);
    }
    downloads++;
    return bytes;
  }

  @override
  Future<Uint8List> readRange(Uri url, int start, int end) async {
    if (noRanges) {
      throw FetchException('Whole file sent.', uri: url, statusCode: 200);
    }
    final bytes = files['$url'];
    if (bytes == null) {
      throw FetchException('Not found.', uri: url, statusCode: 404);
    }
    rangeReads++;
    rangeBytes += end - start;
    return Uint8List.sublistView(bytes, start, end);
  }

  @override
  Future<int> openIssue(
    String repo, {
    required String title,
    required String body,
    List<String> labels = const [],
  }) async {
    issues.add((repo: repo, title: title, body: body, labels: labels));
    return issues.length;
  }
}

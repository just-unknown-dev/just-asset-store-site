/// What the backend asks GitHub: who owns a repository, what its releases
/// hold, and bytes of their files.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_core_cli/fetch.dart';

/// GitHub could not answer now (a rate limit, an outage): try again later.
final class GitHubBusy implements Exception {
  /// Why, in a sentence.
  const GitHubBusy(this.message);

  /// Why.
  final String message;

  @override
  String toString() => message;
}

/// A repository, as GitHub's REST API describes it.
final class RepoInfo {
  /// [repo], numbered [id] (and [nodeId] in GraphQL), owned by the account
  /// numbered [ownerId].
  const RepoInfo({
    required this.repo,
    required this.id,
    required this.nodeId,
    required this.ownerId,
    this.isPrivate = false,
    this.archived = false,
  });

  /// Reads one from a `GET /repos/{owner}/{repo}` answer.
  static RepoInfo? fromRest(Object? json) {
    if (json is! Map) return null;
    final full = GitHubRepo.tryParse('${json['full_name']}');
    final owner = json['owner'];
    final id = json['id'];
    final node = json['node_id'];
    if (full == null || owner is! Map || id is! int || node is! String) {
      return null;
    }
    final ownerId = owner['id'];
    if (ownerId is! int) return null;
    return RepoInfo(
      repo: full,
      id: id,
      nodeId: node,
      ownerId: ownerId,
      isPrivate: json['private'] == true,
      archived: json['archived'] == true,
    );
  }

  /// `owner/name`, as it is now.
  final GitHubRepo repo;

  /// Its numeric id: a repository deleted and made again under the same
  /// name has another one.
  final int id;

  /// Its GraphQL node id.
  final String nodeId;

  /// Its owner's numeric id: a transfer changes it.
  final int ownerId;

  /// Whether it is private (the store lists public repositories only).
  final bool isPrivate;

  /// Whether it is archived.
  final bool archived;
}

/// A file attached to a release.
final class ReleaseAsset {
  /// [name], [size] bytes, downloaded from [url].
  const ReleaseAsset({
    required this.name,
    required this.size,
    required this.url,
    this.sha256,
    this.uploaded = true,
  });

  /// Reads one from a release answer's `assets`.
  static ReleaseAsset? fromRest(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final size = json['size'];
    final url = json['browser_download_url'];
    if (name is! String || size is! int || url is! String) return null;
    return ReleaseAsset(
      name: name,
      size: size,
      url: Uri.parse(url),
      sha256: sha256OfDigest(json['digest']),
      uploaded: json['state'] == 'uploaded',
    );
  }

  /// The hex SHA-256 in a `digest` of `sha256:<hex>`; null for anything
  /// else (files uploaded before GitHub recorded digests have none).
  static String? sha256OfDigest(Object? digest) {
    if (digest is! String || !digest.startsWith('sha256:')) return null;
    final hex = digest.substring('sha256:'.length).toLowerCase();
    return isSha256Hex(hex) ? hex : null;
  }

  /// Its file name.
  final String name;

  /// Its size in bytes.
  final int size;

  /// Where to download it.
  final Uri url;

  /// The SHA-256 GitHub recorded when it was uploaded, when it did.
  final String? sha256;

  /// Whether its upload finished.
  final bool uploaded;
}

/// A release, as GitHub's REST API describes it.
final class ReleaseInfo {
  /// Release [id] of [tag].
  const ReleaseInfo({
    required this.id,
    required this.tag,
    required this.assets,
    this.immutable = false,
    this.draft = false,
    this.prerelease = false,
    this.publishedAt,
  });

  /// Reads one from a release answer.
  static ReleaseInfo? fromRest(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final tag = json['tag_name'];
    if (id is! int || tag is! String) return null;
    return ReleaseInfo(
      id: id,
      tag: tag,
      immutable: json['immutable'] == true,
      draft: json['draft'] == true,
      prerelease: json['prerelease'] == true,
      publishedAt: DateTime.tryParse('${json['published_at']}'),
      assets: [
        for (final a in (json['assets'] as List? ?? const []))
          ?ReleaseAsset.fromRest(a),
      ],
    );
  }

  /// Its numeric id.
  final int id;

  /// Its tag.
  final String tag;

  /// Whether its files and tag can no longer change (GitHub's release
  /// immutability).
  final bool immutable;

  /// Whether it is an unpublished draft.
  final bool draft;

  /// Whether it is marked a pre-release.
  final bool prerelease;

  /// When it was published.
  final DateTime? publishedAt;

  /// Its files.
  final List<ReleaseAsset> assets;

  /// The uploaded file called [name], or null.
  ReleaseAsset? asset(String name) {
    for (final a in assets) {
      if (a.name == name && a.uploaded) return a;
    }
    return null;
  }
}

/// One repository as a sweep found it: who owns it now, and its newest
/// releases.
final class SweptRepo {
  /// The repository [id], now [repo], owned by [ownerId].
  const SweptRepo({
    required this.id,
    required this.repo,
    required this.ownerId,
    required this.releases,
    this.isPrivate = false,
  });

  /// Its numeric id.
  final int id;

  /// `owner/name`, as it is now.
  final GitHubRepo repo;

  /// Its owner's numeric id.
  final int ownerId;

  /// Whether it is private.
  final bool isPrivate;

  /// Its newest releases, newest first: id, tag, and whether a draft.
  final List<({int id, String tag, bool draft})> releases;
}

/// GitHub, as the backend needs it. Tests replace it.
abstract interface class GitHubApi {
  /// [repo] now, or null when it does not exist or is private.
  Future<RepoInfo?> repo(GitHubRepo repo);

  /// The repositories whose GraphQL node ids are [nodeIds], in that order;
  /// null where one is gone (deleted, or private now). Asked about a
  /// hundred at a time.
  Future<List<SweptRepo?>> sweep(List<String> nodeIds);

  /// Release [id] of [repo], or its latest when [id] is null; null when
  /// there is none.
  Future<ReleaseInfo?> release(GitHubRepo repo, {int? id});

  /// The login of the GitHub account numbered [id] (logins change; ids
  /// don't), or null when there is none.
  Future<String?> login(int id);

  /// The bytes at [url] (a release file), at most [maxBytes].
  Future<Uint8List> download(Uri url, {required int maxBytes});

  /// Bytes [start] up to [end] (not included) of the file at [url]. Throws
  /// a [FetchException] with status 200 when the server can't send parts.
  Future<Uint8List> readRange(Uri url, int start, int end);

  /// Opens an issue in [repo] (`owner/name`); its number.
  Future<int> openIssue(
    String repo, {
    required String title,
    required String body,
    List<String> labels = const [],
  });
}

/// The real [GitHubApi]: the REST and GraphQL APIs with the workflow's
/// token, and plain release downloads (GitHub's CDN, not the API) for
/// files.
final class HttpGitHubApi implements GitHubApi {
  /// GitHub, authenticated with [token] (the workflow's `GITHUB_TOKEN`), at
  /// [api] (GitHub's own unless a test serves recorded answers).
  HttpGitHubApi({
    required this.token,
    Uri? api,
    HttpClient Function()? client,
  }) : api = api ?? Uri.https('api.github.com'),
       _client = client ?? HttpClient.new,
       _fetcher = HttpFetcher(userAgent: _userAgent, client: client);

  static const String _userAgent = 'just_asset_store_backend/0.2.0';

  /// The API token.
  final String token;

  /// Where the API is.
  final Uri api;

  final HttpClient Function() _client;
  final HttpFetcher _fetcher;

  Future<(int, Object?)> _call(String method, String path, [Object? body]) async {
    final client = _client()..userAgent = _userAgent;
    try {
      final request = await client.openUrl(method, api.replace(path: path));
      request.headers
        ..set('Authorization', 'Bearer $token')
        ..set('Accept', 'application/vnd.github+json')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final text = await utf8.decodeStream(response);
      final status = response.statusCode;
      final remaining = response.headers.value('x-ratelimit-remaining');
      if (status == 429 || (status == 403 && remaining == '0')) {
        throw GitHubBusy('GitHub\'s rate limit is used up ($path).');
      }
      if (status >= 500) {
        throw GitHubBusy('GitHub answered $status ($path).');
      }
      return (status, text.isEmpty ? null : jsonDecode(text));
    } on TimeoutException {
      throw GitHubBusy('GitHub did not answer ($path).');
    } on SocketException catch (e) {
      throw GitHubBusy('Could not reach GitHub: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<RepoInfo?> repo(GitHubRepo repo) async {
    final (status, body) = await _call(
      'GET',
      '/repos/${repo.owner}/${repo.name}',
    );
    if (status == 404 || status == 451) return null;
    _ok(status, 'repository $repo');
    final info = RepoInfo.fromRest(body);
    return info == null || info.isPrivate ? null : info;
  }

  /// The GraphQL query a sweep asks, for up to a hundred node ids: about a
  /// point of the hourly budget.
  static const String sweepQuery = r'''
query($ids: [ID!]!) {
  nodes(ids: $ids) {
    ... on Repository {
      databaseId
      nameWithOwner
      isPrivate
      owner { ... on User { databaseId } ... on Organization { databaseId } }
      releases(first: 5, orderBy: {field: CREATED_AT, direction: DESC}) {
        nodes { databaseId tagName isDraft }
      }
    }
  }
}''';

  @override
  Future<List<SweptRepo?>> sweep(List<String> nodeIds) async {
    final out = <SweptRepo?>[];
    for (var at = 0; at < nodeIds.length; at += 100) {
      final ids = nodeIds.sublist(
        at,
        at + 100 < nodeIds.length ? at + 100 : nodeIds.length,
      );
      final (status, body) = await _call('POST', '/graphql', {
        'query': sweepQuery,
        'variables': {'ids': ids},
      });
      _ok(status, 'the sweep');
      out.addAll(sweptFrom(body, ids.length));
    }
    return out;
  }

  /// The repositories in a sweep's answer [body], [count] of them. A node
  /// GitHub can't find comes back null, with a NOT_FOUND error beside it;
  /// any other error means the answer can't be trusted.
  static List<SweptRepo?> sweptFrom(Object? body, int count) {
    if (body is! Map) throw const GitHubBusy('GitHub sent no sweep answer.');
    for (final e in (body['errors'] as List? ?? const [])) {
      if (e is! Map || e['type'] != 'NOT_FOUND') {
        throw GitHubBusy('GitHub could not sweep: ${e is Map ? e['message'] : e}');
      }
    }
    final nodes = (body['data'] as Map?)?['nodes'];
    if (nodes is! List || nodes.length != count) {
      throw const GitHubBusy('GitHub sent a sweep answer of the wrong size.');
    }
    return [
      for (final n in nodes)
        if (n is Map &&
            n['databaseId'] is int &&
            GitHubRepo.tryParse('${n['nameWithOwner']}') != null &&
            (n['owner'] as Map?)?['databaseId'] is int)
          SweptRepo(
            id: n['databaseId'] as int,
            repo: GitHubRepo.tryParse('${n['nameWithOwner']}')!,
            ownerId: (n['owner'] as Map)['databaseId'] as int,
            isPrivate: n['isPrivate'] == true,
            releases: [
              for (final r
                  in ((n['releases'] as Map?)?['nodes'] as List? ?? const []))
                if (r is Map && r['databaseId'] is int && r['tagName'] is String)
                  (
                    id: r['databaseId'] as int,
                    tag: r['tagName'] as String,
                    draft: r['isDraft'] == true,
                  ),
            ],
          )
        else
          null,
    ];
  }

  @override
  Future<ReleaseInfo?> release(GitHubRepo repo, {int? id}) async {
    final (status, body) = await _call(
      'GET',
      '/repos/${repo.owner}/${repo.name}/releases/${id ?? 'latest'}',
    );
    if (status == 404) return null;
    _ok(status, 'a release of $repo');
    return ReleaseInfo.fromRest(body);
  }

  @override
  Future<String?> login(int id) async {
    final (status, body) = await _call('GET', '/user/$id');
    if (status == 404) return null;
    _ok(status, 'user $id');
    return body is Map ? body['login'] as String? : null;
  }

  @override
  Future<Uint8List> download(Uri url, {required int maxBytes}) async =>
      (await _fetcher.get(url, maxBytes: maxBytes)).body;

  @override
  Future<Uint8List> readRange(Uri url, int start, int end) async =>
      (await _fetcher.get(url, range: ByteRange(start, end - 1))).body;

  @override
  Future<int> openIssue(
    String repo, {
    required String title,
    required String body,
    List<String> labels = const [],
  }) async {
    final (status, answer) = await _call('POST', '/repos/$repo/issues', {
      'title': title,
      'body': body,
      'labels': labels,
    });
    _ok(status, 'an issue in $repo', expected: 201);
    final number = answer is Map ? answer['number'] : null;
    if (number is! int) throw GitHubBusy('GitHub opened no issue in $repo.');
    return number;
  }

  static void _ok(int status, String what, {int expected = 200}) {
    if (status != expected) {
      throw HttpException('GitHub answered $status for $what.');
    }
  }
}

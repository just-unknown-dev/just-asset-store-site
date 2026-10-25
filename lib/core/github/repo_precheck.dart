import 'dart:convert';

import 'package:http/http.dart' as http;

/// How one line of a pre-check came out.
enum CheckState {
  /// As the store needs it.
  ok,

  /// GitHub couldn't be asked: the store checks it anyway.
  unknown,

  /// The store would refuse it.
  fail,
}

/// One thing a pre-check looked at.
final class CheckLine {
  const CheckLine(this.state, this.text);

  final CheckState state;
  final String text;
}

/// What GitHub says about a repository, before it is submitted.
final class Precheck {
  const Precheck(this.lines);

  final List<CheckLine> lines;

  /// Whether the store would refuse it: submitting can wait.
  bool get blocks => lines.any((l) => l.state == CheckState.fail);
}

/// Looks at a repository the way the store will, as far as GitHub's public
/// API shows: it is public, its latest release is immutable and holds
/// just_release.json and an archive. The claim code inside the release is
/// for the store to read.
abstract interface class RepoPrecheck {
  Future<Precheck> check(String owner, String repo);
}

/// [RepoPrecheck] on GitHub's REST API, without a token (60 questions an
/// hour for each visitor: plenty for a form).
final class GitHubPrecheck implements RepoPrecheck {
  GitHubPrecheck({http.Client? client, Uri? api})
    : _client = client ?? http.Client(),
      _api = api ?? Uri.https('api.github.com');

  final http.Client _client;
  final Uri _api;

  Future<(int, Object?)> _get(String path) async {
    final r = await _client
        .get(
          _api.replace(path: path),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    Object? body;
    try {
      body = jsonDecode(r.body);
    } on FormatException {
      body = null;
    }
    return (r.statusCode, body);
  }

  @override
  Future<Precheck> check(String owner, String repo) async {
    final name = '$owner/$repo';
    try {
      final (status, info) = await _get('/repos/$owner/$repo');
      if (status == 404) {
        return Precheck([
          CheckLine(
            CheckState.fail,
            'There is no public repository at github.com/$name.',
          ),
        ]);
      }
      if (status != 200 || info is! Map) return _unasked(status);
      final lines = <CheckLine>[
        info['private'] == true
            ? const CheckLine(CheckState.fail, 'The repository is private.')
            : CheckLine(CheckState.ok, '$name is public.'),
      ];
      final (rStatus, release) = await _get(
        '/repos/$owner/$repo/releases/latest',
      );
      if (rStatus == 404) {
        return Precheck([
          ...lines,
          const CheckLine(
            CheckState.fail,
            'It has no release yet. Tag a version: the release workflow '
            'makes one.',
          ),
        ]);
      }
      if (rStatus != 200 || release is! Map) {
        return Precheck([...lines, ..._unasked(rStatus).lines]);
      }
      final tag = '${release['tag_name'] ?? 'Its latest release'}';
      final assets = [
        for (final a in (release['assets'] as List?) ?? const [])
          if (a is Map) '${a['name']}',
      ];
      lines
        ..add(
          release['immutable'] == true
              ? CheckLine(CheckState.ok, '$tag is an immutable release.')
              : CheckLine(
                  CheckState.fail,
                  '$tag isn’t an immutable release. Turn on immutable '
                  'releases (Settings → General → Releases), then release a '
                  'new version.',
                ),
        )
        ..add(
          assets.contains('just_release.json')
              ? CheckLine(CheckState.ok, '$tag holds just_release.json.')
              : CheckLine(
                  CheckState.fail,
                  '$tag has no just_release.json. Make releases with the '
                  'store’s release workflow (just store pack writes it).',
                ),
        )
        ..add(
          assets.any((a) => a.endsWith('.zip'))
              ? CheckLine(CheckState.ok, '$tag holds the package’s archive.')
              : CheckLine(CheckState.fail, '$tag has no package archive (.zip).'),
        );
      return Precheck(lines);
    } on Object {
      return _unasked(null);
    }
  }

  static Precheck _unasked(int? status) => Precheck([
    CheckLine(
      CheckState.unknown,
      status == 403 || status == 429
          ? 'GitHub asks to slow down, so this wasn’t checked here. The store '
                'checks it anyway.'
          : 'GitHub couldn’t be asked now. The store checks it anyway.',
    ),
  ]);
}

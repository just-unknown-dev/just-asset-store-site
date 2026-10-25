import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:just_asset_store_site/core/github/repo_precheck.dart';

/// GitHub's API, answering [routes] by path (status, body); anything else
/// is a 404.
GitHubPrecheck github(Map<String, (int, Object?)> routes, {bool fail = false}) =>
    GitHubPrecheck(
      client: MockClient((request) async {
        if (fail) throw http.ClientException('offline');
        final (status, body) = routes[request.url.path] ?? (404, {'message': 'Not Found'});
        return http.Response(jsonEncode(body), status);
      }),
    );

Map<String, Object?> release({
  bool immutable = true,
  List<String> assets = const ['knight-1.0.0.zip', 'just_release.json'],
}) => {
  'tag_name': 'v1.0.0',
  'immutable': immutable,
  'assets': [
    for (final a in assets) {'name': a},
  ],
};

void main() {
  const repo = '/repos/octocat/knight';
  const latest = '$repo/releases/latest';

  List<CheckState> states(Precheck p) => [for (final l in p.lines) l.state];

  test('a public repository with an immutable release the store can read', () async {
    final p = await github({
      repo: (200, {'private': false}),
      latest: (200, release()),
    }).check('octocat', 'knight');
    expect(p.blocks, isFalse);
    expect(states(p), everyElement(CheckState.ok));
    expect(p.lines.map((l) => l.text), contains('v1.0.0 is an immutable release.'));
  });

  test('no such repository, or a private one', () async {
    final missing = await github({}).check('octocat', 'knight');
    expect(missing.blocks, isTrue);
    expect(missing.lines.single.text, contains('no public repository'));
    final private = await github({
      repo: (200, {'private': true}),
      latest: (200, release()),
    }).check('octocat', 'knight');
    expect(private.blocks, isTrue);
  });

  test('no release, a mutable one, or one without the store\'s files', () async {
    final none = await github({repo: (200, {'private': false})}).check('octocat', 'knight');
    expect(none.lines.last.text, contains('no release yet'));
    expect(none.blocks, isTrue);

    final mutable = await github({
      repo: (200, {'private': false}),
      latest: (200, release(immutable: false)),
    }).check('octocat', 'knight');
    expect(mutable.blocks, isTrue);
    expect(mutable.lines.map((l) => l.text).join(), contains('Turn on immutable releases'));

    final bare = await github({
      repo: (200, {'private': false}),
      latest: (200, release(assets: ['notes.txt'])),
    }).check('octocat', 'knight');
    expect(
      states(bare),
      [CheckState.ok, CheckState.ok, CheckState.fail, CheckState.fail],
    );
  });

  test('GitHub not answering, or asking to slow down: not a refusal', () async {
    final offline = await github({}, fail: true).check('octocat', 'knight');
    expect(offline.blocks, isFalse);
    expect(states(offline), [CheckState.unknown]);
    final limited = await github({
      repo: (403, {'message': 'API rate limit exceeded'}),
    }).check('octocat', 'knight');
    expect(limited.blocks, isFalse);
    expect(limited.lines.single.text, contains('slow down'));
  });
}

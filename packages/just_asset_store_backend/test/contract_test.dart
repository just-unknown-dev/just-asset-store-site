// The real clients — GitHub's REST and GraphQL APIs, release downloads in
// parts, Firestore's REST API — against a server on this machine playing
// back answers recorded from the real services (test/fixtures), or written
// from their documentation where a token would be needed to record them.
// What a client sends is checked too.

@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:just_asset_store_backend/just_asset_store_backend.dart';
import 'package:just_core_cli/fetch.dart';
import 'package:test/test.dart';

Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync());

void main() {
  late HttpServer server;
  late List<(String, String, String)> requests; // method, path, body
  final file = Uint8List.fromList(List<int>.generate(5000, (i) => i % 251));

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      final path = request.uri.path;
      requests.add((request.method, path, body));
      final r = request.response;
      void json(Object? value, {int status = 200}) {
        r
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(value));
      }

      switch ((request.method, path)) {
        case ('GET', '/repos/alice/knight'):
          json({
            'id': 101,
            'node_id': 'R_101',
            'full_name': 'alice/knight',
            'private': false,
            'archived': false,
            'owner': {'id': 5001, 'login': 'alice'},
          });
        case ('GET', '/repos/alice/secret'):
          json({
            'id': 102,
            'node_id': 'R_102',
            'full_name': 'alice/secret',
            'private': true,
            'owner': {'id': 5001},
          });
        case ('GET', '/repos/alice/knight/releases/latest' ||
              '/repos/alice/knight/releases/419735650'):
          json(fixture('github_release.json'));
        case ('GET', '/repos/alice/limited'):
          r
            ..statusCode = 403
            ..headers.set('x-ratelimit-remaining', '0');
        case ('GET', '/repos/alice/down'):
          r.statusCode = 502;
        case ('POST', '/graphql'):
          json(fixture('github_sweep.json'));
        case ('GET', '/user/5001'):
          json({'login': 'alice', 'id': 5001});
        case ('POST', '/repos/just-unknown-dev/just-asset-store-site/issues'):
          json({'number': 7}, status: 201);
        case ('GET', '/download/knight.zip'):
          r
            ..statusCode = 302
            ..headers.set('location', '/objects/knight.zip?sig=x');
        case ('GET', '/objects/knight.zip'):
          final m = RegExp(r'^bytes=(\d+)-(\d+)$')
              .firstMatch(request.headers.value('range') ?? '');
          if (m == null) {
            r.add(file);
          } else {
            final start = int.parse(m[1]!);
            final end = int.parse(m[2]!);
            r
              ..statusCode = 206
              ..headers.set('content-range', 'bytes $start-$end/${file.length}')
              ..add(file.sublist(start, end + 1));
          }
        case ('POST', final p) when p.endsWith('/documents:runQuery'):
          json([
            {
              'document': {
                'name': 'projects/p/databases/(default)/documents/submissions/s1',
                'fields': {
                  'status': {'stringValue': 'pending'},
                  'attempts': {'integerValue': '2'},
                  'createdAt': {'timestampValue': '2026-10-09T10:00:00.123456Z'},
                },
              },
              'readTime': '2026-10-09T10:00:01Z',
            },
          ]);
        case ('POST', final p) when p.endsWith('/documents/meta/x:runQuery'):
          json([
            {'readTime': '2026-10-09T10:00:01Z'},
          ]);
        case ('PATCH', final p) when p.endsWith('/documents/items/quota'):
          json({
            'error': {'code': 429, 'message': 'Quota exceeded.'},
          }, status: 429);
        case ('PATCH', final p) when p.contains('/documents/'):
          json({'name': p, 'fields': jsonDecode(body)['fields']});
        case ('GET', final p) when p.endsWith('/documents/items/missing'):
          json({'error': {'code': 404}}, status: 404);
        case ('GET', final p) when p.endsWith('/documents/items/a'):
          json({
            'name': p,
            'fields': {
              'repoId': {'integerValue': '101'},
              'status': {'stringValue': 'listed'},
              'dirty': {'booleanValue': true},
              'blockedReason': {'nullValue': null},
            },
          });
        case ('GET', '/api/packages/nice_lib'):
          // As pub.dev answers (its v2 API, trimmed): every version with
          // its pubspec, newest listed last, some retracted.
          json({
            'name': 'nice_lib',
            'latest': {'version': '2.0.0'},
            'versions': [
              {
                'version': '1.0.0',
                'pubspec': {'name': 'nice_lib', 'version': '1.0.0'},
              },
              {
                'version': '2.0.0',
                'pubspec': {
                  'name': 'nice_lib',
                  'version': '2.0.0',
                  'dependencies': {'camera_x': '^1.0.0'},
                },
              },
              {
                'version': '2.1.0',
                'retracted': true,
                'pubspec': {'name': 'nice_lib', 'version': '2.1.0'},
              },
            ],
          });
        default:
          r.statusCode = 404;
      }
      await r.close();
    });
  });

  tearDown(() => server.close(force: true));

  Uri at(String path) => Uri.parse('http://127.0.0.1:${server.port}$path');

  group('GitHub', () {
    late HttpGitHubApi github;
    setUp(() => github = HttpGitHubApi(token: 't0ken', api: at('')));

    test('a repository, as the REST API describes it', () async {
      final repo = (await github.repo(GitHubRepo.tryParse('alice/knight')!))!;
      expect(repo.id, 101);
      expect(repo.nodeId, 'R_101');
      expect(repo.ownerId, 5001);
      expect(await github.repo(GitHubRepo.tryParse('alice/secret')!), isNull,
          reason: 'private repositories are not listed');
      expect(await github.repo(GitHubRepo.tryParse('alice/none')!), isNull);
    });

    test('a release: immutable, with SHA-256 digests (recorded)', () async {
      final release = (await github.release(GitHubRepo.tryParse('alice/knight')!))!;
      expect(release.id, 419735650);
      expect(release.tag, 'v2.103.0');
      expect(release.immutable, isTrue);
      expect(release.draft, isFalse);
      final asset = release.asset('gh_2.103.0_checksums.txt')!;
      expect(asset.size, 1971);
      expect(
        asset.sha256,
        '075bb954e2b113d0d2ac788d318b516280cb87103e601e788c34f3557acb15df',
      );
      expect(asset.url.host, 'github.com');
      final byId = await github.release(
        GitHubRepo.tryParse('alice/knight')!,
        id: 419735650,
      );
      expect(byId?.tag, 'v2.103.0');
    });

    test('the sweep: one query, a gone repository null', () async {
      final swept = await github.sweep(['R_101', 'R_gone', 'R_103']);
      expect(swept, hasLength(3));
      expect(swept[0]!.repo.toString(), 'alice/knight');
      expect(swept[0]!.ownerId, 5001);
      expect(swept[0]!.releases.map((r) => r.id), [9002, 9001]);
      expect(swept[1], isNull);
      expect(swept[2]!.releases.single.draft, isTrue);
      final (method, path, body) = requests.single;
      expect((method, path), ('POST', '/graphql'));
      final sent = jsonDecode(body) as Map;
      expect(sent['variables'], {
        'ids': ['R_101', 'R_gone', 'R_103'],
      });
      expect(sent['query'], contains('releases(first: 5'));
    });

    test('a sweep answer with other errors is not trusted', () {
      expect(
        () => HttpGitHubApi.sweptFrom({
          'data': {
            'nodes': [null],
          },
          'errors': [
            {'type': 'RATE_LIMITED', 'message': 'slow down'},
          ],
        }, 1),
        throwsA(isA<GitHubBusy>()),
      );
      expect(
        () => HttpGitHubApi.sweptFrom({
          'data': {'nodes': <Object>[]},
        }, 2),
        throwsA(isA<GitHubBusy>()),
      );
    });

    test('a rate limit and an outage are "later", not refusals', () {
      expect(
        github.repo(GitHubRepo.tryParse('alice/limited')!),
        throwsA(isA<GitHubBusy>()),
      );
      expect(
        github.repo(GitHubRepo.tryParse('alice/down')!),
        throwsA(isA<GitHubBusy>()),
      );
    });

    test('logins, issues, and the token sent', () async {
      expect(await github.login(5001), 'alice');
      final number = await github.openIssue(
        'just-unknown-dev/just-asset-store-site',
        title: 'Report: x',
        body: 'b',
        labels: ['report'],
      );
      expect(number, 7);
      expect(jsonDecode(requests.last.$3), {
        'title': 'Report: x',
        'body': 'b',
        'labels': ['report'],
      });
    });

    test('release files in parts, through the CDN redirect', () async {
      final part = await github.readRange(at('/download/knight.zip'), 100, 200);
      expect(part, file.sublist(100, 200));
      final whole = await github.download(
        at('/download/knight.zip'),
        maxBytes: 10000,
      );
      expect(whole, file);
    });
  });

  group('Firestore', () {
    late FirestoreDocumentStore store;
    setUp(
      () => store = FirestoreDocumentStore(
        project: 'p',
        accessToken: 't',
        endpoint: at(''),
      ),
    );

    test('a query: its filters, order and limit as Firestore reads them', () async {
      final found = await store.query(
        'submissions',
        where: const [
          Filter.equal('status', 'pending'),
          Filter('attempts', FilterOp.lessThan, 6),
        ],
        orderBy: const [OrderBy('createdAt')],
        limit: 50,
      );
      expect(found.keys, ['s1']);
      expect(found['s1']!['attempts'], 2);
      expect(found['s1']!['createdAt'], '2026-10-09T10:00:00.123456Z');
      final (_, path, body) = requests.single;
      expect(path, '/v1/projects/p/databases/(default)/documents:runQuery');
      final q = (jsonDecode(body) as Map)['structuredQuery'] as Map;
      expect(q['from'], [
        {'collectionId': 'submissions'},
      ]);
      expect(q['limit'], 50);
      expect(q['orderBy'], [
        {
          'field': {'fieldPath': 'createdAt'},
          'direction': 'ASCENDING',
        },
      ]);
      final filters = ((q['where'] as Map)['compositeFilter'] as Map)['filters'] as List;
      expect(filters, hasLength(2));
      expect((filters[1] as Map)['fieldFilter'], {
        'field': {'fieldPath': 'attempts'},
        'op': 'LESS_THAN',
        'value': {'integerValue': '6'},
      });
    });

    test('a query that finds nothing, and one filter alone', () async {
      expect(
        await store.query(
          'meta/x/meta',
          where: const [Filter.greaterThan('updatedMs', 5)],
        ),
        isEmpty,
      );
      final q = (jsonDecode(requests.single.$3) as Map)['structuredQuery'] as Map;
      expect((q['where'] as Map)['fieldFilter'], isNotNull);
    });

    test('documents read and written as flat fields', () async {
      expect(await store.get('items/a'), {
        'repoId': 101,
        'status': 'listed',
        'dirty': true,
        'blockedReason': null,
      });
      expect(await store.get('items/missing'), isNull);
      await store.set('items/b', {'n': 1, 's': 'x', 'b': false, 'none': null});
      expect(jsonDecode(requests.last.$3), {
        'fields': {
          'n': {'integerValue': '1'},
          's': {'stringValue': 'x'},
          'b': {'booleanValue': false},
          'none': {'nullValue': null},
        },
      });
    });

    test("a used-up free quota says so", () {
      expect(
        store.set('items/quota', {'n': 1}),
        throwsA(
          isA<HttpException>().having((e) => e.message, 'message', contains('quota')),
        ),
      );
    });
  });

  group('pub.dev', () {
    test('versions, without retracted ones; none for a free name', () async {
      final pub = HttpPubDevApi(api: at(''));
      final versions = await pub.versions('nice_lib');
      expect([for (final v in versions!) '${v.version}'], ['1.0.0', '2.0.0']);
      expect(versions.last.pubspec['dependencies'], {'camera_x': '^1.0.0'});
      expect(await pub.versions('free_name'), isNull);
      // Each package is asked about once.
      await pub.versions('nice_lib');
      expect(
        requests.where((r) => r.$2 == '/api/packages/nice_lib'),
        hasLength(1),
      );
    });
  });

  group('card pictures', () {
    test('a picture becomes a 640×360 JPEG', () {
      final png = img.encodePng(
        img.Image(width: 64, height: 32)..clear(img.ColorRgb8(200, 20, 20)),
      );
      final thumb = Thumbnails.makeThumbnail(png)!;
      final back = img.decodeJpg(thumb)!;
      expect((back.width, back.height), (640, 360));
      final c = back.getPixel(320, 180);
      expect(c.r, greaterThan(150), reason: 'the picture fills the card');
    });

    test('a gallery picture fits within 1280×720, whole, never larger', () {
      Uint8List png(int w, int h) => img.encodePng(
        img.Image(width: w, height: h)..clear(img.ColorRgb8(20, 200, 20)),
      );
      (int, int) size(Uint8List jpg) {
        final back = img.decodeJpg(jpg)!;
        return (back.width, back.height);
      }

      expect(size(Thumbnails.makeGalleryPicture(png(2560, 1440))!), (1280, 720));
      expect(size(Thumbnails.makeGalleryPicture(png(1000, 1000))!), (720, 720));
      expect(size(Thumbnails.makeGalleryPicture(png(400, 300))!), (400, 300));
      expect(
        Thumbnails.makeGalleryPicture(img.encodePng(img.Image(width: 5000, height: 2))),
        isNull,
      );
    });

    test('a huge picture is refused before it is decoded; noise too', () {
      final huge = img.encodePng(img.Image(width: 5000, height: 1));
      expect(Thumbnails.makeThumbnail(huge), isNull);
      expect(Thumbnails.makeThumbnail(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}

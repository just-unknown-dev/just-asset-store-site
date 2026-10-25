// The backend end to end against a fake GitHub and records in memory: what
// it lists, holds and refuses, what it notices later, how it fails, what
// it exports, and how little it reads.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_asset_store_backend/just_asset_store_backend.dart';
import 'package:test/test.dart';

import 'support/fake_github.dart';
import 'support/fake_pub_dev.dart';

const alice = 5001; // a community publisher
const bob = 5002; // another one
const official = 262105023; // just-unknown-dev: catalog.json's officialPublishers
const maintainer = 263049034; // in catalog.json's maintainerIds

void main() {
  late FakeGitHub github;
  late FakePubDev pubDev;
  late MemoryDocumentStore records;
  late DateTime now;
  // As shipped: the first version, where only the store's own team
  // publishes.
  final shipped = BackendConfig.parse(File('catalog.json').readAsStringSync());
  // Most of these tests are about everyone else's packages: publishing
  // open, as it will be.
  final config = shipped.withPublishing(open: true);
  const identities = MapIdentityLookup({
    'uid-alice': alice,
    'uid-bob': bob,
    'uid-official': official,
  });

  StoreBackend make() => StoreBackend(
    store: records,
    github: github,
    pubDev: pubDev,
    config: config,
    clock: () => now,
  );

  setUp(() {
    now = DateTime.utc(2026, 10, 9, 12);
    pubDev = FakePubDev();
    github = FakeGitHub()
      ..logins.addAll({
        alice: 'alice',
        bob: 'bob',
        official: 'just-unknown-dev',
      })
      ..addRepo('alice/knight', id: 101, ownerId: alice)
      ..publish('alice/knight', id: 'alice_knight', version: '1.0.0', claimant: alice);
    records = MemoryDocumentStore();
  });

  Future<Outcome> submit({
    String repo = 'https://github.com/alice/knight',
    int by = alice,
  }) => make().submit(repoUrl: repo, submitterId: by, login: github.logins[by]!);

  Future<StoreIndex> catalog() async => (await make().export(full: true)).index;

  Future<void> file(
    String id, {
    String uid = 'uid-alice',
    String repo = 'https://github.com/alice/knight',
    Map<String, Object?> extra = const {},
  }) => records.set('submissions/$id', {
    'uid': uid,
    'repo': repo,
    'status': 'pending',
    'createdAt': '2026-10-09T10:00:0${id.length}Z',
    ...extra,
  });

  Future<RunReport> run() => make().run(identities: identities);

  group('the first version: only the store\'s own team publishes', () {
    StoreBackend closed() => StoreBackend(
      store: records,
      github: github,
      pubDev: pubDev,
      config: shipped,
      clock: () => now,
    );

    test('as shipped, publishing is closed but to just-unknown-dev', () {
      expect(shipped.openPublishing, isFalse);
      expect(shipped.officialPublishers, [official]);
      expect(shipped.maintainerIds, [maintainer]);
      expect(shipped.mayPublish(official), isTrue);
      expect(shipped.mayPublish(alice), isFalse);
    });

    test('anyone else is refused before GitHub is asked', () async {
      final asked = github.calls;
      final o = await closed().submit(
        repoUrl: 'https://github.com/alice/knight',
        submitterId: alice,
        login: 'alice',
      );
      expect(o.ok, isFalse);
      expect(o.message, BackendConfig.closedMessage);
      expect(github.calls, asked);
      expect(await records.get('items/alice_knight'), isNull);
    });

    test('the store\'s own team is listed, official', () async {
      github
        ..addRepo('just-unknown-dev/just-tool', id: 900, ownerId: official)
        ..publish(
          'just-unknown-dev/just-tool',
          id: 'just_tool',
          version: '1.0.0',
          claimant: official,
          kind: 'kit',
          category: 'kits',
        );
      final o = await closed().submit(
        repoUrl: 'https://github.com/just-unknown-dev/just-tool',
        submitterId: official,
        login: 'just-unknown-dev',
      );
      expect(o.ok, isTrue, reason: o.message);
      expect(o.held, isFalse);
      final item = (await catalog()).item('just_tool')!;
      expect(item.trust, TrustLevel.official);
    });

    test('a release of a repository watched from before is refused too', () async {
      // Listed while publishing was open…
      expect((await submit()).ok, isTrue);
      // …then closed: its next release isn't checked.
      github.publish('alice/knight', id: 'alice_knight', version: '1.1.0', claimant: alice);
      await closed().run(identities: identities);
      expect(
        (await catalog()).item('alice_knight')!.versions.map((v) => '${v.version}'),
        ['1.0.0'],
      );
    });
  });

  group('submit', () {
    test('lists a package that passes every check, after a quick look', () async {
      final o = await submit();
      expect(o.ok, isTrue, reason: o.message);
      expect(o.held, isFalse);
      // A look at the directory first, then one download of the archive
      // (and the release file).
      expect(github.rangeReads, greaterThan(0));
      expect(github.downloads, 2);
      final item = (await catalog()).items.single;
      expect(item.id, 'alice_knight');
      expect(item.trust, TrustLevel.community);
      expect(item.publisher, 'alice');
      expect(item.summary, 'A knight.');
      expect(item.repoId, 101);
      expect(item.sourceRepo, 'https://github.com/alice/knight');
      expect(
        item.versions.single.archive!.url,
        'https://github.com/alice/knight/releases/download/v1.0.0/alice_knight-1.0.0.zip',
      );
      final publisher = (await records.get('publishers/$alice'))!;
      expect(publisher['login'], 'alice');
      expect(publisher['trust'], 'community');
    });

    test("refuses a release without the submitter's claim code", () async {
      final o = await submit(by: bob);
      expect(o.ok, isFalse);
      expect(o.message, contains("@bob's claim code"));
      expect(o.message, contains(claimCode(bob)));
      expect(await records.list('items'), isEmpty);
      // Nothing is written for a refused submission, not even a publisher.
      expect(await records.get('publishers/$bob'), isNull);
    });

    test('refuses a release that is not immutable', () async {
      github.repoNamed('alice/knight').releases.clear();
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.0.0',
        claimant: alice,
        immutable: false,
      );
      final o = await submit();
      expect(o.ok, isFalse);
      expect(o.message, contains('immutable'));
    });

    test('refuses an archive that is not the file GitHub recorded', () async {
      final archive = github.files.keys.firstWhere((u) => u.endsWith('.zip'));
      final bytes = github.files[archive]!;
      github.files[archive] = Uint8List.fromList([...bytes]..[40] ^= 1);
      final o = await submit();
      expect(o.ok, isFalse, reason: o.message);
      expect(await records.list('items'), isEmpty);
    });

    test('the quick look refuses a bad package without downloading it', () async {
      github.repoNamed('alice/knight').releases.clear();
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.0.0',
        claimant: alice,
        // A large package whose layout breaks the rules.
        extraFiles: {'hook/build.dart': '// runs on your machine'},
      );
      final o = await submit();
      expect(o.ok, isFalse);
      expect(o.message, contains('hook/'));
      expect(github.downloads, 1, reason: 'only just_release.json');
    });

    test('without GitHub digests, or ranges, the full check decides alone', () async {
      github.repoNamed('alice/knight').releases.clear();
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.0.0',
        claimant: alice,
        digests: false,
      );
      expect((await submit()).ok, isTrue);
      expect(github.rangeReads, 0);

      github
        ..addRepo('bob/sword', id: 102, ownerId: bob)
        ..publish('bob/sword', id: 'bob_sword', version: '1.0.0', claimant: bob)
        ..noRanges = true;
      final o = await submit(repo: 'bob/sword', by: bob);
      expect(o.ok, isTrue, reason: o.message);
    });

    test('a reserved id is for official publishers only', () async {
      github
        ..addRepo('impostor/engine', id: 7, ownerId: bob)
        ..publish('impostor/engine', id: 'just_engine', version: '1.0.0', claimant: bob)
        ..addRepo('just-unknown-dev/sprites', id: 8, ownerId: 262105023)
        ..publish(
          'just-unknown-dev/sprites',
          id: 'just_sprites',
          version: '1.0.0',
          claimant: official,
        );
      final refused = await submit(repo: 'impostor/engine', by: bob);
      expect(refused.ok, isFalse);
      expect(refused.message, contains('kept for the official packages'));
      final listed = await submit(repo: 'just-unknown-dev/sprites', by: official);
      expect(listed.ok, isTrue, reason: listed.message);
      final item = (await catalog()).item('just_sprites')!;
      expect(item.trust, TrustLevel.official);
    });

    test('a taken id, and a repository listed by another publisher', () async {
      await submit();
      github
        ..addRepo('bob/knight', id: 102, ownerId: bob)
        ..publish('bob/knight', id: 'alice_knight', version: '2.0.0', claimant: bob);
      final taken = await submit(repo: 'bob/knight', by: bob);
      expect(taken.ok, isFalse);
      expect(taken.message, contains('already the id of alice/knight'));
      // bob can't list alice's repository under his own account either.
      final theirs = await submit(by: bob);
      expect(theirs.ok, isFalse);
      expect(theirs.message, contains('another publisher'));
    });

    test('a listed version never changes', () async {
      await submit();
      expect((await submit()).message, contains('listed already'));
      // The same version again, with other bytes, in a new release.
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.0.0',
        claimant: alice,
        content: 'other bytes',
      );
      final o = await submit();
      expect(o.ok, isFalse);
      expect(o.message, contains('A version never changes'));
      final listed = (await catalog()).item('alice_knight')!.versions.single;
      expect(
        listed.archive!.sha256,
        github.repoNamed('alice/knight').releases.first.assets.first.sha256,
      );
    });

    test("an id like another publisher's waits for a maintainer", () async {
      await submit();
      github
        ..addRepo('bob/knight', id: 102, ownerId: bob)
        ..publish('bob/knight', id: 'alice_kn1ght', version: '1.0.0', claimant: bob);
      final o = await submit(repo: 'bob/knight', by: bob);
      expect(o.ok, isTrue);
      expect(o.held, isTrue);
      expect(o.message, contains('looks like "alice_knight"'));
      expect((await catalog()).item('alice_kn1ght'), isNull);
      expect(github.issues.single.title, 'Review: alice_kn1ght 1.0.0');
      expect(github.issues.single.labels, ['review']);

      final approved = await make().moderate(
        id: 'alice_kn1ght',
        action: 'approve',
        actorId: maintainer,
      );
      expect(approved.ok, isTrue, reason: approved.message);
      expect((await catalog()).item('alice_kn1ght'), isNotNull);
    });
  });

  group('run', () {
    test('answers submissions as their signers', () async {
      await file('s1');
      // bob signs a submission of alice's repository, claiming to be her.
      await file('s22', uid: 'uid-bob', extra: {'login': 'alice'});
      await file('s333', uid: 'uid-nobody');
      final r = await run();
      expect(r.deploy, isTrue);
      final s1 = (await records.get('submissions/s1'))!;
      expect(s1['status'], 'listed');
      expect(s1['itemId'], 'alice_knight');
      expect(s1['login'], 'alice');
      final s2 = (await records.get('submissions/s22'))!;
      expect(s2['status'], 'refused');
      expect(s2['login'], 'bob');
      final s3 = (await records.get('submissions/s333'))!;
      expect(s3['status'], 'refused');
      expect(s3['message'], contains('which GitHub account'));
      // Answered ones are left alone next time.
      expect((await run()).outcomes.where((o) => o.message.contains('s1')), isEmpty);
    });

    test('a held submission says so', () async {
      await submit();
      github
        ..addRepo('bob/knight', id: 102, ownerId: bob)
        ..publish('bob/knight', id: 'alice_kn1ght', version: '1.0.0', claimant: bob);
      await file('s1', uid: 'uid-bob', repo: 'bob/knight');
      await run();
      expect((await records.get('submissions/s1'))!['status'], 'held');
    });

    test('each signer gets a few per run; the rest wait', () async {
      for (var i = 0; i < 4; i++) {
        await file('s${'x' * i}');
      }
      await run();
      expect(
        (await records.query(
          'submissions',
          where: const [Filter.equal('status', 'pending')],
        )).length,
        1,
      );
    });

    test('a submission that breaks the backend never stops the run', () async {
      github
        ..addRepo('bob/sword', id: 102, ownerId: bob)
        ..publish('bob/sword', id: 'bob_sword', version: '1.0.0', claimant: bob)
        ..broken.add('alice/knight');
      await file('s1');
      await file('s22', uid: 'uid-bob', repo: 'bob/sword');
      await run();
      // The other submission went through; the broken one waits, counted.
      expect((await records.get('submissions/s22'))!['status'], 'listed');
      final s1 = (await records.get('submissions/s1'))!;
      expect(s1['status'], 'pending');
      expect(s1['attempts'], 1);
      // Until the store gives up on it.
      for (var i = 0; i < StoreBackend.maxAttempts; i++) {
        await run();
      }
      final given = (await records.get('submissions/s1'))!;
      expect(given['status'], 'refused');
      expect(given['message'], contains('gave up'));
    });

    test('the sweep lists new releases, and holds what needs a look', () async {
      await submit();
      github.publish('alice/knight', id: 'alice_knight', version: '1.1.0', claimant: alice);
      final r = await run();
      expect(r.outcomes.map((o) => o.message), contains('alice_knight 1.1.0 is listed.'));
      expect(
        (await catalog()).item('alice_knight')!.versions.map((v) => '${v.version}'),
        ['1.0.0', '1.1.0'],
      );
      // A version that brings native code waits.
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.2.0',
        claimant: alice,
        kind: 'kit',
        nativePlugins: ['camera'],
      );
      await run();
      expect(
        (await catalog()).item('alice_knight')!.versions.map((v) => '${v.version}'),
        isNot(contains('1.2.0')),
      );
      expect(github.issues.last.body, contains('adds native code: camera'));
      // Refused, it never comes back.
      await make().moderate(id: 'alice_knight', action: 'reject', actorId: maintainer);
      await run();
      expect(
        (await catalog()).item('alice_knight')!.versions.map((v) => '${v.version}'),
        ['1.0.0', '1.1.0'],
      );
      final notices = jsonDecode(
        (await records.get('notices/$alice'))!['messages'] as String,
      ) as List;
      expect(notices.last['text'], contains('refused by the store'));
    });

    test('a repository that changes hands holds its next version', () async {
      await submit();
      github
        ..move('alice/knight', 'mallory/knight', ownerId: 6666)
        ..publish('mallory/knight', id: 'alice_knight', version: '1.1.0', claimant: alice);
      final r = await run();
      expect(r.outcomes.single.held, isTrue);
      expect(github.issues.last.body, contains('changed hands'));
    });

    test('a refused release is told to its publisher', () async {
      await submit();
      github.publish(
        'alice/knight',
        id: 'alice_knight',
        version: '1.1.0',
        claimant: alice,
        immutable: false,
      );
      await run();
      final notices = jsonDecode(
        (await records.get('notices/$alice'))!['messages'] as String,
      ) as List;
      expect(notices.single['text'], contains('alice_knight v1.1.0'));
      expect(notices.single['text'], contains('immutable'));
      // Refused once, it is not checked again.
      final downloads = github.downloads;
      await run();
      expect(github.downloads, downloads);
    });

    test('one repository failing never stops the others; it backs off', () async {
      await submit();
      github
        ..addRepo('bob/sword', id: 102, ownerId: bob)
        ..publish('bob/sword', id: 'bob_sword', version: '1.0.0', claimant: bob);
      await submit(repo: 'bob/sword', by: bob);
      github
        ..publish('alice/knight', id: 'alice_knight', version: '1.1.0', claimant: alice)
        ..publish('bob/sword', id: 'bob_sword', version: '1.1.0', claimant: bob)
        ..busy.add('alice/knight');
      final r = await run();
      expect(r.outcomes.where((o) => o.retry).single.id, 'alice_knight');
      expect(
        (await catalog()).item('bob_sword')!.versions.map((v) => '${v.version}'),
        contains('1.1.0'),
      );
      final knight = (await records.get('items/alice_knight'))!;
      expect(knight['attempts'], 1);
      expect(knight['nextTryMs'], greaterThan(now.millisecondsSinceEpoch));
      // Not tried again before its time…
      expect((await run()).outcomes.where((o) => o.id == 'alice_knight'), isEmpty);
      // …and listed once GitHub is back.
      github.busy.clear();
      now = now.add(const Duration(hours: 2));
      await run();
      expect(
        (await catalog()).item('alice_knight')!.versions.map((v) => '${v.version}'),
        contains('1.1.0'),
      );
    });

    test('a gone repository makes its item unavailable, until it is back', () async {
      await submit();
      github.repoNamed('alice/knight').gone = true;
      await run();
      expect((await catalog()).item('alice_knight')!.unavailable, isTrue);
      github.repoNamed('alice/knight').gone = false;
      await run();
      expect((await catalog()).item('alice_knight')!.unavailable, isFalse);
    });

    test('reports become issues, their text fenced', () async {
      await submit();
      await records.set('reports/r1', {
        'uid': 'uid-bob',
        'itemId': 'alice_knight',
        'reason': 'malware',
        'text': 'It deletes files ```\n@everyone [click](https://x.example)',
        'status': 'new',
        'createdAt': '2026-10-09T10:00:00Z',
      });
      await records.set('reports/r2', {
        'uid': 'uid-bob',
        'itemId': '../../etc',
        'reason': 'other',
        'text': '',
        'status': 'new',
        'createdAt': '2026-10-09T10:00:01Z',
      });
      await run();
      final issue = github.issues.single;
      expect(issue.title, 'Report: alice_knight');
      expect(issue.labels, ['report']);
      expect(issue.body, contains('````text'), reason: 'a longer fence than the text has');
      expect((await records.get('reports/r1'))!['status'], 'filed');
      expect((await records.get('reports/r2'))!['status'], 'ignored');
    });

    test('a quiet run reads a handful of documents, however many items', () async {
      for (var i = 0; i < 60; i++) {
        github
          ..addRepo('p$i/pack', id: 2000 + i, ownerId: 3000 + i)
          ..logins[3000 + i] = 'p$i'
          ..publish('p$i/pack', id: 'pack_$i', version: '1.0.0', claimant: 3000 + i);
        final o = await make().submit(
          repoUrl: 'p$i/pack',
          submitterId: 3000 + i,
          login: 'p$i',
        );
        expect(o.ok, isTrue, reason: o.message);
      }
      final quiet = MemoryDocumentStore()..docs.addAll(records.docs);
      final r = await StoreBackend(
        store: quiet,
        github: github,
        pubDev: pubDev,
        config: config,
        clock: () => now,
      ).run(identities: identities);
      expect(r.outcomes, isEmpty);
      // The state, the repository shards, and two empty queries.
      expect(quiet.reads, lessThanOrEqualTo(1 + RepoShards.count + 2));
      expect(github.sweeps, 1);
    });
  });

  group('moderate', () {
    test('only maintainers', () async {
      await submit();
      final o = await make().moderate(id: 'alice_knight', action: 'block', actorId: bob);
      expect(o.ok, isFalse);
      expect((await catalog()).item('alice_knight'), isNotNull);
    });

    test('takedowns reach the catalog, for projects that have the item', () async {
      await submit();
      await make().moderate(id: 'alice_knight', action: 'block', actorId: maintainer);
      final index = await catalog();
      expect(index.item('alice_knight'), isNull);
      expect(index.removal('alice_knight')?.reason, contains('Taken down'));
      await make().moderate(id: 'alice_knight', action: 'unblock', actorId: maintainer);
      expect((await catalog()).item('alice_knight'), isNotNull);
    });

    test('one version taken down, or withdrawn', () async {
      await submit();
      await make().moderate(id: 'alice_knight', action: 'block:1.0.0', actorId: maintainer);
      expect((await catalog()).item('alice_knight')!.versions.single.blocked, isTrue);
      await make().moderate(id: 'alice_knight', action: 'yank:1.0.0', actorId: maintainer);
      final v = (await catalog()).item('alice_knight')!.versions.single;
      expect(v.yanked, isTrue);
      expect(
        (await make().moderate(id: 'alice_knight', action: 'yank:9.9.9', actorId: maintainer)).ok,
        isFalse,
      );
    });

    test('trust follows the publisher into every item', () async {
      await submit();
      await make().moderate(id: 'alice_knight', action: 'trust:verified', actorId: maintainer);
      expect((await catalog()).item('alice_knight')!.trust, TrustLevel.verified);
    });
  });

  group('export', () {
    test('built on the deployed catalog, it equals a full one', () async {
      await submit();
      var r = await make().export(full: true);
      await make().exported(rootSha: 'a' * 64, startedMs: r.startedMs, full: true);
      final deployed = r.index;

      now = now.add(const Duration(minutes: 30));
      github
        ..addRepo('bob/sword', id: 102, ownerId: bob)
        ..publish('bob/sword', id: 'bob_sword', version: '1.0.0', claimant: bob)
        ..publish('alice/knight', id: 'alice_knight', version: '1.1.0', claimant: alice);
      await submit(repo: 'bob/sword', by: bob);
      await run();
      await make().moderate(id: 'bob_sword', action: 'yank:1.0.0', actorId: maintainer);

      records.reads = 0;
      r = await make().export(previous: deployed);
      expect(r.full, isFalse);
      expect(records.reads, lessThan(10), reason: 'only what changed');
      final whole = await make().export(full: true);
      expect(
        jsonEncode(r.index.toJson()..remove('generatedAt')),
        jsonEncode(whole.index.toJson()..remove('generatedAt')),
      );
    });

    test('pictures: a card and at most four gallery copies the store serves; '
        'featured names listed items only', () async {
      Uint8List picture(int n) => Uint8List.fromList(utf8.encode('picture $n'));
      String sha16(int n) => Sha256.hexOf(picture(n)).substring(0, 16);
      github
        ..addRepo('bob/sword', id: 102, ownerId: bob)
        ..publish(
          'bob/sword',
          id: 'bob_sword',
          version: '1.0.0',
          claimant: bob,
          previews: {for (var n = 1; n <= 5; n++) 'shot$n.png': picture(n)},
        );
      expect((await submit(repo: 'https://github.com/bob/sword', by: bob)).ok, isTrue);
      final featuring = BackendConfig(
        source: config.source,
        categories: config.categories,
        maintainerIds: config.maintainerIds,
        officialPublishers: config.officialPublishers,
        reservedPrefixes: config.reservedPrefixes,
        site: config.site,
        backendRepo: config.backendRepo,
        openPublishing: true,
        featured: const ['nobody_here', 'bob_sword'],
      );
      final r = await StoreBackend(
        store: records,
        github: github,
        pubDev: pubDev,
        config: featuring,
        clock: () => now,
      ).export(full: true);
      final sword = r.index.item('bob_sword')!;
      expect(sword.thumbnail, 'thumbs/${sha16(1)}.jpg');
      expect(sword.previews, [
        for (var n = 1; n <= 4; n++) 'previews/${sha16(n)}.jpg',
      ]);
      // Each from its pinned release file; the fifth is left out.
      expect('${r.pictures['thumbs/${sha16(1)}.jpg']!.url}', endsWith('/v1.0.0/shot1.png'));
      expect('${r.pictures['previews/${sha16(4)}.jpg']!.url}', endsWith('/shot4.png'));
      expect(r.pictures.keys.where((k) => k.contains(sha16(5))), isEmpty);
      expect(r.index.featured, ['bob_sword']);
      expect(r.index.featuredItems.single.id, 'bob_sword');
    });

    test('deploying clears the flag, unless something changed meanwhile', () async {
      await submit();
      final r = await make().export(full: true);
      now = now.add(const Duration(minutes: 1));
      await make().moderate(id: 'alice_knight', action: 'yank:1.0.0', actorId: maintainer);
      await make().exported(rootSha: 'b' * 64, startedMs: r.startedMs, full: true);
      expect((await StoreState.load(records)).dirty, isTrue);
      final again = await make().export(full: true);
      await make().exported(rootSha: 'c' * 64, startedMs: again.startedMs, full: true);
      final state = await StoreState.load(records);
      expect(state.dirty, isFalse);
      expect(state.rootSha, 'c' * 64);
      expect((await run()).deploy, isFalse);
      // A day later the daily full export is due.
      now = now.add(const Duration(days: 1, minutes: 1));
      expect((await run()).deploy, isTrue);
    });

    test('a name pub.dev has is not a new community item', () async {
      pubDev.add('http');
      github
        ..addRepo('bob/http', id: 103, ownerId: bob)
        ..publish('bob/http', id: 'http', version: '1.0.0', claimant: bob, kind: 'kit');
      final o = await submit(repo: 'bob/http', by: bob);
      expect(o.ok, isFalse);
      expect(o.message, contains('A package called "http" is on pub.dev'));
    });

    test('native code its pub.dev packages bring is listed, and declared',
        () async {
      pubDev
        ..add('nice_lib', dependencies: ['camera_x'])
        ..add('camera_x', plugin: true);
      github
        ..addRepo('bob/tools', id: 104, ownerId: bob)
        ..publish(
          'bob/tools',
          id: 'bob_tools',
          version: '1.0.0',
          claimant: bob,
          kind: 'kit',
          pubDependencies: {'nice_lib': '^1.0.0'},
        );
      final undeclared = await submit(repo: 'bob/tools', by: bob);
      expect(undeclared.ok, isFalse);
      expect(
        undeclared.message,
        contains('brings native code (camera_x), but its just_store.json'),
      );

      // Declared, though its release lists nothing: the store lists it.
      github
        ..addRepo('bob/tools2', id: 105, ownerId: bob)
        ..publish(
          'bob/tools2',
          id: 'bob_tools2',
          version: '1.0.0',
          claimant: bob,
          kind: 'kit',
          pubDependencies: {'nice_lib': '^1.0.0'},
          permissions: ['native'],
        );
      final declared = await submit(repo: 'bob/tools2', by: bob);
      expect(declared.ok, isTrue, reason: declared.message);
      expect(declared.held, isTrue, reason: 'a first version with native code');
      final record = ItemRecord.fromDoc(
        'bob_tools2',
        (await records.get('items/bob_tools2'))!,
      );
      expect(record.pending!.record.entry['nativePlugins'], ['camera_x']);
    });

    test('pub.dev down: asked again later', () async {
      pubDev.down = true;
      github
        ..addRepo('bob/knight', id: 102, ownerId: bob)
        ..publish('bob/knight', id: 'bob_knight', version: '1.0.0', claimant: bob, kind: 'kit');
      final o = await submit(repo: 'bob/knight', by: bob);
      expect(o.retry, isTrue, reason: o.message);
    });

    test('an item waiting for its first review is not listed', () async {
      github
        ..addRepo('bob/knight', id: 102, ownerId: bob)
        ..publish(
          'bob/knight',
          id: 'bob_knight',
          version: '1.0.0',
          claimant: bob,
          kind: 'kit',
          nativePlugins: ['camera'],
        );
      final o = await submit(repo: 'bob/knight', by: bob);
      expect(o.held, isTrue);
      expect((await catalog()).items, isEmpty);
    });
  });

  group('pieces', () {
    test('look-alike ids', () {
      expect(ReleaseCheck.lookAlike('alice_kn1ght', ['alice_knight']), 'alice_knight');
      expect(ReleaseCheck.lookAlike('aliceknight', ['alice_knight']), 'alice_knight');
      expect(ReleaseCheck.lookAlike('alice_knights', ['alice_knight']), 'alice_knight');
      expect(ReleaseCheck.lookAlike('alice_knigth', ['alice_knight']), isNull,
          reason: 'two letters swapped is two edits');
      expect(ReleaseCheck.lookAlike('pixel_forest', ['alice_knight']), isNull);
      expect(ReleaseCheck.lookAlike('alice_knight', ['alice_knight']), isNull);
    });

    test('a report body fences whatever the text holds', () {
      final body = StoreBackend.reportBody({
        'itemId': 'x',
        'reason': 'malware <b>',
        'text': '`````',
      }, site: 'https://store.example');
      expect(body, contains('``````text'));
      expect(body, contains('Reason: `malware`'));
    });

    test('a repository watch remembers a few releases', () {
      final w = RepoWatch(node: 'n', item: 'i', claimant: 1);
      for (var i = 0; i < 30; i++) {
        w.sawRelease(i);
      }
      expect(w.seen, hasLength(RepoWatch.memory));
      expect(w.knows(29), isTrue);
      expect(w.knows(0), isFalse);
      w.refusedRelease(40, 'no');
      expect(w.knows(40), isTrue);
    });
  });

  test("Firestore's rules: what a browser may write, and nothing more", () {
    final rules = File('../../firestore.rules').readAsStringSync();
    final reasons = RegExp(r"d\.reason in \[([^\]]*)\]").firstMatch(rules)!.group(1)!;
    expect(
      RegExp(r"'([a-z-]+)'").allMatches(reasons).map((m) => m[1]).toList(),
      StoreBackend.reportReasons,
    );
    expect(rules, contains("sign_in_provider == 'github.com'"));
    expect(rules, contains("isTally(duration.value(10, 'm'))"));
    expect(rules, contains("tallied('submitters')"));
    expect(rules, contains("tallied('reporters')"));
    // The first version: only the official publisher submits, the same
    // account as catalog.json says.
    final allowed = RegExp(r"hasAny\(\[([^\]]*)\]\)").firstMatch(rules)!.group(1)!;
    expect(
      RegExp(r"'(\d+)'").allMatches(allowed).map((m) => int.parse(m[1]!)).toList(),
      shipped.officialPublishers,
    );
    expect(
      RegExp(r'mayPublish\(\)').allMatches(rules).length,
      3,
      reason: 'defined once, and asked by submitters and submissions',
    );
    expect(rules, contains('match /notices/{githubId}'));
    expect(rules, isNot(contains("'category'")),
        reason: "a submission's category is its package's");
    expect(rules, contains('allow read, write: if false;'));
    final indexes = jsonDecode(
      File('../../firestore.indexes.json').readAsStringSync(),
    ) as Map;
    expect(
      [for (final i in indexes['indexes'] as List) (i as Map)['collectionGroup']],
      ['submissions', 'reports'],
    );
  });

  test("reads Firebase Auth's GitHub identity", () {
    expect(
      FirebaseIdentityLookup.githubIdIn({
        'users': [
          {
            'localId': 'u',
            'providerUserInfo': [
              {'providerId': 'google.com', 'rawId': '9'},
              {'providerId': 'github.com', 'rawId': '583231'},
            ],
          },
        ],
      }),
      583231,
    );
    expect(FirebaseIdentityLookup.githubIdIn({'users': <Object>[]}), isNull);
    expect(FirebaseIdentityLookup.githubIdIn({'kind': 'x'}), isNull);
  });

  test('the memory store queries, orders, limits, and keeps a file', () async {
    final dir = Directory.systemTemp.createTempSync('records_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/store.json');
    final s = MemoryDocumentStore(file: file);
    await s.set('items/a', {'n': 3, 'k': 'x'});
    await s.set('items/b', {'n': 1, 'k': 'x'});
    await s.set('items/c', {'n': 2, 'k': 'y'});
    await s.set('items/c/versions/1', {'n': 9});
    final back = MemoryDocumentStore(file: file);
    expect(
      (await back.query(
        'items',
        where: const [Filter.equal('k', 'x')],
        orderBy: const [OrderBy('n')],
      )).keys,
      ['b', 'a'],
    );
    expect(
      (await back.query(
        'items',
        where: const [Filter.greaterThan('n', 1)],
        orderBy: const [OrderBy('n', descending: true)],
        limit: 1,
      )).keys,
      ['a'],
    );
    expect((await back.list('items')).keys, ['a', 'b', 'c']);
    await back.update('items/a', {'n': 4});
    expect(await back.get('items/a'), {'n': 4, 'k': 'x'});
    expect(() => back.update('items/missing', {'a': 1}), throwsStateError);
  });
}

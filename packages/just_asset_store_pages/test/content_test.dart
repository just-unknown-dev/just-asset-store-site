// The words, links and routes the publish app shares with the pages.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:just_asset_store_pages/content.dart';
import 'package:test/test.dart';

void main() {
  test('the content library runs on the web: no dart:io, no Flutter', () {
    final files = [
      File('lib/content.dart'),
      ...Directory('lib/src/content').listSync().whereType<File>(),
    ];
    for (final f in files) {
      final src = f.readAsStringSync();
      expect(src, isNot(contains("'dart:io'")), reason: f.path);
      expect(src, isNot(contains("'package:flutter")), reason: f.path);
      expect(src, isNot(contains("'../pages/")), reason: f.path);
      expect(src, isNot(contains("'../build/")), reason: f.path);
    }
  });

  test('routes: the publish app owns three pages', () {
    expect(StoreRoutes.isAppPath('/publish'), isTrue);
    expect(StoreRoutes.isAppPath('/report?item=x'), isTrue);
    expect(StoreRoutes.isAppPath('/me/'), isTrue);
    expect(StoreRoutes.isAppPath('/'), isFalse);
    expect(StoreRoutes.isAppPath('/items/x'), isFalse);
    expect(StoreRoutes.appHead('/me').noindex, isTrue);
    expect(StoreRoutes.appHead('/nope'), same(StoreRoutes.notFound));
    expect(StoreLinks.report('my_kit'), '/report?item=my_kit');
  });

  test('the chrome marks the right entry for nested pages', () {
    final c = StoreMeta.chrome;
    expect(c.activeFor('/')?.label, 'Browse');
    expect(c.activeFor('/search')?.label, 'Browse');
    expect(c.activeFor('/items/x')?.label, 'Browse');
    expect(c.activeFor('/policy')?.label, 'Policy');
    expect(c.activeFor('/nope'), isNull);
    // Publishing is offered only once it is open to everyone.
    final publish = StoreAccess.openPublishing ? 'Publish' : null;
    expect(c.activeFor('/publish')?.label, publish);
    expect(c.activeFor('/report')?.label, publish);
    expect(c.activeFor('/me')?.label, publish);
    expect(
      [for (final f in c.footer) ...f.links].map((l) => l.href),
      StoreAccess.openPublishing
          ? contains(StoreRoutes.publishPath)
          : isNot(contains(StoreRoutes.publishPath)),
    );
  });

  test('who may publish: the same here, in the rules and in the backend', () {
    final config = jsonDecode(
      File('../just_asset_store_backend/catalog.json').readAsStringSync(),
    ) as Map<String, Object?>;
    expect(StoreAccess.openPublishing, config['openPublishing'] ?? false);
    expect(
      StoreAccess.officialIds,
      {for (final id in config['officialPublishers']! as List) '$id'},
    );
    final rules = File('../../firestore.rules').readAsStringSync();
    final allowed = RegExp(r"hasAny\(\[([^\]]*)\]\)").firstMatch(rules)!.group(1)!;
    expect(
      RegExp(r"'(\d+)'").allMatches(allowed).map((m) => m[1]).toSet(),
      StoreAccess.officialIds,
    );
    expect(StoreAccess.mayPublish('262105023'), isTrue);
    expect(StoreAccess.mayPublish('5001'), StoreAccess.openPublishing);
    expect(StoreAccess.mayPublish(null), StoreAccess.openPublishing);
  });

  test('report reasons are the ones the rules and the backend take', () {
    final rules = File('../../firestore.rules').readAsStringSync();
    final listed = RegExp(r"d\.reason in \[([^\]]*)\]").firstMatch(rules)!;
    final ids = RegExp(r"'([a-z]+)'")
        .allMatches(listed.group(1)!)
        .map((m) => m.group(1))
        .toList();
    expect(ReportReason.values.map((r) => r.id), ids);
    final backend = File(
      '../just_asset_store_backend/lib/src/backend.dart',
    ).readAsStringSync();
    for (final r in ReportReason.values) {
      expect(backend, contains("'${r.id}'"), reason: r.id);
    }
  });
}

// The whole site in one folder: the catalog's files, the publish app and
// the pages, as the Publish workflow deploys it.
@TestOn('vm')
library;

import 'dart:io';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_asset_store_pages/just_asset_store_pages.dart';
import 'package:test/test.dart';

import 'support/catalog.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('pages_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// The catalog as the backend exports it: index.json naming its pieces,
  /// and a card picture.
  Directory exported() {
    final dir = Directory('${tmp.path}/catalog')..createSync();
    CatalogFiles.of(testCatalog()).files.forEach((path, bytes) {
      File('${dir.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    });
    File('${dir.path}/thumbs/0123456789abcdef.jpg')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    // Not the catalog's: left behind.
    File('${dir.path}/notes.txt').writeAsStringSync('x');
    return dir;
  }

  /// A publish app's build, as `flutter build web` leaves it.
  Directory app() {
    final dir = Directory('${tmp.path}/app')..createSync();
    File('${dir.path}/index.html').writeAsStringSync(
      File('../../web/index.html').readAsStringSync(),
    );
    File('${dir.path}/main.dart.js').writeAsStringSync('// app');
    File('${dir.path}/canvaskit/canvaskit.wasm')
      ..createSync(recursive: true)
      ..writeAsStringSync('engine');
    File('${dir.path}/assets/packages/just_unknown_design/assets/fonts/Inter-Regular.ttf')
      ..createSync(recursive: true)
      ..writeAsStringSync('font');
    return dir;
  }

  test('catalog files, app and pages together', () async {
    final out = Directory('${tmp.path}/site');
    final report = await SiteBuild(
      catalog: exported(),
      app: app(),
      out: out,
    ).run();
    expect(report.items, 7);
    bool has(String path) => File('${out.path}/$path').existsSync();
    for (final path in [
      'index.json',
      'thumbs/0123456789abcdef.jpg',
      'main.dart.js',
      'assets/packages/just_unknown_design/assets/fonts/Inter-Regular.ttf',
      'index.html',
      'items/their_kit.html',
      'publish.html',
      'report.html',
      'me.html',
      '_headers',
      'search.json',
    ]) {
      expect(has(path), isTrue, reason: path);
    }
    expect(has('notes.txt'), isFalse);
    expect(has('canvaskit/canvaskit.wasm'), isFalse, reason: 'from the CDN');
    final pieces = Directory('${out.path}/catalog').listSync();
    expect(pieces, isNotEmpty);
    // The app's own index.html became its pages; the home page is ours.
    expect(File('${out.path}/index.html').readAsStringSync(), contains('New &amp; updated'));
    expect(report.files, greaterThan(15));

    // What the site serves is what the store reads.
    final served = await FolderStoreSource(out.path).fetchIndex();
    expect(served.index.items.map((i) => i.id), contains('their_kit'));

    // Built again over itself: emptied first.
    File('${out.path}/stale.html').writeAsStringSync('old');
    await SiteBuild(catalog: exported(), app: app(), out: out).run();
    expect(has('stale.html'), isFalse);
  });

  test('a folder that holds something else is not emptied', () async {
    final out = Directory('${tmp.path}/mine')..createSync();
    File('${out.path}/thesis.docx').writeAsStringSync('keep me');
    await expectLater(
      SiteBuild(catalog: exported(), out: out).run(),
      throwsA(isA<SiteBuildException>()),
    );
    expect(File('${out.path}/thesis.docx').existsSync(), isTrue);
  });

  test('a catalog that can\'t be read stops the build', () async {
    final bad = Directory('${tmp.path}/bad')..createSync();
    File('${bad.path}/index.json').writeAsStringSync('{"schema": 99}');
    await expectLater(
      SiteBuild(catalog: bad, out: Directory('${tmp.path}/o')).run(),
      throwsA(
        isA<SiteBuildException>().having(
          (e) => e.message,
          'message',
          contains('newer Asset Store'),
        ),
      ),
    );
  });

  test('without the app, the static pages alone', () async {
    final out = Directory('${tmp.path}/static');
    await SiteBuild(catalog: exported(), out: out).run();
    expect(File('${out.path}/index.html').existsSync(), isTrue);
    expect(File('${out.path}/publish.html').existsSync(), isFalse);
  });
}

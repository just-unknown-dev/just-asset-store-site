import 'dart:convert';
import 'dart:io';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../content/site_meta.dart';
import '../pages/store_pages.dart';

/// A build could not be made; nothing was deployed.
final class SiteBuildException implements Exception {
  const SiteBuildException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What [SiteBuild.run] made.
final class SiteBuildReport {
  SiteBuildReport({
    required this.items,
    required this.pages,
    required this.files,
    required this.bytes,
  });

  /// The items the catalog lists.
  final int items;

  /// The HTML pages written.
  final int pages;

  /// Every file in the build.
  final int files;

  /// Their total size.
  final int bytes;
}

/// The whole website in one folder, ready for Cloudflare Pages: the
/// catalog's own files (`index.json`, `catalog/`, `thumbs/`, `previews/`), the publish
/// app's build with its three pages, and the static pages built from the
/// catalog.
final class SiteBuild {
  SiteBuild({
    required this.catalog,
    required this.out,
    this.app,
    this.site = StoreMeta.identity,
    DateTime? buildDate,
  }) : buildDate = buildDate ?? DateTime.now().toUtc();

  /// The exported catalog: the folder holding `index.json`.
  final Directory catalog;

  /// The publish app's `flutter build web` output; none leaves its pages
  /// out (a preview of the static pages alone).
  final Directory? app;

  /// Where the site goes. Emptied first when it holds an earlier build.
  final Directory out;

  final SiteIdentity site;
  final DateTime buildDate;

  /// The most files Cloudflare Pages takes in one deploy.
  static const int maxFiles = 20000;

  /// The largest file Cloudflare Pages takes.
  static const int maxFileBytes = 25 * 1024 * 1024;

  /// The catalog's own files and folders, copied as they are.
  static const List<String> catalogEntries = [
    'index.json',
    'catalog',
    'thumbs',
    'previews',
  ];

  Future<SiteBuildReport> run() async {
    final StoreIndex index;
    try {
      index = (await FolderStoreSource(catalog.path).fetchIndex()).index;
    } on StoreFormatException catch (e) {
      throw SiteBuildException('The catalog can\'t be read: $e');
    } on SourceException catch (e) {
      throw SiteBuildException('The catalog can\'t be read: $e');
    }
    _prepareOut();
    final written = <String>{};

    void put(String path, List<int> bytes) {
      if (!written.add(path)) {
        throw SiteBuildException('Two parts of the build both write $path.');
      }
      if (bytes.length > maxFileBytes) {
        throw SiteBuildException(
          '$path is ${bytes.length} bytes; Cloudflare Pages takes files of up '
          'to ${maxFileBytes ~/ (1024 * 1024)} MiB.',
        );
      }
      File('${out.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }

    final appDir = app;
    if (appDir != null) {
      final template = File('${appDir.path}/index.html');
      if (!template.existsSync()) {
        throw SiteBuildException(
          'There is no publish app at ${appDir.path} (no index.html). Build '
          'it with `dart run tool/build.dart --out ${appDir.path}`.',
        );
      }
      for (final (path, file) in _files(appDir)) {
        // Its index.html is the template of its own pages, below; Flutter's
        // engine comes from Google's CDN (the build's bootstrap says so),
        // not from the site.
        if (path == 'index.html' || path.startsWith('canvaskit/')) continue;
        put(path, file.readAsBytesSync());
      }
    }
    for (final entry in catalogEntries) {
      final type = FileSystemEntity.typeSync('${catalog.path}/$entry');
      if (type == FileSystemEntityType.file) {
        put(entry, File('${catalog.path}/$entry').readAsBytesSync());
      } else if (type == FileSystemEntityType.directory) {
        for (final (path, file) in _files(Directory('${catalog.path}/$entry'))) {
          put('$entry/$path', file.readAsBytesSync());
        }
      }
    }

    final pages = StorePages(index, site: site, buildDate: buildDate);
    var html = 0;
    void text(String path, String content) {
      put(path, utf8.encode(content));
      if (path.endsWith('.html')) html++;
    }

    pages.files().forEach(text);
    pages.binaryFiles().forEach(put);
    if (appDir != null) {
      pages
          .appPages(File('${appDir.path}/index.html').readAsStringSync())
          .forEach(text);
    }
    if (written.length > maxFiles) {
      throw SiteBuildException(
        'The site has ${written.length} files; Cloudflare Pages takes up to '
        '$maxFiles in a deploy.',
      );
    }
    var bytes = 0;
    for (final path in written) {
      bytes += File('${out.path}/$path').lengthSync();
    }
    return SiteBuildReport(
      items: index.items.length,
      pages: html,
      files: written.length,
      bytes: bytes,
    );
  }

  /// Empties [out] when it holds an earlier build (it has `_headers`), and
  /// refuses a folder that holds something else.
  void _prepareOut() {
    if (out.existsSync() && out.listSync().isNotEmpty) {
      if (!File('${out.path}/_headers').existsSync()) {
        throw SiteBuildException(
          '${out.path} holds files that aren\'t a site build. Choose an empty '
          'folder.',
        );
      }
      out.deleteSync(recursive: true);
    }
    out.createSync(recursive: true);
  }

  /// Every file under [dir], by its path from [dir] with `/` between parts.
  static Iterable<(String, File)> _files(Directory dir) sync* {
    final base = dir.absolute.path.replaceAll(r'\', '/');
    final entries = dir.listSync(recursive: true, followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final e in entries) {
      if (e is! File) continue;
      final path = e.absolute.path.replaceAll(r'\', '/');
      yield (path.substring(base.length + 1), e);
    }
  }
}

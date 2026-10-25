// Builds the website around an exported catalog, for Cloudflare Pages:
//
//   dart run bin/pages.dart --catalog <folder with index.json>
//       [--app <the publish app's build>] --out <folder>
//       [--base-url https://store.justunknown.com]
//
// Preview the result with `npx wrangler pages dev <out>`.
import 'dart:io';

import 'package:args/args.dart';
import 'package:just_asset_store_pages/just_asset_store_pages.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'catalog',
      help: 'The exported catalog: the folder holding index.json.',
      mandatory: true,
    )
    ..addOption(
      'app',
      help: 'The publish app\'s build (dart run tool/build.dart). Without it '
          'the site has no /publish or /me.',
    )
    ..addOption('out', help: 'Where the site goes.', mandatory: true)
    ..addOption(
      'base-url',
      defaultsTo: StoreMeta.baseUrl,
      help: 'The address the site is served at (a preview deploy\'s, say).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln('pages: ${e.message}')
      ..writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (opts.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  final base = opts.option('base-url')!;
  final app = opts.option('app');
  try {
    final report = await SiteBuild(
      catalog: Directory(opts.option('catalog')!),
      app: app == null ? null : Directory(app),
      out: Directory(opts.option('out')!),
      site: base == StoreMeta.baseUrl
          ? StoreMeta.identity
          : StoreMeta.identity.at(base),
    ).run();
    stdout.writeln(
      'pages: ${report.items} items, ${report.pages} pages, ${report.files} '
      'files, ${(report.bytes / (1024 * 1024)).toStringAsFixed(1)} MiB '
      '-> ${opts.option('out')}',
    );
  } on SiteBuildException catch (e) {
    stderr.writeln('pages: $e');
    exitCode = 1;
  }
}

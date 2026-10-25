// Builds the publish app (/publish, /report, /me) for the web:
//
//   dart run tool/build.dart [--out build/app] [--no-wasm]
//
// The rest of the site is static pages, built around the catalog by
// packages/just_asset_store_pages (bin/pages.dart --app <this --out>).
// Flutter's engine files (CanvasKit, Skwasm) come from Google's CDN, so the
// build holds only the app itself.
import 'dart:io';

import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('out', defaultsTo: 'build/app', help: 'Where the build goes.')
    ..addFlag(
      'wasm',
      defaultsTo: true,
      help: 'Compile to WebAssembly too (browsers without it get JavaScript).',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln('build: ${e.message}')
      ..writeln(parser.usage);
    exit(64);
  }
  if (opts.flag('help')) {
    stdout.writeln(parser.usage);
    return;
  }
  final out = opts.option('out')!;
  final flutterArgs = <String>[
    'build',
    'web',
    '--release',
    if (opts.flag('wasm')) '--wasm',
    '--pwa-strategy=none',
    '--base-href',
    '/',
    '--output',
    out,
  ];
  stdout.writeln('build: flutter ${flutterArgs.join(' ')}');
  final proc = await Process.start(
    'flutter',
    flutterArgs,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await proc.exitCode;
  if (code != 0) exit(code);
  stdout.writeln('build: done -> $out');
}

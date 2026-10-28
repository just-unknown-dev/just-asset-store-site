// Publishes the store from this computer: what .github/workflows/publish.yml
// does on GitHub, run by hand with your own logins instead of the workflow's.
//
//   dart tool/publish_local.dart --pages-project <cloudflare pages project>
//
// Steps, as in the workflow:
//   1. answer the website's submissions and reports, check new releases
//      (backend run), with your gcloud login on Firestore and Firebase Auth;
//   2. export the catalog (backend export): index.json, pieces, pictures;
//   3. build the publish app (/publish, /report, /me) when its code changed;
//   4. build the static site around the catalog (just_asset_store_pages);
//   5. deploy build/site to Cloudflare Pages (wrangler, your login);
//   6. record the deploy (backend exported).
//
// Logins (the script asks to log in to gcloud or wrangler when either needs
// it, opens the browser and waits for the login before going on):
//   gcloud auth login            the Google account that owns the Firebase project
//   npx wrangler login           your Cloudflare account
//   GITHUB_TOKEN=<token>         a fine-grained GitHub token (Issues: read and
//                                write on this repository; public releases
//                                need nothing more), in .env or the environment
//
// .env (this folder, gitignored) holds KEY=VALUE lines: GITHUB_TOKEN and,
// optionally, CLOUDFLARE_PAGES_PROJECT. The environment wins over it.
//
// Options:
//   --pages-project=NAME  the Cloudflare Pages project (or CLOUDFLARE_PAGES_PROJECT)
//   --project=ID          the Firebase project (default: lib/firebase_options.dart's)
//   --live=URL            where the live site is (default https://asset.justunknown.com)
//   --rules               deploy firestore.rules and the indexes first (firebase CLI)
//   --full                read every record, not only what changed
//   --allow-shrink        deploy a catalog with far fewer items than the live one
//   --rebuild-app         build the publish app even if its code didn't change
//   --no-deploy           stop after building build/site (steps 1-4 still write
//                         to Firestore: submissions are answered)
//
// Only dart: libraries, so `dart tool/publish_local.dart` needs no pub get.
import 'dart:convert';
import 'dart:io';

const wranglerVersion = '4.152.0';
const firebaseToolsVersion = '15.34.1';

final root = File.fromUri(Platform.script).parent.parent;
final backendDir = Directory('${root.path}/packages/just_asset_store_backend');
final pagesDir = Directory('${root.path}/packages/just_asset_store_pages');
final backendExe = File(
  '${backendDir.path}/build/backend${Platform.isWindows ? '.exe' : ''}',
);

/// The KEY=VALUE lines of this repository's .env (gitignored): local
/// settings such as GITHUB_TOKEN. Empty when there is none.
final Map<String, String> dotEnv = readDotEnv();

Map<String, String> readDotEnv() {
  final file = File('${root.path}/.env');
  if (!file.existsSync()) return const {};
  final String text;
  try {
    text = file.readAsStringSync().replaceFirst('﻿', '');
  } on FileSystemException {
    throw Stop('.env must be UTF-8 text (save it as UTF-8).');
  }
  final values = <String, String>{};
  for (var line in const LineSplitter().convert(text)) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trim();
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var value = line.substring(eq + 1).trim();
    if (value.length >= 2 &&
        (value[0] == '"' || value[0] == "'") &&
        value[value.length - 1] == value[0]) {
      value = value.substring(1, value.length - 1);
    }
    values[line.substring(0, eq).trim()] = value;
  }
  return values;
}

/// [name] from the environment, else from .env; null when neither sets it.
String? setting(String name) {
  for (final value in [Platform.environment[name], dotEnv[name]]) {
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// .env files hold secrets: never copied for a build.
bool isDotEnv(String name) => name == '.env' || name.startsWith('.env.');

class Stop implements Exception {
  Stop(this.message);
  final String message;
  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  try {
    await publish(args);
  } on Stop catch (e) {
    stderr.writeln('\nFAIL $e');
    exitCode = 1;
  } finally {
    dropCopy();
  }
}

Future<void> publish(List<String> args) async {
  String? option(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  bool flag(String name) => args.contains('--$name');
  const known = {
    'pages-project', 'project', 'live', //
    'rules', 'full', 'allow-shrink', 'rebuild-app', 'no-deploy',
  };
  for (final a in args) {
    final name = a.startsWith('--') ? a.substring(2).split('=').first : '';
    if (!known.contains(name)) {
      throw Stop(
        'Unknown argument "$a". See the top of tool/publish_local.dart.',
      );
    }
  }

  final deploy = !flag('no-deploy');
  final project = option('project') ?? firebaseProject();
  final live = (option('live') ?? 'https://asset.justunknown.com').replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final pagesProject =
      option('pages-project') ?? setting('CLOUDFLARE_PAGES_PROJECT');
  if (deploy && (pagesProject == null || pagesProject.isEmpty)) {
    throw Stop(
      'Say which Cloudflare Pages project to deploy to: --pages-project=NAME.\n'
      '     `npx wrangler pages project list` lists yours.',
    );
  }

  // ── Logins ─────────────────────────────────────────────────────────────
  step('Logins');
  final githubToken = setting('GITHUB_TOKEN') ?? '';
  if (githubToken.isEmpty) {
    throw Stop(
      'No GITHUB_TOKEN: put `GITHUB_TOKEN=<token>` in .env (this folder; git '
      'ignores it). The backend asks GitHub which releases exist and files '
      'reports as issues here: a fine-grained token with Issues: read and '
      'write on this repository (github.com/settings/personal-access-tokens).',
    );
  }
  final tokenInEnvironment =
      Platform.environment['GITHUB_TOKEN']?.isNotEmpty ?? false;
  ok('GITHUB_TOKEN is set${tokenInEnvironment ? '' : ' (from .env)'}');
  final googleToken = await gcloudToken(project);
  ok('gcloud: ${await gcloudAccount()} (project $project)');
  if (deploy) {
    ok('wrangler: ${await wranglerAccount()}');
    await checkPagesProject(pagesProject!);
    ok('Cloudflare Pages project: $pagesProject');
  }
  final options = File('${root.path}/lib/firebase_options.dart');
  if (!options.existsSync() ||
      !options.readAsStringSync().contains("projectId: '$project'")) {
    throw Stop(
      'lib/firebase_options.dart is missing or not for $project: the publish '
      'app signs in with it (flutterfire configure makes it).',
    );
  }

  final env = {
    'FIREBASE_PROJECT': project,
    'GOOGLE_OAUTH_ACCESS_TOKEN': googleToken,
    'GOOGLE_CLOUD_QUOTA_PROJECT': project,
    'GITHUB_TOKEN': githubToken,
  };

  // ── Firestore rules and indexes ────────────────────────────────────────
  if (flag('rules')) {
    step('Firestore rules and indexes');
    await stream('npx', [
      '--yes',
      'firebase-tools@$firebaseToolsVersion',
      'deploy',
      '--only',
      'firestore:rules,firestore:indexes',
      '--project',
      project,
      '--non-interactive',
    ], dir: root);
  }

  // ── 1. The backend ─────────────────────────────────────────────────────
  step('Backend');
  await compileBackend();
  final runResult = await backend(['run', '--json'], env);
  final outcomes = (runResult['outcomes'] as List?) ?? const [];
  if (outcomes.isEmpty) note('no submissions, reports or new releases');
  for (final o in outcomes.cast<Map<String, dynamic>>()) {
    final mark = o['ok'] == true
        ? (o['held'] == true ? 'held' : 'ok  ')
        : (o['retry'] == true ? 'later' : 'x   ');
    stdout.writeln('  $mark ${o['message']}');
  }

  // ── 2. The catalog ─────────────────────────────────────────────────────
  step('Catalog');
  final catalogDir = Directory('${backendDir.path}/build/catalog');
  if (catalogDir.existsSync()) catalogDir.deleteSync(recursive: true);
  final export = await backend([
    'export',
    '--out',
    'build/catalog',
    '--previous',
    '$live/index.json',
    '--thumbs',
    'build/thumbs',
    if (flag('full')) '--full',
    if (flag('allow-shrink')) '--allow-shrink',
    '--json',
  ], env);
  ok(
    '${export['items']} items in ${export['pieces']} pieces'
    '${export['full'] == true ? ' (every record read)' : ''}',
  );
  for (final s in (export['skipped'] as List?) ?? const []) {
    note('left out: $s');
  }

  // ── 3. The publish app ─────────────────────────────────────────────────
  step('Publish app');
  final appDir = Directory('${root.path}/build/app');
  // Beside build/app, not in it: the site carries build/app's files.
  final stamp = File('${root.path}/build/app.inputs');
  final inputs = appInputs();
  if (!flag('rebuild-app') &&
      appDir.existsSync() &&
      stamp.existsSync() &&
      stamp.readAsStringSync() == inputs) {
    ok('unchanged since the last build: build/app reused');
  } else {
    final copy = await cleanCopy();
    await pubGet(copy, flutter: true);
    await stream('dart', [
      'run',
      'tool/build.dart',
      '--out',
      appDir.absolute.path,
    ], dir: copy);
    stamp.writeAsStringSync(inputs);
    ok('built build/app');
  }

  // ── 4. The site ────────────────────────────────────────────────────────
  step('Site');
  final siteDir = Directory('${root.path}/build/site');
  if (siteDir.existsSync()) siteDir.deleteSync(recursive: true);
  final copyPages = Directory(
    '${(await cleanCopy()).path}/packages/just_asset_store_pages',
  );
  await pubGet(copyPages);
  await stream('dart', [
    'run',
    'bin/pages.dart',
    '--catalog',
    Directory('${backendDir.path}/build/catalog').absolute.path,
    '--app',
    appDir.absolute.path,
    '--out',
    siteDir.absolute.path,
  ], dir: copyPages);
  final pages = siteDir.listSync(recursive: true).whereType<File>().length;
  ok('build/site: $pages files');

  if (!deploy) {
    note('--no-deploy: build/site is ready, nothing deployed.');
    return;
  }

  // ── 5. Deploy ──────────────────────────────────────────────────────────
  step('Deploy to Cloudflare Pages ($pagesProject)');
  await stream('npx', [
    '--yes',
    'wrangler@$wranglerVersion',
    'pages',
    'deploy',
    'build/site',
    '--project-name',
    pagesProject!,
    '--branch',
    'main',
    '--commit-dirty=true',
  ], dir: root);

  // ── 6. Record it ───────────────────────────────────────────────────────
  step('Record the deploy');
  await backend([
    'exported',
    '--root',
    '${export['rootSha']}',
    '--since',
    '${export['startedMs']}',
    if (export['full'] == true) '--full',
    '--json',
  ], env);
  ok('recorded');

  step('Done');
  final index = await statusOf(Uri.parse('$live/index.json'));
  if (index == 200) {
    ok('$live/index.json is live');
  } else {
    note(
      '$live/index.json answers $index: is $live a custom domain of the '
      '"$pagesProject" Pages project? (The editor reads the catalog there.)',
    );
  }
}

// ── Pieces ─────────────────────────────────────────────────────────────────

void step(String s) => stdout.writeln('\n== $s');
void ok(String s) => stdout.writeln('  ok  $s');
void note(String s) => stdout.writeln('   -  $s');

/// The Firebase project lib/firebase_options.dart is for.
String firebaseProject() {
  final f = File('${root.path}/lib/firebase_options.dart');
  final m = f.existsSync()
      ? RegExp(r"projectId: '([^']+)'").firstMatch(f.readAsStringSync())
      : null;
  if (m == null) throw Stop('No project: pass --project=ID.');
  return m.group(1)!;
}

/// A Google access token from gcloud; when gcloud has no login (or it
/// expired), asks to log in, waits for it, and tries again.
Future<String> gcloudToken(String project) async {
  for (var tried = false; ; tried = true) {
    final r = await run('gcloud', ['auth', 'print-access-token']);
    final token = (r.stdout as String).trim();
    if (r.exitCode == 0 && token.isNotEmpty) return token;
    final err = (r.stderr as String).trim();
    if (r.exitCode == 9009 || err.contains('is not recognized')) {
      throw Stop(
        "gcloud isn't installed: cloud.google.com/sdk/docs/install, then "
        'open a new terminal.',
      );
    }
    if (tried) throw Stop("gcloud still can't make a Google token:\n$err");
    await logIn(
      'gcloud',
      ['gcloud', 'auth', 'login'],
      hint: 'Pick the Google account that owns the Firebase project $project.',
    );
  }
}

/// Who wrangler is logged in as; when it isn't, asks to log in, waits for
/// it, and checks again.
Future<String> wranglerAccount() async {
  final wrangler = ['--yes', 'wrangler@$wranglerVersion'];
  for (var tried = false; ; tried = true) {
    final r = await run('npx', [...wrangler, 'whoami']);
    final text = '${r.stdout}${r.stderr}';
    final loggedOut = text.contains('not authenticated');
    if (r.exitCode == 0 && !loggedOut) {
      final email = RegExp(r'associated with the email ([^\s]+)')
          .firstMatch(text);
      return email?.group(1)?.replaceAll(RegExp(r'\.$'), '') ?? 'logged in';
    }
    // Not a login problem (no network, say): a login wouldn't help.
    if (!loggedOut) throw Stop('wrangler whoami failed:\n${text.trim()}');
    if (tried) throw Stop('wrangler is still not logged in.');
    await logIn('Cloudflare (wrangler)', ['npx', ...wrangler, 'login']);
  }
}

/// Stops unless the Cloudflare account has a Pages project called [name]
/// (wrangler would otherwise offer to create one in the middle of the
/// deploy, after everything else ran).
Future<void> checkPagesProject(String name) async {
  final r = await run('npx', [
    '--yes',
    'wrangler@$wranglerVersion',
    'pages',
    'project',
    'list',
  ]);
  final text = '${r.stdout}${r.stderr}';
  if (r.exitCode != 0) {
    throw Stop('wrangler pages project list failed:\n${text.trim()}');
  }
  // The table's first column: "│ name │ domains │ ...".
  final names = [
    for (final m in RegExp(
      r'^[│|]\s*([a-z0-9][a-z0-9-]*)\s+[│|]',
      multiLine: true,
    ).allMatches(text))
      m[1]!,
  ];
  if (!names.contains(name)) {
    throw Stop(
      'Cloudflare has no Pages project "$name"'
      '${names.isEmpty ? '' : ' (yours: ${names.join(', ')})'}. Set '
      'CLOUDFLARE_PAGES_PROJECT in .env, or pass --pages-project=NAME.',
    );
  }
}

/// A missing login: asks first, then runs [command] in this terminal (it
/// opens the browser) and waits for it to finish. Stops on a no, or when
/// there is no terminal to ask in.
Future<void> logIn(String what, List<String> command, {String? hint}) async {
  final shown = command.join(' ');
  note("$what isn't logged in, or its login expired.");
  if (hint != null) note(hint);
  if (!confirm('Log in now?')) {
    throw Stop('$what: run `$shown`, then run this again.');
  }
  await stream(command.first, command.sublist(1), dir: root);
  ok('$what login finished');
}

/// Asks a yes/no question (yes by default); false when there is no
/// terminal to answer in.
bool confirm(String question) {
  try {
    if (!stdin.hasTerminal) return false;
    stdout.write('   ?  $question [Y/n] ');
    final answer = (stdin.readLineSync() ?? 'n').trim().toLowerCase();
    return answer.isEmpty || answer == 'y' || answer == 'yes';
  } on StdinException {
    return false;
  }
}

Future<String> gcloudAccount() async =>
    ((await run('gcloud', ['config', 'get-value', 'account'])).stdout as String)
        .trim();

/// Compiles the backend when its code is newer than the last build.
Future<void> compileBackend() async {
  final sources = [
    for (final d in ['lib', 'bin'])
      ...Directory('${backendDir.path}/$d')
          .listSync(recursive: true)
          .whereType<File>(),
    File('${backendDir.path}/pubspec.yaml'),
    File('${backendDir.path}/pubspec.lock'),
  ].where((f) => f.existsSync());
  final newest = sources
      .map((f) => f.lastModifiedSync())
      .reduce((a, b) => a.isAfter(b) ? a : b);
  if (backendExe.existsSync() &&
      backendExe.lastModifiedSync().isAfter(newest)) {
    ok('backend: compiled already');
    return;
  }
  final copy = Directory(
    '${(await cleanCopy()).path}/packages/just_asset_store_backend',
  );
  await pubGet(copy);
  backendExe.parent.createSync(recursive: true);
  await stream(
    'dart',
    ['compile', 'exe', 'bin/backend.dart', '-o', backendExe.absolute.path],
    dir: copy,
    quiet: true,
  );
  ok('backend: compiled');
}

/// `pub get` in [dir] of the clean copy: exactly what its pubspec.lock
/// names, as the workflow does; a lockfile made with local overrides (it
/// names paths) can't be kept, and is resolved again from pub.dev instead.
/// Either way only the copy changes.
Future<void> pubGet(Directory dir, {bool flutter = false}) async {
  final exe = flutter ? 'flutter' : 'dart';
  final r = await Process.run(
    exe,
    ['pub', 'get', '--enforce-lockfile'],
    workingDirectory: dir.path,
    runInShell: Platform.isWindows,
  );
  if (r.exitCode == 0) return;
  final name = dir.path.substring((_copy ?? dir).path.length);
  note(
    'pubspec.lock${name.isEmpty ? '' : ' in ${name.substring(1)}'} names '
    'local paths: resolving from pub.dev (your lockfile is left as it is)',
  );
  await stream(exe, ['pub', 'get'], dir: dir, quiet: true);
}

Directory? _copy;

/// This repository's code (lib, web, tool, packages and the root files) in
/// a temporary folder, without any pubspec_overrides.yaml: built from there
/// with `pub get --enforce-lockfile`, it uses exactly the packages from
/// pub.dev the lockfiles name, as the workflow does, and the lockfiles here
/// are never rewritten. Made once a run; [dropCopy] removes it.
Future<Directory> cleanCopy() async {
  if (_copy case final copy?) return copy;
  final copy = Directory.systemTemp.createTempSync('jsite');
  const skipDirs = {'.dart_tool', '.git', 'node_modules'};
  void copyTree(Directory from, Directory to) {
    to.createSync(recursive: true);
    for (final e in from.listSync(followLinks: false)) {
      final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (e is Directory) {
        // build/ is output only at a package's top (lib/src/build is code).
        final isPackageTop = File('${from.path}/pubspec.yaml').existsSync();
        final skip = name == 'build' ? isPackageTop : skipDirs.contains(name);
        if (!skip) copyTree(e, Directory('${to.path}/$name'));
      } else if (e is File &&
          name != 'pubspec_overrides.yaml' &&
          !isDotEnv(name)) {
        e.copySync('${to.path}/$name');
      }
    }
  }

  for (final e in root.listSync(followLinks: false)) {
    final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (e is File && name != 'pubspec_overrides.yaml' && !isDotEnv(name)) {
      e.copySync('${copy.path}/$name');
    } else if (e is Directory &&
        const {'lib', 'web', 'tool', 'packages'}.contains(name)) {
      copyTree(e, Directory('${copy.path}/$name'));
    }
  }
  return _copy = copy;
}

void dropCopy() {
  try {
    _copy?.deleteSync(recursive: true);
  } on FileSystemException {
    // A file Windows still holds; the temp folder keeps it.
  }
}

/// Runs the backend with `--json`, and returns its result.
Future<Map<String, dynamic>> backend(
  List<String> args,
  Map<String, String> env,
) async {
  final r = await Process.run(
    backendExe.path,
    args,
    workingDirectory: backendDir.path,
    environment: env,
  );
  final err = (r.stderr as String).trim();
  if (err.isNotEmpty) {
    for (final line in const LineSplitter().convert(err)) {
      stdout.writeln('   -  $line');
    }
  }
  final out = (r.stdout as String).trim();
  Map<String, dynamic>? json;
  try {
    json = jsonDecode(out) as Map<String, dynamic>;
  } on FormatException {
    json = null;
  }
  if (r.exitCode != 0 || json == null) {
    final hint = out.contains('could not query') && out.contains(': 400')
        ? '\n     Firestore lacks an index, or is still building one: run '
              'once with --rules, wait a few minutes, and run again.'
        : '';
    throw Stop('backend ${args.first} failed (exit ${r.exitCode}).\n$out$hint');
  }
  return (json['result'] as Map<String, dynamic>?) ?? const {};
}

/// What the publish app is built from, as path|size|time lines: the same
/// inputs the workflow's cache key hashes.
String appInputs() {
  final out = <String>[];
  void add(FileSystemEntity e) {
    if (e is File) {
      final s = e.statSync();
      out.add(
        '${e.path.substring(root.path.length)}|${s.size}|'
        '${s.modified.millisecondsSinceEpoch}',
      );
    } else if (e is Directory && e.existsSync()) {
      for (final f in e.listSync(recursive: true).whereType<File>()) {
        add(f);
      }
    }
  }

  for (final p in [
    'lib',
    'web',
    'tool/build.dart',
    'pubspec.yaml',
    'pubspec.lock',
    'packages/just_unknown_site/lib',
    'packages/just_unknown_design/lib',
    'packages/just_unknown_design/assets',
    'packages/just_asset_store_pages/lib',
  ]) {
    final type = FileSystemEntity.typeSync('${root.path}/$p');
    if (type == FileSystemEntityType.file) add(File('${root.path}/$p'));
    if (type == FileSystemEntityType.directory) {
      add(Directory('${root.path}/$p'));
    }
  }
  out.sort();
  return out.join('\n');
}

Future<ProcessResult> run(String exe, List<String> args) => Process.run(
  exe,
  args,
  workingDirectory: root.path,
  environment: environmentFor(exe),
  runInShell: Platform.isWindows,
  // wrangler writes UTF-8 (its table, its emoji) whatever the console's
  // code page.
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
);

/// npx tools (wrangler, firebase-tools) run on Node, which tries IPv6 first:
/// where the IPv6 route resets connections (as to api.cloudflare.com on some
/// networks, "fetch failed"), IPv4 first works. Other tools: unchanged.
Map<String, String>? environmentFor(String exe) {
  if (exe != 'npx') return null;
  final options = Platform.environment['NODE_OPTIONS'] ?? '';
  if (options.contains('--dns-result-order')) return null;
  return {'NODE_OPTIONS': '$options --dns-result-order=ipv4first'.trim()};
}

/// Runs [exe] with its output shown as it goes (only on failure when
/// [quiet]); stops on a non-zero exit.
Future<void> stream(
  String exe,
  List<String> args, {
  required Directory dir,
  bool quiet = false,
}) async {
  if (quiet) {
    final r = await Process.run(
      exe,
      args,
      workingDirectory: dir.path,
      environment: environmentFor(exe),
      runInShell: Platform.isWindows,
    );
    if (r.exitCode != 0) {
      throw Stop('$exe ${args.join(' ')} failed:\n${r.stdout}${r.stderr}');
    }
    return;
  }
  final p = await Process.start(
    exe,
    args,
    workingDirectory: dir.path,
    environment: environmentFor(exe),
    runInShell: Platform.isWindows,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await p.exitCode;
  if (code != 0) throw Stop('$exe ${args.join(' ')} failed (exit $code).');
}

Future<int> statusOf(Uri url) async {
  final client = HttpClient();
  try {
    final res = await (await client.getUrl(url)).close();
    await res.drain<void>();
    return res.statusCode;
  } on IOException {
    return 0;
  } finally {
    client.close();
  }
}

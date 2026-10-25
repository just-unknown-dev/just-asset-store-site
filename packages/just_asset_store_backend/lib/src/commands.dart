/// The backend's commands, as the workflows run them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_core_cli/fetch.dart';
import 'package:just_core_cli/just_core_cli.dart';

import 'backend.dart';
import 'documents.dart';
import 'firestore.dart';
import 'github.dart';
import 'identity.dart';
import 'pub_dev.dart';
import 'thumbnails.dart';

/// What every backend command shares: the records, GitHub and the settings.
abstract class BackendCommand extends JustCommand {
  BackendCommand() {
    argParser
      ..addOption(
        'config',
        defaultsTo: 'catalog.json',
        help: "The backend's settings.",
      )
      ..addOption(
        'memory',
        valueHelp: 'file',
        help:
            'Keep the records in this JSON file instead of Firestore: to try '
            'it locally.',
      );
  }

  (String, String)? get _firebase {
    final env = context.environment;
    final project = env['FIREBASE_PROJECT'];
    final token = env['GOOGLE_OAUTH_ACCESS_TOKEN'];
    return project == null || token == null ? null : (project, token);
  }

  /// GitHub, with the workflow's token.
  GitHubApi github() =>
      HttpGitHubApi(token: context.environment['GITHUB_TOKEN'] ?? '');

  /// The backend, on Firestore (or `--memory`).
  StoreBackend backend() {
    final memory = argResults!.option('memory');
    final DocumentStore store;
    if (memory != null) {
      store = MemoryDocumentStore(file: File(memory));
    } else {
      final firebase = _firebase;
      if (firebase == null) {
        throw const CommandFailure(
          'FIREBASE_PROJECT and GOOGLE_OAUTH_ACCESS_TOKEN are not set (or '
          'pass --memory <file> to try it locally).',
        );
      }
      store = FirestoreDocumentStore(
        project: firebase.$1,
        accessToken: firebase.$2,
      );
    }
    final config = File(argResults!.option('config')!);
    if (!config.existsSync()) {
      throw CommandFailure('There is no ${config.path}.');
    }
    return StoreBackend(
      store: store,
      github: github(),
      pubDev: HttpPubDevApi(),
      config: BackendConfig.parse(config.readAsStringSync()),
    );
  }

  /// Prints [outcomes], one a line, and makes them the `--json` result.
  void report(List<Outcome> outcomes, {Map<String, Object?> extra = const {}}) {
    for (final o in outcomes) {
      output.line(
        '${o.ok ? (o.held ? 'held' : 'ok  ') : (o.retry ? 'later' : 'x   ')} '
        '${o.message}',
      );
    }
    output.result = {
      ...extra,
      'outcomes': [
        for (final o in outcomes)
          {
            'ok': o.ok,
            'message': o.message,
            'id': o.id,
            if (o.retry) 'retry': true,
            if (o.held) 'held': true,
          },
      ],
    };
  }

  /// The integer option [name].
  int intOption(String name, {int? fallback}) {
    final text = argResults!.option(name);
    final value = text == null ? fallback : int.tryParse(text);
    if (value == null) throw UsageFailure('--$name takes a number.');
    return value;
  }
}

/// `run`: the website's submissions and reports, then every watched
/// repository's new releases.
final class RunCommand extends BackendCommand {
  RunCommand() {
    argParser
      ..addOption(
        'identities',
        valueHelp: 'file',
        help:
            'A JSON file of Firebase uid -> GitHub id, instead of asking '
            'Firebase Auth: to try it locally with --memory.',
      )
      ..addOption(
        'limit',
        defaultsTo: '50',
        help: 'At most this many submissions, and this many releases.',
      );
  }

  @override
  String get name => 'run';

  @override
  String get description =>
      "Answer the website's submissions and reports, and check new releases.";

  @override
  Future<int> run() async {
    final b = backend();
    final IdentityLookup identities;
    final file = argResults!.option('identities');
    if (file != null) {
      final json = jsonDecode(File(file).readAsStringSync()) as Map;
      identities = MapIdentityLookup({
        for (final e in json.entries) '${e.key}': e.value as int,
      });
    } else if (_firebase case (final project, final token)) {
      identities = FirebaseIdentityLookup(project: project, accessToken: token);
    } else {
      throw const CommandFailure(
        'FIREBASE_PROJECT and GOOGLE_OAUTH_ACCESS_TOKEN are not set (or pass '
        '--identities <file> with --memory to try it locally).',
      );
    }
    final r = await b.run(identities: identities, limit: intOption('limit'));
    if (r.outcomes.isEmpty) output.line('Nothing happened.');
    output.line(r.deploy ? 'The catalog changed.' : 'The catalog is as it was.');
    report(r.outcomes, extra: {'deploy': r.deploy});
    // A refused package is its publisher's to fix, not a failed run.
    return 0;
  }
}

/// `submit`: one repository, checked by a maintainer's hand (the website
/// files the usual ones; see `run`).
final class SubmitCommand extends BackendCommand {
  SubmitCommand() {
    argParser
      ..addOption('repo', help: 'The GitHub repository.')
      ..addOption(
        'submitter-id',
        help: "The publisher's numeric GitHub id (its claim code's).",
      );
  }

  @override
  String get name => 'submit';

  @override
  String get description => 'Check a repository\'s latest release and list it.';

  @override
  Future<int> run() async {
    final repo = argResults!.option('repo');
    if (repo == null || repo.isEmpty) {
      throw const UsageFailure('submit needs --repo and --submitter-id.');
    }
    final id = intOption('submitter-id');
    final b = backend();
    final login = await b.github.login(id);
    if (login == null) throw CommandFailure('There is no GitHub account $id.');
    final o = await b.submit(repoUrl: repo, submitterId: id, login: login);
    report([o]);
    return o.ok ? 0 : 1;
  }
}

/// `moderate`: a maintainer's decision.
final class ModerateCommand extends BackendCommand {
  ModerateCommand() {
    argParser
      ..addOption('id', help: 'The item.')
      ..addOption(
        'action',
        help:
            'block, unblock, block:<v>, unblock:<v>, yank:<v>, unyank:<v>, '
            'trust:<level>, approve, reject.',
      )
      ..addOption('actor-id', help: "Who decided: a numeric GitHub id.");
  }

  @override
  String get name => 'moderate';

  @override
  String get description =>
      'Take down, withdraw, approve or refuse, or set a publisher\'s trust.';

  @override
  Future<int> run() async {
    final id = argResults!.option('id');
    final action = argResults!.option('action');
    if (id == null || action == null) {
      throw const UsageFailure('moderate needs --id, --action and --actor-id.');
    }
    final o = await backend().moderate(
      id: id,
      action: action,
      actorId: intOption('actor-id'),
    );
    report([o]);
    return o.ok ? 0 : 1;
  }
}

/// `export`: the catalog in pieces, and its card pictures, for the site.
final class ExportCommand extends BackendCommand {
  ExportCommand() {
    argParser
      ..addOption(
        'out',
        abbr: 'o',
        defaultsTo: 'build/catalog',
        help: 'The folder index.json, its pieces, thumbs/ and previews/ go in.',
      )
      ..addOption(
        'previous',
        valueHelp: 'url',
        help:
            "The deployed catalog's index.json: the export builds on it, and "
            'keeps its pieces for editors that read it a moment ago.',
      )
      ..addOption(
        'thumbs',
        defaultsTo: 'build/thumbs',
        help: 'Where card and gallery pictures are kept between runs.',
      )
      ..addFlag('full', negatable: false, help: 'Read every record.')
      ..addFlag(
        'allow-shrink',
        negatable: false,
        help: 'Export a catalog with far fewer items than the deployed one.',
      );
  }

  @override
  String get name => 'export';

  @override
  String get description =>
      'Write the catalog — index.json, its pieces and card pictures.';

  @override
  Future<int> run() async {
    final b = backend();
    final previousUrl = argResults!.option('previous');
    StoreIndex? previous;
    CatalogRoot? previousRoot;
    final fetcher = HttpFetcher(userAgent: 'just_asset_store_backend/0.2.0');
    if (previousUrl != null) {
      final uri = Uri.parse(previousUrl);
      try {
        previous = (await HttpStoreSource(uri).fetchIndex()).index;
        final text = utf8.decode((await fetcher.get(uri)).body);
        final json = JsonFields.parse(text);
        if (CatalogRoot.isSplit(json)) previousRoot = CatalogRoot.fromJson(json);
      } on Object catch (e) {
        output.warn('The deployed catalog could not be read ($e): reading every record.');
        previous = null;
      }
    }
    final result = await b.export(
      previous: previous,
      full: argResults!.flag('full'),
    );

    // A deploy that drops far more than usual is more likely a fault than a
    // decision: it needs saying so.
    final before = previous?.items.length ?? 0;
    final after = result.index.items.length;
    if (!argResults!.flag('allow-shrink') &&
        before - after > 5 &&
        after < before * 0.9) {
      throw CommandFailure(
        'The catalog would shrink from $before to $after items. If that is '
        'meant, export with --allow-shrink.',
      );
    }

    final out = Directory(argResults!.option('out')!)
      ..createSync(recursive: true);
    void write(String path, List<int> bytes) => File('${out.path}/$path')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    // Card and gallery pictures: kept, fetched from the live site, or made.
    // A picture that can't be had is left out of its item.
    final pictures = Thumbnails(
      github: b.github,
      cacheDir: Directory(argResults!.option('thumbs')!),
      liveSite: previousUrl == null ? null : Uri.parse(previousUrl),
    );
    Future<bool> publish(String path) async {
      final bytes = await pictures.bytesOf(
        path,
        source: result.pictures[path],
      );
      if (bytes == null) return false;
      write(path, bytes);
      return true;
    }

    final items = <StoreItem>[];
    for (final item in result.index.items) {
      final json = item.toJson();
      final card = item.thumbnail;
      if (card != null && (!card.startsWith('thumbs/') || !await publish(card))) {
        json.remove('thumbnail');
      }
      json['previews'] = [
        for (final path in item.previews)
          if (path.startsWith('previews/') && await publish(path)) path,
      ];
      items.add(StoreItem.fromJson(JsonFields(json)));
    }
    final index = StoreIndex.checked(
      source: result.index.source,
      categories: result.index.categories,
      items: items,
      removed: result.index.removed,
      generatedAt: result.index.generatedAt,
      featured: result.index.featured,
    );
    final files = CatalogFiles.of(index);
    files.files.forEach(write);

    // The deployed catalog's pieces stay one more deploy: an editor that
    // read its index.json a moment ago still finds them.
    var kept = 0;
    final root = previousRoot;
    if (root != null && previousUrl != null) {
      for (final ref in root.pieces) {
        if (files.pieces.containsKey(ref.path)) continue;
        try {
          final bytes = (await fetcher.get(
            Uri.parse(previousUrl).resolve(ref.path),
            maxBytes: ref.size,
          )).body;
          if (Sha256.hexOf(bytes) == ref.sha256) {
            write(ref.path, bytes);
            kept++;
          }
        } on Object {
          // Gone already: editors that need it ask for index.json again.
        }
      }
    }

    final rootSha = Sha256.hexOf(Uint8List.fromList(utf8.encode(files.rootText)));
    for (final s in result.skipped) {
      output.warn('Left out: $s');
    }
    output
      ..result = {
        'items': after,
        'removed': index.removed.length,
        'pieces': files.pieces.length,
        'keptPieces': kept,
        'rootSha': rootSha,
        'startedMs': result.startedMs,
        'full': result.full,
        'skipped': result.skipped,
      }
      ..line(
        'Exported $after items in ${files.pieces.length} pieces into '
        '${out.path}${result.full ? ' (every record read)' : ''}.',
      );
    return 0;
  }
}

/// `exported`: records that an export was deployed.
final class ExportedCommand extends BackendCommand {
  ExportedCommand() {
    argParser
      ..addOption('root', help: "The deployed index.json's SHA-256.")
      ..addOption('since', help: "The export's startedMs.")
      ..addFlag('full', negatable: false, help: 'It read every record.');
  }

  @override
  String get name => 'exported';

  @override
  String get description => 'Record that the exported catalog is live.';

  @override
  Future<int> run() async {
    final root = argResults!.option('root');
    if (root == null || !isSha256Hex(root)) {
      throw const UsageFailure('--root takes the SHA-256 export printed.');
    }
    await backend().exported(
      rootSha: root,
      startedMs: intOption('since'),
      full: argResults!.flag('full'),
    );
    output.line('Recorded.');
    return 0;
  }
}

/// The backend's commands.
List<JustCommand> backendCommands() => [
  RunCommand(),
  SubmitCommand(),
  ModerateCommand(),
  ExportCommand(),
  ExportedCommand(),
];

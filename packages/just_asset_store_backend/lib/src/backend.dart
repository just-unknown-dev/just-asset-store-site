/// The store's records, and the only code that writes them.
library;

import 'dart:convert';
import 'dart:math';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_core_cli/fetch.dart' show GitHubRepo;

import 'config.dart';
import 'documents.dart';
import 'github.dart';
import 'identity.dart';
import 'pub_dev.dart';
import 'records.dart';
import 'release_check.dart';
import 'thumbnails.dart';

export 'config.dart';

/// What a submission, a release, a report or a moderation came to.
final class Outcome {
  /// [ok] with [message], about item [id].
  const Outcome(
    this.ok,
    this.message, {
    this.id,
    this.retry = false,
    this.held = false,
  });

  /// Whether it went through.
  final bool ok;

  /// What to tell the person (a submission's answer, an issue comment).
  final String message;

  /// The item it concerns.
  final String? id;

  /// Not decided: GitHub or the network failed, and it is tried again.
  final bool retry;

  /// Accepted, but waiting for a maintainer.
  final bool held;

  @override
  String toString() => message;
}

/// What [StoreBackend.run] did.
final class RunReport {
  /// [outcomes]; [deploy] when the catalog should be exported and deployed.
  const RunReport(this.outcomes, {required this.deploy});

  /// What each submission, report and release came to.
  final List<Outcome> outcomes;

  /// Whether the catalog changed since it was last deployed (or is due its
  /// daily full export).
  final bool deploy;
}

/// What [StoreBackend.export] made.
final class ExportResult {
  /// [index], from an export that started at [startedMs].
  const ExportResult(
    this.index, {
    required this.startedMs,
    required this.full,
    this.pictures = const {},
    this.skipped = const [],
  });

  /// The catalog.
  final StoreIndex index;

  /// When the export started: what changes after it goes in the next one.
  final int startedMs;

  /// Whether every record was read (rather than what changed).
  final bool full;

  /// The sources of the pictures this export rebuilt (card pictures in
  /// `thumbs/`, gallery pictures in `previews/`), by the path the catalog
  /// names them at.
  final Map<String, ThumbSource> pictures;

  /// Records that could not be made into catalog items, and why.
  final List<String> skipped;
}

/// The store backend: the only thing that writes the store's records. The
/// website only files `submissions` and `reports`, which [run] answers.
///
/// It reads little, to stay within Firestore's free daily reads: one
/// document per watched-repository shard and the state each run, the
/// submissions and reports waiting, and an item only when something
/// happens to it. The export reads what changed since the last one.
final class StoreBackend {
  /// The backend over [store], asking [github], set up by [config].
  StoreBackend({
    required this.store,
    required this.github,
    required this.config,
    required PubDevApi pubDev,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       check = ReleaseCheck(github: github, config: config, pubDev: pubDev);

  /// The records.
  final DocumentStore store;

  /// GitHub.
  final GitHubApi github;

  /// The settings.
  final BackendConfig config;

  /// How releases are checked.
  final ReleaseCheck check;

  final DateTime Function() _clock;

  /// Set when the catalog changed during this run.
  bool _dirty = false;

  int get _nowMs => _clock().toUtc().millisecondsSinceEpoch;

  /// How many times a submission or a release is tried before it is given
  /// up: GitHub was down, say.
  static const int maxAttempts = 6;

  /// The most new releases of one repository checked in a run.
  static const int perRepo = 3;

  /// The most submissions of one person answered in a run.
  static const int perUser = 3;

  static const int _hour = 60 * 60 * 1000;
  static const int _day = 24 * _hour;

  /// One run: the website's waiting submissions, its reports, then every
  /// watched repository's new releases — at most [limit] submissions and
  /// [limit] releases. Each is handled on its own: a failure is answered on
  /// it, or tried again in a later run, and never stops the others.
  Future<RunReport> run({
    required IdentityLookup identities,
    int limit = 50,
  }) async {
    final state = await StoreState.load(store);
    final shards = await RepoShards.load(store);
    final out = [
      ...await _submissions(identities, shards, limit),
      ...await _reports(),
      ...await _sweep(shards, limit),
    ];
    await shards.save(store);
    if (_dirty && !state.dirty) {
      state.dirty = true;
      await state.save(store);
    }
    return RunReport(
      out,
      deploy: state.dirty || _nowMs - state.lastFullMs > _day,
    );
  }

  // ── Submissions ─────────────────────────────────────────────────────────

  /// The website's waiting submissions, oldest first, each answered on
  /// itself: its signer's GitHub account found through [identities] —
  /// never taken from the submission — then [submit]ted as that account.
  /// At most [perUser] per signer in a run; the rest wait for the next.
  ///
  /// A submission's fields, as the website writes them (and Firestore's
  /// rules allow): `uid`, `repo`, `note`, `status: pending`, `createdAt`.
  /// The answer adds `status` (`listed`, `held` or `refused`), `message`,
  /// `itemId`, `login` and `processedAt`; a try that failed, `attempts`.
  Future<List<Outcome>> _submissions(
    IdentityLookup identities,
    RepoShards shards,
    int limit,
  ) async {
    final pending = await store.query(
      'submissions',
      where: const [Filter.equal('status', 'pending')],
      orderBy: const [OrderBy('createdAt')],
      limit: limit,
    );
    final out = <Outcome>[];
    final perSigner = <String, int>{};
    for (final MapEntry(key: id, value: s) in pending.entries) {
      final uid = s['uid'];
      final repo = s['repo'];
      if (uid is! String || repo is! String) {
        await _answer(
          id,
          const Outcome(false, 'This is not a submission the store reads.'),
        );
        out.add(Outcome(false, '$id: not a submission.'));
        continue;
      }
      perSigner[uid] = (perSigner[uid] ?? 0) + 1;
      if (perSigner[uid]! > perUser) continue;
      Outcome o;
      String? login;
      try {
        final githubId = await identities.githubIdOf(uid);
        login = githubId == null ? null : await github.login(githubId);
        o = githubId == null || login == null
            ? const Outcome(
                false,
                'The store could not tell which GitHub account sent this. '
                'Sign in with GitHub and submit it again.',
              )
            : await _submit(repo, githubId, login, shards);
      } on Object catch (e) {
        o = Outcome(false, 'The store could not check it now ($e).', retry: true);
      }
      if (o.retry) {
        final attempts = (s['attempts'] is int ? s['attempts'] as int : 0) + 1;
        if (attempts < maxAttempts) {
          await store.update('submissions/$id', {'attempts': attempts});
          out.add(Outcome(false, '$repo: ${o.message}', retry: true));
          continue;
        }
        o = Outcome(
          false,
          '${o.message} The store gave up after $maxAttempts tries: submit '
          'it again later.',
        );
      }
      await _answer(id, o, login: login);
      out.add(Outcome(o.ok, '$repo: ${o.message}', id: o.id, held: o.held));
    }
    return out;
  }

  Future<void> _answer(String id, Outcome o, {String? login}) =>
      store.update('submissions/$id', {
        'status': o.held ? 'held' : (o.ok ? 'listed' : 'refused'),
        'message': o.message,
        'itemId': o.id,
        'login': login,
        'processedAt': _clock().toUtc().toIso8601String(),
      });

  /// The package in [repoUrl], submitted by the GitHub account numbered
  /// [submitterId] (called [login]): listed when its latest release passes
  /// every check of [ReleaseCheck.check], held when a maintainer should look
  /// first. A repository listed already is checked again (its publisher's
  /// "check now").
  Future<Outcome> submit({
    required String repoUrl,
    required int submitterId,
    required String login,
  }) async {
    final shards = await RepoShards.load(store);
    try {
      return await _submit(repoUrl, submitterId, login, shards);
    } finally {
      await shards.save(store);
      await _flagDirty();
    }
  }

  Future<Outcome> _submit(
    String repoUrl,
    int submitterId,
    String login,
    RepoShards shards,
  ) async {
    // Before asking GitHub anything: in the first version only the store's
    // own team publishes.
    if (!config.mayPublish(submitterId)) {
      return const Outcome(false, BackendConfig.closedMessage);
    }
    final parsed = GitHubRepo.tryParse(repoUrl);
    if (parsed == null) {
      return Outcome(false, '`$repoUrl` is not a GitHub repository.');
    }
    final repo = await github.repo(parsed);
    if (repo == null) {
      return Outcome(
        false,
        '$parsed was not found, or is private: the store lists public '
        'repositories.',
      );
    }
    final release = await github.release(repo.repo);
    if (release == null) {
      return Outcome(
        false,
        '${repo.repo} has no published release. Make one with the store\'s '
        'release workflow.',
      );
    }
    final watch = shards[repo.id];
    final existing = watch == null ? null : await _item(watch.item);
    if (existing != null && existing.claimant != submitterId) {
      return Outcome(
        false,
        '${repo.repo} is listed already, by another publisher.',
        id: existing.id,
      );
    }
    final publisher = await _publisher(submitterId, login);
    final verdict = await check.check(
      repo: repo,
      release: release,
      claim: (id: submitterId, login: login, trust: _trust(publisher)),
      existing: existing,
      otherIds: {
        for (final w in shards.all.values)
          if (w.claimant != submitterId) w.item,
      },
    );
    switch (verdict) {
      case Retry(:final message):
        return Outcome(false, message, retry: true);
      case Refused(:final message):
        return Outcome(false, message);
      case Accepted(same: true, :final version):
        watch?.sawRelease(release.id);
        if (watch != null) shards.changed(repo.id);
        return Outcome(
          true,
          '${existing?.id ?? repo.repo} $version is listed already.',
          id: existing?.id,
        );
      case final Accepted a:
        final id = '${a.item['id']}';
        final byId = existing ?? await _item(id);
        if (byId != null && byId.repoId != repo.id) {
          return Outcome(false, '`$id` is already the id of ${byId.repo}.', id: id);
        }
        if (byId != null && byId.claimant != submitterId) {
          return Outcome(false, '`$id` is listed by another publisher.', id: id);
        }
        if (byId != null && byId.status == ItemStatus.blocked) {
          return Outcome(false, '`$id` was taken down.', id: id);
        }
        final item =
            byId ??
            ItemRecord(
              id: id,
              repo: '${repo.repo}',
              repoId: repo.id,
              repoNode: repo.nodeId,
              ownerId: repo.ownerId,
              claimant: submitterId,
              status: ItemStatus.held,
              item: a.item,
              createdMs: _nowMs,
            );
        await _savePublisher(publisher);
        final held = await _take(item, a, ownerId: repo.ownerId);
        shards[repo.id] =
            (shards[repo.id] ??
                  RepoWatch(
                    node: repo.nodeId,
                    item: id,
                    claimant: submitterId,
                    repo: '${repo.repo}',
                  ))
              ..sawRelease(release.id);
        return held
            ? Outcome(
                true,
                '$id ${a.version} waits for a maintainer: ${a.holds.join(' ')}',
                id: id,
                held: true,
              )
            : Outcome(
                true,
                '${a.item['name']} ${a.version} is listed: '
                '${config.site}/items/$id',
                id: id,
              );
    }
  }

  /// Lists [a] on [item] — or, when it has holds, keeps it waiting for a
  /// maintainer (who is told in an issue); saves the item. Whether it was
  /// held. [ownerId] is who owns the repository now.
  Future<bool> _take(ItemRecord item, Accepted a, {required int ownerId}) async {
    item
      ..lastError = null
      ..attempts = 0
      ..nextTryMs = 0;
    if (a.holds.isNotEmpty) {
      item.pending = PendingVersion(
        version: a.version,
        record: a.record,
        item: a.item,
        reasons: a.holds,
        ownerId: ownerId,
      );
      await _saveItem(item, catalog: false);
      await _review(item, a);
      await _notice(
        item.claimant,
        '${item.id} ${a.version} waits for a maintainer: ${a.holds.join(' ')}',
      );
      return true;
    }
    item
      ..versions = {...item.versions, a.version: a.record}
      ..item = a.item
      ..pictures = a.pictures.isNotEmpty ? a.pictures : item.pictures
      ..ownerId = ownerId;
    if (item.pending?.version == a.version) item.pending = null;
    if (item.status == ItemStatus.held) item.status = ItemStatus.listed;
    await _saveItem(item);
    return false;
  }

  /// Opens an issue asking the maintainers to look at [a].
  Future<void> _review(ItemRecord item, Accepted a) async {
    try {
      await github.openIssue(
        config.backendRepo,
        title: 'Review: ${item.id} ${a.version}',
        body: [
          '${item.id} ${a.version}, from '
              '[${item.repo}](https://github.com/${item.repo}/releases), '
              'waits for a maintainer:',
          '',
          for (final r in a.holds) '- $r',
          '',
          'To list it, comment `/store approve ${item.id}`; to refuse it, '
              '`/store reject ${item.id}`.',
        ].join('\n'),
        labels: const ['review'],
      );
    } on Object {
      // It still waits; a maintainer finds it in the records.
    }
  }

  // ── Reports ─────────────────────────────────────────────────────────────

  /// The website's new reports (`reports/{id}`: `uid`, `itemId`, `reason`,
  /// `text`, `status: new`, `createdAt`), each made an issue in the
  /// backend's repository for the maintainers.
  Future<List<Outcome>> _reports() async {
    final reports = await store.query(
      'reports',
      where: const [Filter.equal('status', 'new')],
      orderBy: const [OrderBy('createdAt')],
      limit: 20,
    );
    final out = <Outcome>[];
    for (final MapEntry(key: id, value: r) in reports.entries) {
      final itemId = '${r['itemId']}';
      if (!StoreNames.isId(itemId)) {
        await store.update('reports/$id', {'status': 'ignored'});
        continue;
      }
      try {
        final number = await github.openIssue(
          config.backendRepo,
          title: 'Report: $itemId',
          body: reportBody(r, site: config.site),
          labels: const ['report'],
        );
        await store.update('reports/$id', {'status': 'filed', 'issue': number});
        out.add(Outcome(true, 'Report on $itemId: #$number', id: itemId));
      } on Object catch (e) {
        out.add(Outcome(false, 'Report $id: $e', retry: true));
      }
    }
    return out;
  }

  /// The reasons a report may give: the website offers these, and
  /// `firestore.rules` accepts only these.
  static const List<String> reportReasons = [
    'malware',
    'stolen',
    'broken',
    'inappropriate',
    'other',
  ];

  /// A report's issue text. The reporter's words are fenced, so nothing in
  /// them is read as markdown, a link or a mention.
  static String reportBody(Map<String, Object?> report, {required String site}) {
    final itemId = '${report['itemId']}';
    final given =
        RegExp('^[a-z-]+').firstMatch('${report['reason'] ?? ''}'.trim())?[0];
    final reason = reportReasons.contains(given) ? given! : 'other';
    var text = '${report['text'] ?? ''}';
    if (text.length > 2000) text = '${text.substring(0, 2000)}…';
    var run = 0;
    var longest = 0;
    for (final c in text.split('')) {
      run = c == '`' ? run + 1 : 0;
      longest = max(longest, run);
    }
    final fence = '`' * max(3, longest + 1);
    return [
      'Item: [$itemId]($site/items/$itemId)',
      'Reason: `$reason`',
      '',
      '${fence}text',
      text,
      fence,
      '',
      'To act on it, comment `/store block $itemId`, or '
          '`/store block:<version> $itemId` for one version.',
    ].join('\n');
  }

  // ── The sweep ───────────────────────────────────────────────────────────

  /// Every watched repository asked about in a few GraphQL queries; new
  /// releases checked, oldest first, at most [limit] in all.
  Future<List<Outcome>> _sweep(RepoShards shards, int limit) async {
    final watches = shards.all;
    if (watches.isEmpty) return const [];
    final ids = watches.keys.toList();
    final List<SweptRepo?> swept;
    try {
      swept = await github.sweep([for (final id in ids) watches[id]!.node]);
    } on Object catch (e) {
      return [Outcome(false, 'The sweep failed; it runs again: $e', retry: true)];
    }
    final out = <Outcome>[];
    var budget = limit;
    for (var i = 0; i < ids.length && budget > 0; i++) {
      final watch = watches[ids[i]]!;
      try {
        budget -= await _sweepRepo(ids[i], watch, swept[i], shards, out);
      } on Object catch (e) {
        out.add(Outcome(false, '${watch.item}: $e', id: watch.item, retry: true));
      }
    }
    return out;
  }

  /// One repository as the sweep found it ([now]: null when it is gone);
  /// how many releases were checked.
  Future<int> _sweepRepo(
    int repoId,
    RepoWatch watch,
    SweptRepo? now,
    RepoShards shards,
    List<Outcome> out,
  ) async {
    if (now == null || now.isPrivate || now.id != repoId) {
      if (watch.gone) return 0;
      final item = await _item(watch.item);
      watch.gone = true;
      shards.changed(repoId);
      if (item != null && item.status == ItemStatus.listed) {
        item.status = ItemStatus.unavailable;
        await _saveItem(item);
        out.add(
          Outcome(
            false,
            '${item.id} is unavailable: its repository is gone or private.',
            id: item.id,
          ),
        );
      }
      return 0;
    }
    final fresh = [
      for (final r in now.releases.reversed)
        if (!r.draft && !watch.knows(r.id)) r,
    ];
    final moved = watch.repo != '${now.repo}';
    if (fresh.isEmpty && !moved && !watch.gone) return 0;

    final item = await _item(watch.item);
    if (item == null) return 0;
    var changed = false;
    if (item.repo != '${now.repo}') {
      item.repo = '${now.repo}';
      changed = true;
    }
    if (item.status == ItemStatus.unavailable) {
      item.status = ItemStatus.listed;
      changed = true;
      out.add(Outcome(true, '${item.id} is back.', id: item.id));
    }
    watch
      ..repo = '${now.repo}'
      ..gone = false;
    shards.changed(repoId);
    if (item.status == ItemStatus.blocked) {
      for (final r in fresh) {
        watch.sawRelease(r.id);
      }
      if (changed) await _saveItem(item);
      return 0;
    }
    if (item.nextTryMs > _nowMs) {
      if (changed) await _saveItem(item);
      return 0;
    }

    var checked = 0;
    for (final r in fresh.take(perRepo)) {
      checked++;
      final ReleaseInfo? release;
      try {
        release = await github.release(now.repo, id: r.id);
      } on GitHubBusy catch (e) {
        await _retry(item, watch, r, e.message, out);
        return checked;
      }
      if (release == null) {
        watch.sawRelease(r.id);
        continue;
      }
      final publisher = await _publisher(item.claimant, null);
      final verdict = await check.check(
        repo: RepoInfo(
          repo: now.repo,
          id: now.id,
          nodeId: watch.node,
          ownerId: now.ownerId,
        ),
        release: release,
        claim: (
          id: item.claimant,
          login: publisher.login,
          trust: _trust(publisher),
        ),
        existing: item,
      );
      switch (verdict) {
        case Accepted(same: true):
          watch.sawRelease(r.id);
        case final Accepted a:
          final held = await _take(item, a, ownerId: now.ownerId);
          changed = false;
          watch.sawRelease(r.id);
          out.add(
            Outcome(
              true,
              held
                  ? '${item.id} ${a.version} waits for a maintainer.'
                  : '${item.id} ${a.version} is listed.',
              id: item.id,
              held: held,
            ),
          );
        case Refused(:final message):
          watch.refusedRelease(r.id, message);
          await _notice(item.claimant, '${item.id} ${r.tag}: $message');
          out.add(Outcome(false, '${item.id} ${r.tag}: $message', id: item.id));
        case Retry(:final message):
          await _retry(item, watch, r, message, out, changed: changed);
          return checked;
      }
    }
    if (changed) await _saveItem(item);
    return checked;
  }

  /// [item]'s release [r] could not be checked now, for [message]: tried
  /// again after a while, longer each time, until the store gives up on it.
  Future<void> _retry(
    ItemRecord item,
    RepoWatch watch,
    ({int id, String tag, bool draft}) r,
    String message,
    List<Outcome> out, {
    bool changed = false,
  }) async {
    item
      ..attempts += 1
      ..lastError = message;
    if (item.attempts >= maxAttempts) {
      watch.refusedRelease(
        r.id,
        'The store gave up after $maxAttempts tries: $message',
      );
      await _notice(
        item.claimant,
        '${item.id} ${r.tag}: the store could not check it ($message). '
        'Publish it again as a new version.',
      );
      item
        ..attempts = 0
        ..nextTryMs = 0;
    } else {
      item.nextTryMs = _nowMs + min(24, 1 << (item.attempts - 1)) * _hour;
    }
    await _saveItem(item, catalog: changed);
    out.add(
      Outcome(false, '${item.id} ${r.tag}: $message', id: item.id, retry: true),
    );
  }

  // ── Moderation ──────────────────────────────────────────────────────────

  /// A maintainer's [action] on item [id], by the GitHub account numbered
  /// [actorId] (it must be one of [BackendConfig.maintainerIds]):
  /// - `block`, `unblock`: the item (taken down items are named in the
  ///   catalog's `removed`, and projects that have them are warned);
  /// - `block:<version>`, `unblock:<version>`: one version, likewise;
  /// - `yank:<version>`, `unyank:<version>`: withdrawn from new installs;
  /// - `trust:<official|verified|community>`: its publisher;
  /// - `approve`, `reject`: the version waiting for review.
  Future<Outcome> moderate({
    required String id,
    required String action,
    required int actorId,
  }) async {
    if (!config.maintainerIds.contains(actorId)) {
      return Outcome(false, 'Only the store\'s maintainers may do that.', id: id);
    }
    final item = await _item(id);
    if (item == null) return Outcome(false, 'There is no item `$id`.');
    final (verb, arg) = switch (action.split(':')) {
      [final v] => (v, null),
      [final v, final a] when a.isNotEmpty => (v, a),
      _ => (action, ''),
    };
    final Outcome o;
    switch ((verb, arg)) {
      case ('block', null):
        item
          ..status = ItemStatus.blocked
          ..blockedReason = 'Taken down by the store\'s maintainers.';
        await _saveItem(item);
        o = Outcome(true, '$id is taken down.', id: id);
      case ('unblock', null):
        item
          ..status = item.versions.isEmpty ? ItemStatus.held : ItemStatus.listed
          ..blockedReason = null;
        await _saveItem(item);
        o = Outcome(true, '$id is back.', id: id);
      case ('block' || 'unblock' || 'yank' || 'unyank', final String v):
        final record = item.versions[v];
        if (record == null) {
          o = Outcome(false, '$id has no version $v.', id: id);
          break;
        }
        item.versions = {
          ...item.versions,
          v: verb == 'block' || verb == 'unblock'
              ? record.copyWith(blocked: verb == 'block')
              : record.copyWith(yanked: verb == 'yank'),
        };
        await _saveItem(item);
        o = Outcome(true, '$id $v: ${verb}ed.', id: id);
      case ('trust', final String level) when TrustLevel.byId.containsKey(level):
        final publisher = await _publisher(item.claimant, null)
          ..trust = level;
        await _savePublisher(publisher);
        // Every item of theirs carries the new trust in the next export.
        final theirs = await store.query(
          'items',
          where: [Filter.equal('claimant', item.claimant)],
        );
        for (final e in theirs.entries) {
          await _saveItem(ItemRecord.fromDoc(e.key, e.value));
        }
        o = Outcome(true, '@${publisher.login} is $level now.', id: id);
      case ('approve', _) when item.pending != null &&
          (arg == null || arg == item.pending!.version):
        final p = item.pending!;
        item
          ..versions = {...item.versions, p.version: p.record}
          ..item = p.item
          ..ownerId = p.ownerId ?? item.ownerId
          ..pending = null;
        if (item.status == ItemStatus.held) item.status = ItemStatus.listed;
        await _saveItem(item);
        await _notice(item.claimant, '$id ${p.version} is listed.');
        o = Outcome(true, '$id ${p.version} is listed.', id: id);
      case ('reject', _) when item.pending != null &&
          (arg == null || arg == item.pending!.version):
        final p = item.pending!;
        final shards = await RepoShards.load(store);
        shards[item.repoId]?.refusedRelease(
          p.record.releaseId,
          'Refused by the store\'s maintainers.',
        );
        shards.changed(item.repoId);
        await shards.save(store);
        item.pending = null;
        await _saveItem(item, catalog: false);
        await _notice(
          item.claimant,
          '$id ${p.version} was refused by the store\'s maintainers.',
        );
        o = Outcome(true, '$id ${p.version} is refused.', id: id);
      default:
        o = Outcome(false, '"$action" is not something to do with $id.', id: id);
    }
    await _flagDirty();
    return o;
  }

  // ── Export ──────────────────────────────────────────────────────────────

  /// The catalog. From [previous] (the deployed one) and the records that
  /// changed since it was made — or, when [full], there is no [previous],
  /// or the last full export is a day old, from every record.
  ///
  /// Items taken down are named in `removed`; items waiting for their first
  /// review, or with no version, are left out; a record that can't be made
  /// into an item is left out and named in [ExportResult.skipped].
  Future<ExportResult> export({StoreIndex? previous, bool full = false}) async {
    final startedMs = _nowMs;
    final state = await StoreState.load(store);
    final whole =
        full || previous == null || startedMs - state.lastFullMs > _day;
    final records = whole
        ? await store.list('items')
        : await store.query(
            'items',
            where: [Filter.greaterThan('updatedMs', state.exportedMs)],
          );
    final items = <String, StoreItem>{
      if (!whole) for (final i in previous.items) i.id: i,
    };
    final removed = <String, RemovedItem>{
      if (!whole) for (final r in previous.removed) r.id: r,
    };
    final pictures = <String, ThumbSource>{};
    final skipped = <String>[];
    final publishers = <int, PublisherRecord>{};
    final known = {for (final c in config.categories) c.id};
    for (final e in records.entries) {
      items.remove(e.key);
      removed.remove(e.key);
      try {
        final r = ItemRecord.fromDoc(e.key, e.value);
        switch (r.status) {
          case ItemStatus.blocked:
            removed[r.id] = RemovedItem(
              r.id,
              r.blockedReason ?? 'Taken down by the store.',
            );
          case ItemStatus.held:
            break;
          case ItemStatus.listed || ItemStatus.unavailable:
            if (r.versions.isEmpty) break;
            final p = publishers[r.claimant] ??= await _publisher(
              r.claimant,
              null,
            );
            final card = r.pictures.isEmpty
                ? null
                : Thumbnails.pathOf(r.pictures.first);
            final gallery = [
              for (final s in r.pictures) Thumbnails.galleryPathOf(s),
            ];
            final item = _catalogItem(r, p, card, gallery);
            if (!known.contains(item.category)) {
              skipped.add('${r.id}: "${item.category}" is not a category.');
              break;
            }
            items[r.id] = item;
            if (card != null) pictures[card] = r.pictures.first;
            for (var i = 0; i < gallery.length; i++) {
              pictures[gallery[i]] = r.pictures[i];
            }
        }
      } on Object catch (x) {
        skipped.add('${e.key}: $x');
      }
    }
    return ExportResult(
      StoreIndex.checked(
        source: config.source,
        categories: config.categories,
        items: items.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
        removed: removed.values.toList()..sort((a, b) => a.id.compareTo(b.id)),
        generatedAt: _clock().toUtc(),
        featured: [
          for (final id in config.featured)
            if (items.containsKey(id)) id,
        ],
      ),
      startedMs: startedMs,
      full: whole,
      pictures: pictures,
      skipped: skipped,
    );
  }

  StoreItem _catalogItem(
    ItemRecord r,
    PublisherRecord p,
    String? thumbnail,
    List<String> previews,
  ) {
    final versions = r.versions.entries.toList()
      ..sort(
        (a, b) => (Version.tryParse(a.key) ?? Version(0, 0, 0)).compareTo(
          Version.tryParse(b.key) ?? Version(0, 0, 0),
        ),
      );
    return StoreItem.fromJson(
      JsonFields({
        ...r.item,
        'trust': _trust(p).name,
        'publisher': p.login,
        'repoId': r.repoId,
        'sourceRepo': 'https://github.com/${r.repo}',
        'unavailable': r.status == ItemStatus.unavailable ? true : null,
        'thumbnail': thumbnail,
        'previews': previews,
        'versions': [
          for (final v in versions)
            {
              ...v.value.entry,
              if (v.value.yanked) 'yanked': true,
              if (v.value.blocked) 'blocked': true,
            },
        ],
      }),
    );
  }

  /// Records a deploy of the export that started at [startedMs], whose
  /// `index.json` has the SHA-256 [rootSha]: what changes after it goes in
  /// the next one.
  Future<void> exported({
    required String rootSha,
    required int startedMs,
    required bool full,
  }) async {
    final state = await StoreState.load(store);
    final later = await store.query(
      'items',
      where: [Filter.greaterThan('updatedMs', startedMs)],
      limit: 1,
    );
    state
      ..dirty = later.isNotEmpty
      ..exportedMs = startedMs
      ..rootSha = rootSha;
    if (full) state.lastFullMs = startedMs;
    await state.save(store);
  }

  // ── Records ─────────────────────────────────────────────────────────────

  Future<ItemRecord?> _item(String id) async {
    final doc = await store.get('items/$id');
    return doc == null ? null : ItemRecord.fromDoc(id, doc);
  }

  /// Saves [item]; [catalog] when the change shows in the catalog.
  Future<void> _saveItem(ItemRecord item, {bool catalog = true}) async {
    item.updatedMs = _nowMs;
    await store.set('items/${item.id}', item.toDoc());
    if (catalog) _dirty = true;
  }

  Future<void> _flagDirty() async {
    if (!_dirty) return;
    final state = await StoreState.load(store);
    if (state.dirty) return;
    state.dirty = true;
    await state.save(store);
  }

  /// The publisher numbered [id]: its record, or a new one (not saved yet)
  /// — official when the settings say so. [login], when given, is its
  /// login now.
  Future<PublisherRecord> _publisher(int id, String? login) async {
    final doc = await store.get('publishers/$id');
    final p = doc == null
        ? PublisherRecord(
            id: id,
            login: login ?? '$id',
            trust: config.officialPublishers.contains(id)
                ? 'official'
                : 'community',
          )
        : PublisherRecord.fromDoc(id, doc);
    if (login != null) p.login = login;
    return p;
  }

  Future<void> _savePublisher(PublisherRecord p) async {
    p.updatedMs = _nowMs;
    await store.set('publishers/${p.id}', p.toDoc());
  }

  /// How far the store vouches for [p]: the settings' official publishers
  /// always, else their record.
  TrustLevel _trust(PublisherRecord p) => config.officialPublishers.contains(p.id)
      ? TrustLevel.official
      : TrustLevel.byId[p.trust] ?? TrustLevel.community;

  /// Tells the publisher numbered [githubId] [text] on the website: the
  /// newest of their notices (`notices/{githubId}`), which only they can
  /// read.
  Future<void> _notice(int githubId, String text) async {
    final doc = await store.get('notices/$githubId');
    final messages = [
      ...(doc?['messages'] is String
          ? (jsonDecode(doc!['messages'] as String) as List)
          : const []),
      {'atMs': _nowMs, 'text': text},
    ];
    while (messages.length > 20) {
      messages.removeAt(0);
    }
    await store.set('notices/$githubId', {'messages': jsonEncode(messages)});
  }
}

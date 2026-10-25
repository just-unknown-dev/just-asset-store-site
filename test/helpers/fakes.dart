import 'dart:async';

import 'package:just_asset_store_pages/content.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';
import 'package:just_asset_store_site/core/github/repo_precheck.dart';
import 'package:just_asset_store_site/core/notices/notices.dart';
import 'package:just_asset_store_site/core/reports/reports.dart';
import 'package:just_asset_store_site/core/submissions/submissions.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

/// Sign-in that signs in as [as] when asked.
final class FakeAuth extends StoreAuth {
  FakeAuth({this.as, StoreUser? signedIn}) {
    user.value = signedIn;
    ready.value = true;
  }

  final StoreUser? as;
  int signIns = 0;

  @override
  bool get available => true;

  @override
  Future<void> signIn() async {
    signIns++;
    user.value = as;
  }

  @override
  Future<void> signOut() async => user.value = null;
}

/// Submissions in memory; [answer] plays the backend.
final class MemorySubmissionStore implements SubmissionStore {
  final List<(String uid, Submission s)> _all = [];
  final _changes = StreamController<void>.broadcast();
  var _next = 0;

  List<Submission> get all => [for (final e in _all) e.$2];

  @override
  Future<String> submit({
    required String uid,
    required String repo,
    String? note,
  }) async {
    final id = 's${_next++}';
    _all.add((
      uid,
      Submission(
        id: id,
        repo: repo,
        note: note,
        status: SubmissionStatus.pending,
        createdAt: DateTime.utc(2026, 10, 9, 12, _next),
      ),
    ));
    _changes.add(null);
    return id;
  }

  /// The backend's verdict on submission [id].
  void answer(
    String id,
    SubmissionStatus status,
    String message, {
    String? itemId,
  }) {
    final i = _all.indexWhere((e) => e.$2.id == id);
    final (uid, s) = _all[i];
    _all[i] = (
      uid,
      Submission(
        id: s.id,
        repo: s.repo,
        note: s.note,
        status: status,
        message: message,
        itemId: itemId,
        createdAt: s.createdAt,
      ),
    );
    _changes.add(null);
  }

  @override
  Stream<List<Submission>> watch(String uid) async* {
    List<Submission> mine() => [
      for (final e in _all.reversed)
        if (e.$1 == uid) e.$2,
    ];
    yield mine();
    await for (final _ in _changes.stream) {
      yield mine();
    }
  }
}

/// Reports in memory; [tooSoon] plays the rules' two-minute wait.
final class MemoryReportStore implements ReportStore {
  final List<(String uid, String itemId, ReportReason reason, String? text)>
  sent = [];
  bool tooSoon = false;

  @override
  Future<void> report({
    required String uid,
    required String itemId,
    required ReportReason reason,
    String? text,
  }) async {
    if (tooSoon) throw StateError(ReportCopy.tooSoon);
    sent.add((uid, itemId, reason, text));
  }
}

/// The store's notices, by GitHub id.
final class MemoryNoticeStore implements NoticeStore {
  MemoryNoticeStore([this.byId = const {}]);

  final Map<String, List<StoreNotice>> byId;

  @override
  Stream<List<StoreNotice>> watch(String githubId) =>
      Stream.value(byId[githubId] ?? const []);
}

/// A pre-check that answers [result] (all good by default).
final class FakePrecheck implements RepoPrecheck {
  FakePrecheck([this.result = const Precheck([CheckLine(CheckState.ok, 'Fine.')])]);

  Precheck result;
  final List<String> asked = [];

  @override
  Future<Precheck> check(String owner, String repo) async {
    asked.add('$owner/$repo');
    return result;
  }
}

/// Records what the app writes into `<head>`.
final class RecordingHead implements HeadService {
  final List<PageMeta> applied = [];

  PageMeta get last => applied.last;

  @override
  void apply(PageMeta meta) => applied.add(meta);
}

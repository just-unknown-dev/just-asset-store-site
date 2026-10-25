import 'dart:async';

import 'package:just_signals/just_signals.dart';

import '../auth/store_auth.dart';
import 'submission_rules.dart';

/// Where a submission is.
enum SubmissionStatus {
  /// Waiting for the store's next check.
  pending,

  /// Checked and listed.
  listed,

  /// Checked; waits for a maintainer's look before it is listed.
  held,

  /// Checked and refused; [Submission.message] says why.
  refused;

  static SubmissionStatus byId(Object? id) => switch (id) {
    'listed' => listed,
    'held' => held,
    'refused' => refused,
    _ => pending,
  };
}

/// A request to list a package: written by its creator, answered by the
/// backend.
final class Submission {
  const Submission({
    required this.id,
    required this.repo,
    required this.status,
    this.note,
    this.message,
    this.itemId,
    this.createdAt,
    this.processedAt,
  });

  final String id;
  final String repo;
  final SubmissionStatus status;
  final String? note;

  /// The backend's answer.
  final String? message;

  /// The item it listed.
  final String? itemId;
  final DateTime? createdAt;
  final DateTime? processedAt;
}

/// Where submissions are kept (Firestore's `submissions` collection).
abstract interface class SubmissionStore {
  /// Files a pending submission for [uid]; returns its id.
  Future<String> submit({
    required String uid,
    required String repo,
    String? note,
  });

  /// [uid]'s submissions, newest first, as they change.
  Stream<List<Submission>> watch(String uid);
}

/// Nowhere: sign-in isn't set up.
final class NoSubmissionStore implements SubmissionStore {
  const NoSubmissionStore();

  @override
  Future<String> submit({
    required String uid,
    required String repo,
    String? note,
  }) => Future.error(StateError('Submissions are not set up here.'));

  @override
  Stream<List<Submission>> watch(String uid) => Stream.value(const []);
}

/// The signed-in user's submissions, followed live, and the form's submit.
final class SubmissionsController {
  SubmissionsController(this.auth, this.store) {
    _effect = Effect(() {
      final u = auth.user.value;
      _follow(u?.uid);
      return null;
    }, debugLabel: 'submissions');
  }

  final StoreAuth auth;
  final SubmissionStore store;

  /// Theirs, newest first; null while signed out or loading.
  final Signal<List<Submission>?> mine = Signal<List<Submission>?>(
    null,
    debugLabel: 'mySubmissions',
  );

  /// Why following them failed.
  final Signal<String?> error = Signal<String?>(null, debugLabel: 'subsError');

  Effect? _effect;
  StreamSubscription<List<Submission>>? _sub;
  String? _uid;

  void _follow(String? uid) {
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    mine.value = null;
    error.value = null;
    if (uid == null) return;
    _sub = store.watch(uid).listen(
      (list) => mine.value = list,
      onError: (Object e) => error.value = 'Your submissions could not be read ($e).',
    );
  }

  /// Files [repo] (its category is the one its `just_store.json` names).
  /// Throws [ArgumentError] with the problem when the form is wrong,
  /// [StateError] when signed out.
  Future<String> submit({required String repo, String note = ''}) {
    final u = auth.user.value;
    if (u == null) throw StateError('Sign in first.');
    final normalized = SubmissionRules.normalizeRepo(repo);
    if (normalized == null) {
      throw ArgumentError(SubmissionRules.repoProblem(repo));
    }
    final text = note.trim();
    if (text.length > SubmissionRules.noteMax) {
      throw ArgumentError(
        'Keep the note under ${SubmissionRules.noteMax} characters.',
      );
    }
    return store.submit(
      uid: u.uid,
      repo: normalized,
      note: text.isEmpty ? null : text,
    );
  }

  void dispose() {
    _effect?.dispose();
    _sub?.cancel();
  }
}

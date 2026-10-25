import 'package:cloud_firestore/cloud_firestore.dart';

import 'submissions.dart';

/// [SubmissionStore] on Firestore's `submissions` collection.
///
/// `firestore.rules` lets a GitHub-signed-in user create a pending
/// submission in their own name — together with their tally,
/// `submitters/{uid}`, which holds them to one every ten minutes — and read
/// their own; the backend (a service account) answers them. [db] completes
/// once Firebase has started, with null when it isn't set up here.
final class FirestoreSubmissionStore implements SubmissionStore {
  FirestoreSubmissionStore(this._db);

  final Future<FirebaseFirestore?> _db;

  Future<FirebaseFirestore> get _ready async =>
      await _db ?? (throw StateError('Submissions are not set up here.'));

  @override
  Future<String> submit({
    required String uid,
    required String repo,
    String? note,
  }) async {
    final db = await _ready;
    final doc = db.collection('submissions').doc();
    final batch = db.batch()
      ..set(doc, {
        'uid': uid,
        'repo': repo,
        'note': ?note,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      })
      // The rules accept a submission only with this, written at the same
      // moment, at least ten minutes after the last.
      ..set(db.collection('submitters').doc(uid), {
        'lastAt': FieldValue.serverTimestamp(),
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw StateError(
          'The store takes one submission every ten minutes. Wait a little, '
          'then submit it again.',
        );
      }
      rethrow;
    }
    return doc.id;
  }

  @override
  Stream<List<Submission>> watch(String uid) async* {
    final db = await _db;
    if (db == null) {
      yield const [];
      return;
    }
    yield* db
        .collection('submissions')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = [for (final d in snap.docs) _read(d.id, d.data())];
          final epoch = DateTime.fromMillisecondsSinceEpoch(0);
          // Newest first; one still being written has no time yet.
          list.sort(
            (a, b) => (b.createdAt ?? DateTime.now()).compareTo(
              a.createdAt ?? epoch,
            ),
          );
          return list;
        });
  }

  static Submission _read(String id, Map<String, dynamic> d) => Submission(
    id: id,
    repo: '${d['repo'] ?? ''}',
    status: SubmissionStatus.byId(d['status']),
    note: d['note'] as String?,
    message: d['message'] as String?,
    itemId: d['itemId'] as String?,
    createdAt: _time(d['createdAt']),
    processedAt: _time(d['processedAt']),
  );

  static DateTime? _time(Object? v) => switch (v) {
    final Timestamp t => t.toDate(),
    final String s => DateTime.tryParse(s),
    _ => null,
  };
}

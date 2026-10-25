import 'package:cloud_firestore/cloud_firestore.dart';

import 'notices.dart';

/// [NoticeStore] on Firestore's `notices/{githubId}`, which the backend
/// writes and `firestore.rules` lets that GitHub account read.
final class FirestoreNoticeStore implements NoticeStore {
  FirestoreNoticeStore(this._db);

  final Future<FirebaseFirestore?> _db;

  @override
  Stream<List<StoreNotice>> watch(String githubId) async* {
    final db = await _db;
    if (db == null) {
      yield const [];
      return;
    }
    yield* db
        .collection('notices')
        .doc(githubId)
        .snapshots()
        .map((d) => StoreNotice.parse(d.data()?['messages']));
  }
}

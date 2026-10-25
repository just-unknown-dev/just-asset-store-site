import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:just_asset_store_pages/content.dart';

import 'reports.dart';

/// [ReportStore] on Firestore: a report, with its sender's tally
/// (`reporters/{uid}`), which `firestore.rules` holds to one every two
/// minutes. [db] completes once Firebase has started (null when it isn't
/// set up here).
final class FirestoreReportStore implements ReportStore {
  FirestoreReportStore(this._db);

  final Future<FirebaseFirestore?> _db;

  @override
  Future<void> report({
    required String uid,
    required String itemId,
    required ReportReason reason,
    String? text,
  }) async {
    final db = await _db;
    if (db == null) throw StateError('Reports are not set up here.');
    final batch = db.batch()
      ..set(db.collection('reports').doc(), {
        'uid': uid,
        'itemId': itemId,
        'reason': reason.id,
        'text': ?text,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(db.collection('reporters').doc(uid), {
        'lastAt': FieldValue.serverTimestamp(),
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw StateError(ReportCopy.tooSoon);
      rethrow;
    }
  }
}

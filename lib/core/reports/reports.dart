import 'package:just_asset_store_pages/content.dart';

import '../auth/store_auth.dart';

/// Where reports go (Firestore's `reports` collection); the backend turns
/// each into an issue for the maintainers.
abstract interface class ReportStore {
  /// Files [uid]'s report about [itemId].
  Future<void> report({
    required String uid,
    required String itemId,
    required ReportReason reason,
    String? text,
  });
}

/// Nowhere: sign-in isn't set up.
final class NoReportStore implements ReportStore {
  const NoReportStore();

  @override
  Future<void> report({
    required String uid,
    required String itemId,
    required ReportReason reason,
    String? text,
  }) => Future.error(StateError('Reports are not set up here.'));
}

/// The report form's send: checks it as `firestore.rules` will.
final class ReportsController {
  ReportsController(this.auth, this.store);

  final StoreAuth auth;
  final ReportStore store;

  static final RegExp _itemId = RegExp(r'^[a-z][a-z0-9_]{0,63}$');

  /// Whether [id] names an item the form can report.
  static bool isItemId(String? id) => id != null && _itemId.hasMatch(id);

  /// Reports [itemId] for [reason]. Throws [ArgumentError] when the form is
  /// wrong, [StateError] when signed out or too soon after the last.
  Future<void> send({
    required String itemId,
    required ReportReason reason,
    String text = '',
  }) {
    final u = auth.user.value;
    if (u == null) throw StateError('Sign in first.');
    if (!isItemId(itemId)) throw ArgumentError(ReportCopy.noItem);
    final details = text.trim();
    if (details.length > ReportCopy.detailsMax) {
      throw ArgumentError(
        'Keep it under ${ReportCopy.detailsMax} characters.',
      );
    }
    return store.report(
      uid: u.uid,
      itemId: itemId,
      reason: reason,
      text: details.isEmpty ? null : details,
    );
  }
}

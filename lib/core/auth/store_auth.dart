import 'package:just_asset_store/just_asset_store.dart' show claimCode;
import 'package:just_signals/just_signals.dart';

/// Someone signed in with GitHub.
final class StoreUser {
  const StoreUser({
    required this.uid,
    this.name,
    this.photoUrl,
    this.login,
    this.githubId,
  });

  /// Their Firebase user id: what their submissions are filed under.
  final String uid;
  final String? name;
  final String? photoUrl;

  /// Their GitHub login, when GitHub told us at sign-in. Only for show: the
  /// backend looks their GitHub account up itself.
  final String? login;

  /// Their GitHub account's number, which never changes (a login can).
  final String? githubId;

  /// What to call them.
  String get label => login != null ? '@$login' : (name ?? 'Signed in');

  /// The code that shows a repository is theirs: the one the store expects
  /// in a release's just_release.json. Null when GitHub didn't say who they
  /// are.
  String? get claim {
    final id = int.tryParse(githubId ?? '');
    return id == null || id < 1 ? null : claimCode(id);
  }
}

/// Sign-in with GitHub, identity only (no extra permissions).
abstract class StoreAuth {
  /// Who is signed in.
  final Signal<StoreUser?> user = Signal<StoreUser?>(null, debugLabel: 'user');

  /// Whether the first sign-in state is known.
  final Signal<bool> ready = Signal<bool>(false, debugLabel: 'authReady');

  /// The last sign-in failure, for the page to show.
  final Signal<String?> error = Signal<String?>(null, debugLabel: 'authError');

  /// Whether sign-in works here (Firebase is set up). Until [ready], it is
  /// assumed to.
  bool get available;

  Future<void> signIn();
  Future<void> signOut();
}

/// No sign-in: Firebase isn't configured, or a test doesn't need it.
final class UnavailableAuth extends StoreAuth {
  UnavailableAuth() {
    ready.value = true;
  }

  @override
  bool get available => false;

  @override
  Future<void> signIn() async {
    error.value = 'Sign-in is not set up on this copy of the store.';
  }

  @override
  Future<void> signOut() async {}
}

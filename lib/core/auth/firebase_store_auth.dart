import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_storage/just_storage.dart';

import 'store_auth.dart';

/// [StoreAuth] on Firebase Auth's GitHub provider.
///
/// It asks GitHub for nothing beyond the public profile: the backend checks
/// repository ownership with the claim code, never the user's token.
/// Firebase starts in the background ([auth] completes when it has, with
/// null when it isn't set up here), so the page draws first.
final class FirebaseStoreAuth extends StoreAuth {
  FirebaseStoreAuth(Future<FirebaseAuth?> auth, this._storage) : _auth = auth {
    auth.then((a) {
      if (a == null) {
        _available = false;
        ready.value = true;
        return;
      }
      _sub = a.authStateChanges().listen((u) async {
        user.value = u == null ? null : await _toUser(u);
        ready.value = true;
      });
    });
  }

  final Future<FirebaseAuth?> _auth;
  final JustStandardStorage _storage;
  StreamSubscription<User?>? _sub;
  bool _available = true;

  static String _loginKey(String uid) => 'github_login:$uid';

  @override
  bool get available => _available;

  @override
  Future<void> signIn() async {
    error.value = null;
    final auth = await _auth;
    if (auth == null) {
      error.value = 'Sign-in is not set up on this copy of the store.';
      return;
    }
    final provider = GithubAuthProvider();
    try {
      final cred = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);
      final u = cred.user;
      final login = cred.additionalUserInfo?.username;
      if (u != null && login != null) {
        await _storage.write(_loginKey(u.uid), login);
        user.value = await _toUser(u);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }
      error.value = switch (e.code) {
        'popup-blocked' =>
          'Your browser blocked the sign-in window. Allow pop-ups for this '
              'site and try again.',
        'account-exists-with-different-credential' =>
          'This email already signs in another way.',
        'operation-not-allowed' =>
          'GitHub sign-in is not turned on for the store yet.',
        'network-request-failed' =>
          'Sign-in couldn’t reach GitHub. Check your connection and try '
              'again.',
        _ => 'Sign-in failed: ${e.message ?? e.code}',
      };
    }
  }

  @override
  Future<void> signOut() async => (await _auth)?.signOut();

  Future<StoreUser> _toUser(User u) async {
    UserInfo? github;
    for (final p in u.providerData) {
      if (p.providerId == 'github.com') github = p;
    }
    return StoreUser(
      uid: u.uid,
      name: github?.displayName ?? u.displayName,
      photoUrl: github?.photoURL ?? u.photoURL,
      login: await _storage.read(_loginKey(u.uid)),
      // The provider's own id for the user: their GitHub account's number.
      githubId: github?.uid,
    );
  }

  void dispose() => _sub?.cancel();
}

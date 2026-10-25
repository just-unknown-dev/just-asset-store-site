/// Who signed a website submission: the GitHub account behind a Firebase
/// user, looked up with the backend's own credentials.
library;

import 'dart:convert';
import 'dart:io';

/// The GitHub account a Firebase user signed in with.
///
/// A submission names only its signer's Firebase uid (Firestore's rules make
/// sure of that); the GitHub account comes from here, never from anything
/// the browser wrote.
abstract interface class IdentityLookup {
  /// The numeric GitHub id [uid] signed in with, or null when [uid] isn't a
  /// GitHub sign-in (or no longer exists).
  Future<int?> githubIdOf(String uid);
}

/// [IdentityLookup] on Firebase Auth, through the Identity Toolkit REST API
/// (`accounts:lookup`). The access token is the workflow's service account,
/// which needs the *Firebase Authentication Viewer* role.
final class FirebaseIdentityLookup implements IdentityLookup {
  FirebaseIdentityLookup({
    required this.project,
    required this.accessToken,
    HttpClient Function()? client,
  }) : _client = client ?? HttpClient.new;

  final String project;
  final String accessToken;
  final HttpClient Function() _client;

  @override
  Future<int?> githubIdOf(String uid) async {
    final client = _client();
    try {
      final request = await client.postUrl(
        Uri.https(
          'identitytoolkit.googleapis.com',
          '/v1/projects/$project/accounts:lookup',
        ),
      );
      request.headers
        ..set('Authorization', 'Bearer $accessToken')
        ..contentType = ContentType.json;
      request.write(jsonEncode({
        'localId': [uid],
      }));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      if (response.statusCode != 200) {
        throw HttpException(
          'Firebase Auth answered ${response.statusCode} looking up a user.',
        );
      }
      return githubIdIn(jsonDecode(text));
    } finally {
      client.close(force: true);
    }
  }

  /// The GitHub id in an `accounts:lookup` answer, or null.
  static int? githubIdIn(Object? answer) {
    if (answer is! Map) return null;
    final users = answer['users'];
    if (users is! List || users.isEmpty || users.first is! Map) return null;
    final providers = (users.first as Map)['providerUserInfo'];
    if (providers is! List) return null;
    for (final p in providers) {
      if (p is Map && p['providerId'] == 'github.com') {
        return int.tryParse('${p['rawId']}');
      }
    }
    return null;
  }
}

/// Identities from a map, for tests and local runs (`--identities`).
final class MapIdentityLookup implements IdentityLookup {
  const MapIdentityLookup(this.ids);

  final Map<String, int> ids;

  @override
  Future<int?> githubIdOf(String uid) async => ids[uid];
}

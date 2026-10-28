/// Firestore through its REST API: what the backend runs on in GitHub
/// Actions, with a short-lived access token from workload identity.
library;

import 'dart:convert';
import 'dart:io';

import 'documents.dart';

/// A [DocumentStore] on Firestore's REST API.
///
/// The token is an OAuth access token for a service account allowed to
/// write the database — in GitHub Actions, `google-github-actions/auth`
/// with `token_format: access_token` makes one from the workflow's own
/// identity, so no key file is stored anywhere.
final class FirestoreDocumentStore implements DocumentStore {
  /// The `(default)` database of Firebase project [project], at [endpoint]
  /// (Firestore's own unless a test serves recorded answers).
  FirestoreDocumentStore({
    required this.project,
    required this.accessToken,
    this.quotaProject,
    Uri? endpoint,
    HttpClient Function()? client,
  }) : endpoint = endpoint ?? Uri.https('firestore.googleapis.com'),
       _client = client ?? HttpClient.new;

  /// The Firebase project id.
  final String project;

  /// The OAuth access token.
  final String accessToken;

  /// The project a person's own token bills its calls to
  /// (`x-goog-user-project`), when run by hand with `gcloud` credentials
  /// rather than a service account; null in the workflows.
  final String? quotaProject;

  /// Where Firestore's REST API is.
  final Uri endpoint;

  final HttpClient Function() _client;

  String get _root => '/v1/projects/$project/databases/(default)/documents';

  Uri _uri(String path, [Map<String, Object>? query]) =>
      endpoint.replace(path: path, queryParameters: query);

  @override
  Future<Map<String, Object?>?> get(String path) async {
    final (status, body) = await _send('GET', _uri('$_root/$path'));
    if (status == 404) return null;
    _ok(status, body, 'read $path');
    return _fieldsOf(_object(body));
  }

  @override
  Future<void> set(String path, Map<String, Object?> data) async {
    final (status, body) = await _send('PATCH', _uri('$_root/$path'), {
      'fields': {for (final e in data.entries) e.key: _value(e.value)},
    });
    _ok(status, body, 'write $path');
  }

  @override
  Future<void> update(String path, Map<String, Object?> fields) async {
    final (status, body) = await _send(
      'PATCH',
      _uri('$_root/$path', {
        'updateMask.fieldPaths': fields.keys.toList(),
        'currentDocument.exists': 'true',
      }),
      {
        'fields': {for (final e in fields.entries) e.key: _value(e.value)},
      },
    );
    _ok(status, body, 'update $path');
  }

  @override
  Future<Map<String, Map<String, Object?>>> list(String collection) async {
    final out = <String, Map<String, Object?>>{};
    String? page;
    do {
      final (status, raw) = await _send(
        'GET',
        _uri('$_root/$collection', {'pageSize': '300', 'pageToken': ?page}),
      );
      _ok(status, raw, 'list $collection');
      final body = _object(raw);
      for (final d in (body['documents'] as List? ?? const [])) {
        final doc = (d as Map).cast<String, Object?>();
        out['${doc['name']}'.split('/').last] = _fieldsOf(doc);
      }
      page = body['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  @override
  Future<Map<String, Map<String, Object?>>> query(
    String collection, {
    List<Filter> where = const [],
    List<OrderBy> orderBy = const [],
    int? limit,
  }) async {
    final parts = collection.split('/');
    final parent = parts.length == 1
        ? _root
        : '$_root/${parts.sublist(0, parts.length - 1).join('/')}';
    final filters = [
      for (final f in where)
        {
          'fieldFilter': {
            'field': {'fieldPath': f.field},
            'op': _ops[f.op],
            'value': _value(f.value),
          },
        },
    ];
    final (status, raw) = await _send('POST', _uri('$parent:runQuery'), {
      'structuredQuery': {
        'from': [
          {'collectionId': parts.last},
        ],
        if (filters.length == 1) 'where': filters.single,
        if (filters.length > 1)
          'where': {
            'compositeFilter': {'op': 'AND', 'filters': filters},
          },
        if (orderBy.isNotEmpty)
          'orderBy': [
            for (final o in orderBy)
              {
                'field': {'fieldPath': o.field},
                'direction': o.descending ? 'DESCENDING' : 'ASCENDING',
              },
          ],
        'limit': ?limit,
      },
    });
    _ok(status, raw, 'query $collection');
    return {
      // One entry per match; with no match, a single entry without one.
      for (final r in raw is List ? raw : const [])
        if ((r as Map<String, Object?>)['document']
            case final Map<String, Object?> d)
          '${d['name']}'.split('/').last: _fieldsOf(d),
    };
  }

  static const Map<FilterOp, String> _ops = {
    FilterOp.equal: 'EQUAL',
    FilterOp.lessThan: 'LESS_THAN',
    FilterOp.lessThanOrEqual: 'LESS_THAN_OR_EQUAL',
    FilterOp.greaterThan: 'GREATER_THAN',
    FilterOp.greaterThanOrEqual: 'GREATER_THAN_OR_EQUAL',
  };

  @override
  Future<void> delete(String path) async {
    final (status, body) = await _send('DELETE', _uri('$_root/$path'));
    if (status != 404) _ok(status, body, 'delete $path');
  }

  Future<(int, Object?)> _send(String method, Uri uri, [Object? body]) async {
    final client = _client();
    try {
      final request = await client.openUrl(method, uri);
      request.headers.set('Authorization', 'Bearer $accessToken');
      if (quotaProject case final quota?) {
        request.headers.set('x-goog-user-project', quota);
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      return (response.statusCode, text.isEmpty ? null : jsonDecode(text));
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, Object?> _object(Object? body) =>
      body is Map ? body.cast<String, Object?>() : const <String, Object?>{};

  static void _ok(int status, Object? body, String what) {
    if (status >= 200 && status < 300) return;
    final error = _object(body)['error'];
    final message = error is Map ? '${error['message']}' : '';
    throw HttpException(
      status == 429
          ? 'Firestore refused to $what: the free plan\'s daily quota is '
                'used up (it resets at midnight Pacific time). $message'
          : 'Firestore could not $what: $status $message',
    );
  }

  static Map<String, Object?> _value(Object? v) => switch (v) {
    null => {'nullValue': null},
    final bool b => {'booleanValue': b},
    final int i => {'integerValue': '$i'},
    final String s => {'stringValue': s},
    _ => throw ArgumentError.value(v, 'value', 'Only flat values are stored'),
  };

  static Map<String, Object?> _fieldsOf(Map<String, Object?> doc) {
    final fields = (doc['fields'] as Map?)?.cast<String, Object?>() ?? {};
    return {
      for (final e in fields.entries)
        e.key: switch ((e.value as Map).cast<String, Object?>()) {
          {'stringValue': final String s} => s,
          {'integerValue': final String i} => int.parse(i),
          {'booleanValue': final bool b} => b,
          // The website's server timestamps; read as ISO-8601 text.
          {'timestampValue': final String t} => t,
          _ => null,
        },
    };
  }
}

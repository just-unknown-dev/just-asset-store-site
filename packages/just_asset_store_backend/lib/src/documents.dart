/// Where the backend keeps the store's records: Firestore, or memory for
/// tests and dry runs.
library;

import 'dart:convert';
import 'dart:io';

/// How a [Filter] compares a field with its value.
enum FilterOp {
  /// Equal to.
  equal,

  /// Less than.
  lessThan,

  /// Less than or equal to.
  lessThanOrEqual,

  /// Greater than.
  greaterThan,

  /// Greater than or equal to.
  greaterThanOrEqual,
}

/// A condition on one field, for [DocumentStore.query].
final class Filter {
  /// [field] compared by [op] with [value].
  const Filter(this.field, this.op, this.value);

  /// [field] equal to [value].
  const Filter.equal(this.field, this.value) : op = FilterOp.equal;

  /// [field] greater than [value].
  const Filter.greaterThan(this.field, this.value) : op = FilterOp.greaterThan;

  /// The field.
  final String field;

  /// How it compares.
  final FilterOp op;

  /// What it compares with: a string, an int or a bool.
  final Object value;

  /// Whether a document whose [field] holds [actual] passes. A document
  /// without the field passes nothing, as in Firestore.
  bool matches(Object? actual) {
    if (actual == null) return false;
    if (op == FilterOp.equal) return actual == value;
    final c = compareValues(actual, value);
    if (c == null) return false;
    return switch (op) {
      FilterOp.lessThan => c < 0,
      FilterOp.lessThanOrEqual => c <= 0,
      FilterOp.greaterThan => c > 0,
      FilterOp.greaterThanOrEqual => c >= 0,
      FilterOp.equal => c == 0,
    };
  }
}

/// How [DocumentStore.query] orders what it finds.
final class OrderBy {
  /// By [field], smallest first unless [descending].
  const OrderBy(this.field, {this.descending = false});

  /// The field.
  final String field;

  /// Largest first.
  final bool descending;
}

/// [a] against [b] when both are numbers or both strings; null otherwise.
int? compareValues(Object? a, Object? b) => switch ((a, b)) {
  (final num x, final num y) => x.compareTo(y),
  (final String x, final String y) => x.compareTo(y),
  _ => null,
};

/// A document database of flat records: string, int, bool or null fields
/// (nested data is stored as JSON text), in collections addressed by path —
/// `items/just_art_knight`, `meta/state`.
abstract interface class DocumentStore {
  /// The document at [path], or null.
  Future<Map<String, Object?>?> get(String path);

  /// Writes [data] as the whole document at [path].
  Future<void> set(String path, Map<String, Object?> data);

  /// Merges [fields] into the existing document at [path], leaving its
  /// other fields (a timestamp the website wrote, say) as they are.
  Future<void> update(String path, Map<String, Object?> fields);

  /// The documents of [collection], by id.
  Future<Map<String, Map<String, Object?>>> list(String collection);

  /// The documents of [collection] that pass every filter in [where], in
  /// [orderBy]'s order, at most [limit] of them, by id. A document without
  /// a field the order names is left out, as in Firestore.
  Future<Map<String, Map<String, Object?>>> query(
    String collection, {
    List<Filter> where = const [],
    List<OrderBy> orderBy = const [],
    int? limit,
  });

  /// Removes the document at [path].
  Future<void> delete(String path);
}

/// A [DocumentStore] in memory, saved to a JSON file when given one: for
/// tests, and to try the backend locally (`--memory store.json`).
final class MemoryDocumentStore implements DocumentStore {
  /// A store starting from [file]'s contents, when it exists.
  MemoryDocumentStore({this.file}) {
    final f = file;
    if (f != null && f.existsSync()) {
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      json.forEach((k, v) => docs[k] = (v as Map).cast<String, Object?>());
    }
  }

  /// Where it saves, if anywhere.
  final File? file;

  /// Every document, by path.
  final Map<String, Map<String, Object?>> docs = {};

  /// How many documents each call read, as Firestore would bill them: one
  /// per document returned, and one for a read that found nothing.
  int reads = 0;

  /// How many documents were written or deleted.
  int writes = 0;

  @override
  Future<Map<String, Object?>?> get(String path) async {
    reads++;
    return docs[path] == null ? null : {...docs[path]!};
  }

  @override
  Future<void> set(String path, Map<String, Object?> data) async {
    writes++;
    docs[path] = {...data};
    _save();
  }

  @override
  Future<void> update(String path, Map<String, Object?> fields) async {
    final doc = docs[path];
    if (doc == null) throw StateError('There is no document $path.');
    writes++;
    docs[path] = {...doc, ...fields};
    _save();
  }

  Map<String, Map<String, Object?>> _in(String collection) {
    final depth = collection.split('/').length + 1;
    return {
      for (final e in docs.entries)
        if (e.key.startsWith('$collection/') &&
            e.key.split('/').length == depth)
          e.key.split('/').last: {...e.value},
    };
  }

  @override
  Future<Map<String, Map<String, Object?>>> list(String collection) async {
    final out = _in(collection);
    reads += out.isEmpty ? 1 : out.length;
    return out;
  }

  @override
  Future<Map<String, Map<String, Object?>>> query(
    String collection, {
    List<Filter> where = const [],
    List<OrderBy> orderBy = const [],
    int? limit,
  }) async {
    var found = _in(collection).entries.where(
      (e) =>
          where.every((f) => f.matches(e.value[f.field])) &&
          orderBy.every((o) => e.value[o.field] != null),
    ).toList();
    found.sort((a, b) {
      for (final o in orderBy) {
        final c = compareValues(a.value[o.field], b.value[o.field]) ?? 0;
        if (c != 0) return o.descending ? -c : c;
      }
      return a.key.compareTo(b.key);
    });
    if (limit != null && found.length > limit) {
      found = found.sublist(0, limit);
    }
    reads += found.isEmpty ? 1 : found.length;
    return {for (final e in found) e.key: e.value};
  }

  @override
  Future<void> delete(String path) async {
    writes++;
    docs.remove(path);
    _save();
  }

  void _save() {
    final f = file;
    if (f == null) return;
    final sorted = Map.fromEntries(
      docs.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    f.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(sorted)}\n');
  }
}

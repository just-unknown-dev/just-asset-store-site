/// What the backend asks pub.dev: whether a name is taken there, and what
/// a package's versions depend on.
library;

import 'dart:convert';
import 'dart:io';

import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_core_cli/fetch.dart';

/// One version of a package on pub.dev, and its pubspec.
typedef PubVersion = ({Version version, Map<Object?, Object?> pubspec});

/// pub.dev could not answer now: ask again on a later run.
final class PubDevBusy implements Exception {
  /// Why.
  const PubDevBusy(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// pub.dev, as the backend reads it.
abstract interface class PubDevApi {
  /// Every version of [package] on pub.dev that isn't retracted, or null
  /// when pub.dev has no package of that name. Throws [PubDevBusy] when
  /// pub.dev can't answer now.
  Future<List<PubVersion>?> versions(String package);
}

/// The real [PubDevApi], at [api] (pub.dev's own unless a test serves
/// recorded answers). Each package is asked about once.
final class HttpPubDevApi implements PubDevApi {
  /// pub.dev at [api].
  HttpPubDevApi({Uri? api, HttpClient Function()? client})
    : api = api ?? Uri.https('pub.dev'),
      _fetcher = HttpFetcher(userAgent: _userAgent, client: client);

  static const String _userAgent = 'just_asset_store_backend/0.2.0';

  /// Where pub.dev is.
  final Uri api;

  final HttpFetcher _fetcher;
  final Map<String, Future<List<PubVersion>?>> _asked = {};

  @override
  Future<List<PubVersion>?> versions(String package) =>
      _asked[package] ??= _versions(package);

  Future<List<PubVersion>?> _versions(String package) async {
    if (!StoreNames.isId(package)) return null;
    final FetchResponse response;
    try {
      response = await _fetcher.get(
        api.replace(path: '/api/packages/$package'),
        headers: {'Accept': 'application/vnd.pub.v2+json'},
        maxBytes: 32 << 20,
      );
    } on FetchException catch (e) {
      if (e.statusCode == 404) return null;
      throw PubDevBusy('pub.dev: ${e.message}');
    }
    return parse(utf8.decode(response.body, allowMalformed: true));
  }

  /// The versions in pub.dev's answer [text] about one package.
  static List<PubVersion> parse(String text) {
    final json = jsonDecode(text);
    final out = <PubVersion>[];
    if (json is! Map || json['versions'] is! List) return out;
    for (final v in json['versions'] as List) {
      if (v is! Map || v['retracted'] == true) continue;
      final version = Version.tryParse('${v['version']}');
      final pubspec = v['pubspec'];
      if (version == null || pubspec is! Map) continue;
      out.add((version: version, pubspec: pubspec));
    }
    return out..sort((a, b) => a.version.compareTo(b.version));
  }
}

/// The native code packages from pub.dev bring: Flutter plugins and
/// packages with build hooks ([NativeScan.isNativePubspec]), found by
/// following each package's newest allowed version's dependencies, as pub
/// would most likely resolve them. What the project has anyway — what the
/// item requires, and the store items it needs — isn't counted.
abstract final class PubNativeScan {
  /// The most packages one walk reads.
  static const int maxPackages = 300;

  /// What [dependencies] bring but [provided] don't: the packages with
  /// native code, and whether every package could be read (not, past
  /// [maxPackages] in either walk). Throws [PubDevBusy].
  static Future<({List<String> native, bool complete})> of(
    PubDevApi pub,
    Map<String, VersionConstraint> dependencies, {
    Map<String, VersionConstraint> provided = const {},
  }) async {
    final have = await _walk(pub, provided);
    final mine = await _walk(pub, {
      for (final e in dependencies.entries)
        if (!provided.containsKey(e.key)) e.key: e.value,
    });
    return (
      native: [
        for (final e in mine.found.entries)
          if (e.value && !have.found.containsKey(e.key)) e.key,
      ]..sort(),
      complete: have.complete && mine.complete,
    );
  }

  /// Every package [roots] reach, and whether each has native code.
  static Future<({Map<String, bool> found, bool complete})> _walk(
    PubDevApi pub,
    Map<String, VersionConstraint> roots,
  ) async {
    final found = <String, bool>{};
    final queue = [for (final e in roots.entries) (e.key, e.value)];
    while (queue.isNotEmpty) {
      final (name, constraint) = queue.removeLast();
      if (ReservedNames.sdk.contains(name) || found.containsKey(name)) {
        continue;
      }
      if (found.length >= maxPackages) return (found: found, complete: false);
      final versions = await pub.versions(name);
      // No such package: pub would fail to resolve it, so nothing runs.
      final pick = versions == null ? null : _best(versions, constraint);
      found[name] = pick != null && NativeScan.isNativePubspec(name, pick.pubspec);
      final deps = pick?.pubspec['dependencies'];
      if (deps is! Map) continue;
      for (final e in deps.entries) {
        final c = _hosted(e.value);
        if (c != null) queue.add(('${e.key}', c));
      }
    }
    return (found: found, complete: true);
  }

  /// The newest release [constraint] allows, else its newest pre-release.
  static PubVersion? _best(List<PubVersion> versions, VersionConstraint c) {
    PubVersion? release;
    PubVersion? pre;
    for (final v in versions) {
      if (!c.allows(v.version)) continue;
      if (v.version.isPreRelease) {
        pre = v;
      } else {
        release = v;
      }
    }
    return release ?? pre;
  }

  /// The constraint of a dependency pub fetches from pub.dev, or null for
  /// an SDK's (or one no published package can have).
  static VersionConstraint? _hosted(Object? spec) {
    if (spec == null) return VersionConstraint.any;
    if (spec is String) return VersionConstraint.tryParse(spec);
    if (spec is Map && !spec.containsKey('sdk')) {
      final v = spec['version'];
      return v == null
          ? VersionConstraint.any
          : VersionConstraint.tryParse('$v');
    }
    return null;
  }
}

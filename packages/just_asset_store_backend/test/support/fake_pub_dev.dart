// pub.dev in memory: packages, their versions' pubspecs, and an outage.
import 'package:just_asset_store/just_asset_store.dart';
import 'package:just_asset_store_backend/just_asset_store_backend.dart';

/// A [PubDevApi] answering from [packages].
final class FakePubDev implements PubDevApi {
  /// Each package's pubspec at 1.0.0, by name.
  final Map<String, Map<Object?, Object?>> packages = {};

  /// Set to make every question fail, as when pub.dev is down.
  bool down = false;

  /// The names asked about.
  final List<String> asked = [];

  /// Adds [name] 1.0.0, depending on [dependencies] (any version), a Flutter
  /// plugin when [plugin].
  void add(
    String name, {
    List<String> dependencies = const [],
    bool plugin = false,
  }) => packages[name] = {
    'name': name,
    'version': '1.0.0',
    'dependencies': {for (final d in dependencies) d: '^1.0.0'},
    if (plugin)
      'flutter': {
        'plugin': {
          'platforms': {
            'android': {'package': 'x'},
          },
        },
      },
  };

  @override
  Future<List<PubVersion>?> versions(String package) async {
    asked.add(package);
    if (down) throw const PubDevBusy('pub.dev: The server answered 503.');
    final pubspec = packages[package];
    return pubspec == null
        ? null
        : [(version: Version(1, 0, 0), pubspec: pubspec)];
  }
}

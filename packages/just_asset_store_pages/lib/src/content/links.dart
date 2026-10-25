import 'routes.dart';

/// Where the store links to.
abstract final class StoreLinks {
  static const String justUnknown = 'https://justunknown.com';
  static const String engine = 'https://justunknown.com/engine';
  static const String engineDocs = 'https://engine.justunknown.com/';
  static const String githubOrg = 'https://github.com/just-unknown-dev';

  /// The store's core and its tools: public, unlike the website's own
  /// repository.
  static const String storeRepo =
      'https://github.com/just-unknown-dev/just-asset-store';

  /// The package template a creator starts from, in the core's repository.
  static const String itemTemplate = '$storeRepo/tree/main/templates/item';

  /// How to turn on immutable releases, which the store requires.
  static const String immutableReleases =
      'https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/immutable-releases';

  /// The `just` command-line tool on pub.dev.
  static const String justCli = 'https://pub.dev/packages/just_core_cli';

  /// The command that installs [justCli].
  static const String justCliInstall =
      'dart pub global activate just_core_cli';

  static const String email = 'contact@justunknown.com';
  static const String mailto = 'mailto:$email';

  /// A report about [id]: the website's report form (signed in with
  /// GitHub), which the store's maintainers get as an issue.
  static String report(String id) => Uri(
    path: StoreRoutes.reportPath,
    queryParameters: {'item': id},
  ).toString();

  /// [package] on pub.dev.
  static String pub(String package) => 'https://pub.dev/packages/$package';
}

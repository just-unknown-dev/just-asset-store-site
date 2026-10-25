// The store backend, as the workflows run it:
//
//     dart run bin/backend.dart process
//     dart run bin/backend.dart refresh
//     dart run bin/backend.dart moderate --id x --action block --actor me
//     dart run bin/backend.dart export --out build/catalog
//     dart run bin/backend.dart submit --repo <url> --category c --submitter me
//
// Add --memory store.json to any of them to try it without Firestore
// (and --identities ids.json to process).

import 'dart:io';

import 'package:just_asset_store_backend/just_asset_store_backend.dart';
import 'package:just_core_cli/just_core_cli.dart';

Future<void> main(List<String> arguments) async {
  final context = JustContext(invokedAs: 'backend');
  exitCode = await JustRunner(
    context,
    executableName: 'dart run bin/backend.dart',
    description: "The Just Asset Store's backend.",
    commands: backendCommands(),
  ).run(arguments);
}

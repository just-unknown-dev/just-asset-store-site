import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:just_storage/just_storage.dart';

import '../core/auth/firebase_store_auth.dart';
import '../core/di/app_config.dart';
import '../core/notices/firestore_notices.dart';
import '../core/reports/firestore_reports.dart';
import '../core/submissions/firestore_submissions.dart';
import '../firebase_options.dart';

SemanticsHandle? _semantics;

/// Firebase, started in the background: the page draws while its scripts
/// load. Null when it isn't set up here (or it failed to start).
Future<FirebaseApp?> startFirebase() async {
  try {
    return await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on Object catch (e) {
    debugPrint('Firebase is not available: $e');
    return null;
  }
}

/// One-time app setup: path URLs, the accessibility tree, and the app's
/// services on a Firebase that is still starting.
Future<void> bootstrap() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // Always publish a semantics tree so screen readers get real text, links
  // and headings.
  _semantics ??= SemanticsBinding.instance.ensureSemantics();

  final storage = await JustStorage.standard();
  final firebase = startFirebase();
  final db = firebase.then(
    (app) => app == null ? null : FirebaseFirestore.instanceFor(app: app),
  );
  await setupDependencies(
    storage: storage,
    auth: FirebaseStoreAuth(
      firebase.then(
        (app) => app == null ? null : FirebaseAuth.instanceFor(app: app),
      ),
      storage,
    ),
    submissions: FirestoreSubmissionStore(db),
    reports: FirestoreReportStore(db),
    notices: FirestoreNoticeStore(db),
  );
}

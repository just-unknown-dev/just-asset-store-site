import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_asset_store_site/app/app.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';
import 'package:just_asset_store_site/core/di/app_config.dart';
import 'package:just_asset_store_site/core/github/repo_precheck.dart';
import 'package:just_asset_store_site/core/notices/notices.dart';
import 'package:just_asset_store_site/core/reports/reports.dart';
import 'package:just_asset_store_site/core/submissions/submissions.dart';

import 'fakes.dart';
import 'in_memory_storage.dart';

/// What [pumpApp] wired in, for the test to look at.
final class TestApp {
  TestApp(this.head, this.auth, this.submissions);

  final RecordingHead head;
  final StoreAuth auth;
  final SubmissionStore submissions;
}

const Size desktop = Size(1440, 1000);
const Size phone = Size(390, 860);

/// Wires test doubles into just_di and pumps the real app at
/// [initialLocation].
Future<TestApp> pumpApp(
  WidgetTester tester, {
  String initialLocation = '/publish',
  Size size = desktop,
  StoreAuth? auth,
  SubmissionStore? submissions,
  ReportStore? reports,
  NoticeStore? notices,
  RepoPrecheck? precheck,
}) async {
  await resetDependencies();
  final head = RecordingHead();
  final signIn = auth ?? UnavailableAuth();
  final store = submissions ?? MemorySubmissionStore();
  await setupDependencies(
    storage: InMemoryStorage(),
    head: head,
    auth: signIn,
    submissions: store,
    reports: reports ?? MemoryReportStore(),
    notices: notices ?? MemoryNoticeStore(),
    precheck: precheck ?? FakePrecheck(),
  );
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(StoreApp(initialLocation: initialLocation));
  await tester.pumpAndSettle();
  return TestApp(head, signIn, store);
}

/// Scrolls [finder] to the middle of the view (clear of the floating top
/// nav), then taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder.first), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

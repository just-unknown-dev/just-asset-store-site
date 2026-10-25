import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

const _me = StoreUser(uid: 'u1', login: 'octocat', githubId: '583231');

void main() {
  testWidgets('a report names the item, a reason and what happened', (
    tester,
  ) async {
    final reports = MemoryReportStore();
    await pumpApp(
      tester,
      initialLocation: '/report?item=their_kit',
      auth: FakeAuth(signedIn: _me),
      reports: reports,
    );
    expect(find.text('Report a package'), findsWidgets);
    expect(find.textContaining('Reporting their_kit', findRichText: true), findsOneWidget);
    final send = find.widgetWithText(FilledButton, 'Send the report');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);

    await tapVisible(tester, find.text(ReportReason.malware.label));
    await tester.enterText(
      find.widgetWithText(TextField, ReportCopy.detailsLabel),
      'It downloads a program at start.',
    );
    await tapVisible(tester, send);
    expect(reports.sent.single, (
      'u1',
      'their_kit',
      ReportReason.malware,
      'It downloads a program at start.',
    ));
    expect(find.text(ReportCopy.sent), findsOneWidget);
  });

  testWidgets('too soon after the last one: why, and nothing sent', (
    tester,
  ) async {
    final reports = MemoryReportStore()..tooSoon = true;
    await pumpApp(
      tester,
      initialLocation: '/report?item=their_kit',
      auth: FakeAuth(signedIn: _me),
      reports: reports,
    );
    await tapVisible(tester, find.text(ReportReason.broken.label));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Send the report'));
    expect(reports.sent, isEmpty);
    expect(find.text(ReportCopy.tooSoon), findsOneWidget);
  });

  testWidgets('without an item, the form says where to start', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/report',
      auth: FakeAuth(signedIn: _me),
    );
    expect(find.text(ReportCopy.noItem), findsOneWidget);
    expect(find.text('Send the report'), findsNothing);
  });

  testWidgets('signed out, it asks to sign in first', (tester) async {
    await pumpApp(
      tester,
      initialLocation: '/report?item=their_kit',
      auth: FakeAuth(as: _me),
    );
    expect(find.text(ReportCopy.signInBody), findsOneWidget);
    expect(find.text('Back to the package'), findsOneWidget);
  });
}

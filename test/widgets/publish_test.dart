import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_asset_store/just_asset_store.dart' show claimCode;
import 'package:just_asset_store_pages/content.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';
import 'package:just_asset_store_site/core/github/repo_precheck.dart';
import 'package:just_asset_store_site/core/submissions/submissions.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

/// The store's own account, the only one that publishes in the first
/// version.
const _me = StoreUser(
  uid: 'u1',
  name: 'Just Unknown',
  login: 'just-unknown-dev',
  githubId: '262105023',
);

/// Anyone else.
const _them = StoreUser(uid: 'u2', login: 'octocat', githubId: '583231');

void main() {
  testWidgets('signed out: the steps, then a GitHub sign-in and the claim code', (
    tester,
  ) async {
    final auth = FakeAuth(as: _me);
    await pumpApp(tester, auth: auth);
    expect(find.text('Make a package'), findsOneWidget);
    expect(find.text('Turn on immutable releases'), findsOneWidget);
    expect(find.text('just store validate .'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget); // the top nav, on desktop
    await tapVisible(tester, find.text('Sign in with GitHub'));
    expect(auth.signIns, 1);
    expect(find.text('Signed in as @just-unknown-dev.'), findsOneWidget);
    expect(find.text(claimCode(262105023)), findsOneWidget);
    expect(find.text('Submit for review'), findsOneWidget);
  });

  testWidgets('anyone else is told publishing isn\'t open yet', (tester) async {
    final store = MemorySubmissionStore();
    await pumpApp(tester, auth: FakeAuth(signedIn: _them), submissions: store);
    expect(find.text(PublishCopy.closedBody), findsOneWidget);
    expect(find.text('Submit for review'), findsNothing);
    expect(find.text(PublishCopy.claimTitle), findsNothing);
    await tester.tap(find.byTooltip('@octocat'));
    await tester.pumpAndSettle();
    expect(find.text('Publish a package'), findsNothing);
  }, skip: StoreAccess.openPublishing);

  testWidgets('without Firebase, the form says sign-in is not set up', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.textContaining('isn’t set up'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('submitting asks GitHub first, then files a pending request', (
    tester,
  ) async {
    final store = MemorySubmissionStore();
    final precheck = FakePrecheck();
    await pumpApp(
      tester,
      auth: FakeAuth(signedIn: _me),
      submissions: store,
      precheck: precheck,
    );
    final submit = find.widgetWithText(FilledButton, 'Submit for review');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Repository'),
      'github.com/octocat/knight',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tapVisible(tester, find.byType(Checkbox));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tapVisible(tester, submit);
    expect(precheck.asked, ['octocat/knight']);
    expect(store.all.single.repo, 'https://github.com/octocat/knight');
    expect(store.all.single.status, SubmissionStatus.pending);
    expect(find.text('Waiting for the next check'), findsOneWidget);
    expect(find.textContaining('Submitted.'), findsOneWidget);

    store.answer(
      store.all.single.id,
      SubmissionStatus.refused,
      'octocat/knight has no release with a just_release.json.',
    );
    await tester.pumpAndSettle();
    expect(find.text('Refused'), findsOneWidget);
    expect(
      find.textContaining('no release with a just_release.json'),
      findsOneWidget,
    );
  });

  testWidgets('what the store would refuse stops the form, with why', (
    tester,
  ) async {
    final store = MemorySubmissionStore();
    await pumpApp(
      tester,
      auth: FakeAuth(signedIn: _me),
      submissions: store,
      precheck: FakePrecheck(
        const Precheck([
          CheckLine(CheckState.ok, 'octocat/knight is public.'),
          CheckLine(CheckState.fail, 'v1.0.0 isn’t an immutable release.'),
        ]),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Repository'),
      'https://github.com/octocat/knight',
    );
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Submit for review'));
    expect(store.all, isEmpty);
    expect(find.text('v1.0.0 isn’t an immutable release.'), findsOneWidget);
    expect(find.textContaining('would refuse it'), findsOneWidget);
  });

  testWidgets('GitHub not answering doesn\'t stop the form', (tester) async {
    final store = MemorySubmissionStore();
    await pumpApp(
      tester,
      auth: FakeAuth(signedIn: _me),
      submissions: store,
      precheck: FakePrecheck(
        const Precheck([
          CheckLine(CheckState.unknown, 'GitHub couldn’t be asked now.'),
        ]),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Repository'),
      'https://github.com/octocat/knight',
    );
    await tapVisible(tester, find.byType(Checkbox));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Submit for review'));
    expect(store.all, hasLength(1));
  });

  testWidgets('a bad address is flagged as it is typed', (tester) async {
    await pumpApp(tester, auth: FakeAuth(signedIn: _me));
    await tester.enterText(
      find.widgetWithText(TextField, 'Repository'),
      'https://gitlab.com/me/x',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('https://github.com/owner/name'),
      findsOneWidget,
    );
  });

  testWidgets('signing out from the account menu returns to signed out', (
    tester,
  ) async {
    await pumpApp(tester, auth: FakeAuth(signedIn: _me));
    await tester.tap(find.byTooltip('@just-unknown-dev'));
    await tester.pumpAndSettle();
    // The menu's entry, over the page's own "Sign out".
    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}

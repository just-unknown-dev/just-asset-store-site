import 'package:flutter_test/flutter_test.dart';
import 'package:just_asset_store/just_asset_store.dart' show claimCode;
import 'package:just_asset_store_pages/content.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';
import 'package:just_asset_store_site/core/notices/notices.dart';
import 'package:just_asset_store_site/core/submissions/submissions.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

const _me = StoreUser(
  uid: 'u1',
  name: 'Just Unknown',
  login: 'just-unknown-dev',
  githubId: '262105023',
);

void main() {
  testWidgets('My packages: claim code, notices, what was listed, submissions', (
    tester,
  ) async {
    final store = MemorySubmissionStore();
    final id = await store.submit(
      uid: _me.uid,
      repo: 'https://github.com/just-unknown-dev/just-ui-editor',
    );
    store.answer(
      id,
      SubmissionStatus.listed,
      'Interface 0.1.0 is listed.',
      itemId: 'just_ui_editor',
    );
    await store.submit(uid: 'someone-else', repo: 'https://github.com/x/y');

    await pumpApp(
      tester,
      initialLocation: '/me',
      auth: FakeAuth(signedIn: _me),
      submissions: store,
      notices: MemoryNoticeStore({
        '262105023': StoreNotice.parse(
          '[{"atMs": 1760000000000, "text": "knight v1.0.0: not immutable."},'
          ' {"atMs": 1760100000000, "text": "knight 1.1.0 waits for a maintainer."}]',
        ),
        '999': [StoreNotice(DateTime.utc(2026), 'Not yours.')],
      }),
    );
    expect(find.text(claimCode(262105023)), findsOneWidget);
    expect(find.text(MineCopy.noticesTitle), findsOneWidget);
    final newer = find.textContaining('waits for a maintainer');
    final older = find.textContaining('not immutable');
    expect(newer, findsOneWidget);
    expect(older, findsOneWidget);
    expect(
      tester.getTopLeft(newer).dy,
      lessThan(tester.getTopLeft(older).dy),
      reason: 'newest first',
    );
    expect(find.textContaining('Not yours'), findsNothing);
    expect(find.text('Listed'), findsWidgets);
    expect(find.text('just_ui_editor'), findsOneWidget);
    expect(find.text('Interface 0.1.0 is listed.'), findsOneWidget);
    expect(find.textContaining('x/y'), findsNothing);
  });

  testWidgets('anyone else: no claim code while publishing is closed', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: '/me',
      auth: FakeAuth(
        signedIn: const StoreUser(uid: 'u2', login: 'octocat', githubId: '583231'),
      ),
    );
    expect(find.text(PublishCopy.closedBody), findsOneWidget);
    expect(find.text(claimCode(583231)), findsNothing);
  }, skip: StoreAccess.openPublishing);

  testWidgets('no notices: says so', (tester) async {
    await pumpApp(tester, initialLocation: '/me', auth: FakeAuth(signedIn: _me));
    expect(find.text(MineCopy.noNotices), findsOneWidget);
  });

  test('notices the backend wrote, read back; anything else, none', () {
    final list = StoreNotice.parse(
      '[{"atMs": 1, "text": "a"}, {"atMs": "x"}, {"atMs": 2, "text": "b"}]',
    );
    expect([for (final n in list) n.text], ['b', 'a']);
    expect(StoreNotice.parse('not json'), isEmpty);
    expect(StoreNotice.parse(null), isEmpty);
  });
}

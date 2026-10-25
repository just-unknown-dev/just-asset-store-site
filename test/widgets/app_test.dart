import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_asset_store_site/core/auth/store_auth.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('each page writes its own head', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/me');
    expect(app.head.last.title, StoreRoutes.mine.title);
    expect(app.head.last.noindex, isTrue);
  });

  testWidgets('anything but its three pages is not found', (tester) async {
    await pumpApp(tester, initialLocation: '/items/x');
    expect(find.text('Page not found'), findsOneWidget);
  });

  testWidgets('links to the static pages load them; its own stay in the app', (
    tester,
  ) async {
    await pumpApp(tester);
    final context = tester.element(find.byType(Scaffold).first);
    expect(AppRoutes.routes(context, '/me'), isTrue);
    expect(AppRoutes.routes(context, '/report?item=x'), isTrue);
    expect(AppRoutes.routes(context, '/'), isFalse);
    expect(AppRoutes.routes(context, '/items/their_kit'), isFalse);
    expect(AppRoutes.routes(context, '/policy'), isFalse);
  });

  testWidgets('on a phone, the drawer has the account entries', (tester) async {
    await pumpApp(
      tester,
      size: phone,
      auth: FakeAuth(
        signedIn: const StoreUser(
          uid: 'u1',
          login: 'just-unknown-dev',
          githubId: '262105023',
        ),
      ),
    );
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('My packages'), findsWidgets);
  });
}

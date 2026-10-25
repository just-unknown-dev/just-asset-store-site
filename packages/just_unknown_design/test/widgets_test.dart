import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import 'helpers/in_memory_storage.dart';

const _chrome = SiteChrome(
  name: 'Test Store',
  tagline: 'Things for games.',
  nav: [SiteLink('Browse', '/'), SiteLink('Publish', '/publish')],
  iconLinks: [
    SiteLink('GitHub', 'https://github.com/x', glyph: LinkGlyph.github),
  ],
  footer: [
    FooterColumn('Store', [SiteLink('Policy', '/policy')]),
  ],
  copyright: '© {year} Test.',
);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final theme = ThemeController(InMemoryStorage());
  Widget page(String text) => Column(
    children: [
      PageHero(
        eyebrow: 'Eyebrow',
        title: text,
        lede: 'Lede',
        actions: const [SiteLink('Go', '/publish', primary: true)],
      ),
      SectionBlock(
        title: 'Cards',
        content: ResponsiveGrid(
          children: const [
            FeatureCard(title: 'One', body: 'First', badge: 'New'),
            FeatureCard(title: 'Two', body: 'Second', icon: Icons.star),
          ],
        ),
      ),
      const ContentColumn(child: CodeCard('just add thing')),
    ],
  );
  final router = GoRouter(
    routes: [
      ShellRoute(
        builder: (context, state, child) => SiteScaffold(
          chrome: _chrome,
          theme: theme,
          location: state.uri.path,
          actions: const [Icon(Icons.person, key: Key('action'))],
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (_, _) => page('Home page')),
          GoRoute(path: '/publish', builder: (_, _) => page('Publish page')),
          GoRoute(path: '/policy', builder: (_, _) => page('Policy page')),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    SignalBuilderHost(theme: theme, router: router),
  );
  await tester.pumpAndSettle();
}

/// The app shell a site builds: the themes, switched by the controller.
class SignalBuilderHost extends StatelessWidget {
  const SignalBuilderHost({super.key, required this.theme, required this.router});

  final ThemeController theme;
  final GoRouter router;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: theme.mode,
    builder: (context, mode, _) => MaterialApp.router(
      themeMode: mode,
      theme: JuTheme.light(),
      darkTheme: JuTheme.dark(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('desktop: nav links, icon links, actions and the footer', (
    tester,
  ) async {
    await _pump(tester, const Size(1440, 1000));
    expect(find.text('Home page'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.byTooltip('GitHub'), findsOneWidget);
    expect(find.byKey(const Key('action')), findsOneWidget);
    expect(find.byTooltip('Menu'), findsNothing);
    expect(find.text('© ${DateTime.now().year} Test.'), findsOneWidget);
    expect(find.text('just add thing'), findsOneWidget);

    await tester.tap(find.text('Publish').first);
    await tester.pumpAndSettle();
    expect(find.text('Publish page'), findsOneWidget);
  });

  testWidgets('mobile: the menu opens the drawer and navigates', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 900));
    expect(find.byTooltip('Menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.byType(NavDrawer), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Publish'));
    await tester.pumpAndSettle();
    expect(find.text('Publish page'), findsOneWidget);
    expect(find.byType(NavDrawer), findsNothing);
  });

  testWidgets('the theme switch flips the app to light', (tester) async {
    await _pump(tester, const Size(1440, 1000));
    final before = Theme.of(tester.element(find.text('Home page')));
    expect(before.brightness, Brightness.dark);
    await tester.tap(find.byTooltip('Switch to light theme'));
    await tester.pumpAndSettle();
    final after = Theme.of(tester.element(find.text('Home page')));
    expect(after.brightness, Brightness.light);
  });
}

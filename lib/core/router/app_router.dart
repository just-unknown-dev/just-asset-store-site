import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_asset_store_pages/content.dart';

import '../../app/store_scaffold.dart';
import '../../features/mine/my_packages_page.dart';
import '../../features/not_found/not_found_page.dart';
import '../../features/publish/publish_page.dart';
import '../../features/report/report_page.dart';
import 'route_state.dart';

/// The publish app's router: Publish, a report, and My packages
/// ([StoreRoutes.appPaths]). Every other page of the site is a static page,
/// which links load in full. Mirrors the location into
/// [RouteState.location].
GoRouter createRouter(
  RouteState routeState, {
  String initialLocation = StoreRoutes.publishPath,
}) {
  Page<void> page(GoRouterState state, Widget child) =>
      NoTransitionPage<void>(key: state.pageKey, child: child);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => StoreScaffold(child: child),
        routes: [
          GoRoute(
            path: StoreRoutes.publishPath,
            pageBuilder: (context, state) => page(state, const PublishPage()),
          ),
          GoRoute(
            path: StoreRoutes.reportPath,
            pageBuilder: (context, state) => page(
              state,
              ReportPage(
                key: ValueKey('report-${state.uri.queryParameters['item']}'),
                itemId: state.uri.queryParameters['item'],
              ),
            ),
          ),
          GoRoute(
            path: StoreRoutes.minePath,
            pageBuilder: (context, state) =>
                page(state, const MyPackagesPage()),
          ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) => NoTransitionPage<void>(
      key: state.pageKey,
      child: StoreScaffold(child: NotFoundPage(path: state.uri.path)),
    ),
  );

  void sync() {
    final matches = router.routerDelegate.currentConfiguration;
    routeState.location.value = matches.isEmpty
        ? StoreRoutes.normalize(router.routeInformationProvider.value.uri.path)
        : StoreRoutes.normalize(matches.uri.path);
  }

  routeState.location.value = StoreRoutes.normalize(initialLocation);
  router.routerDelegate.addListener(sync);
  return router;
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../core/di/app_config.dart';
import '../core/router/app_router.dart';
import '../core/router/route_state.dart';

class StoreApp extends StatefulWidget {
  const StoreApp({super.key, this.initialLocation = StoreRoutes.publishPath});

  final String initialLocation;

  @override
  State<StoreApp> createState() => _StoreAppState();
}

class _StoreAppState extends State<StoreApp> {
  late final GoRouter _router = createRouter(
    getIt<RouteState>(),
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = getIt<ThemeController>();
    return SignalBuilder<ThemeMode>(
      signal: theme.mode,
      builder: (context, mode, _) => MaterialApp.router(
        title: StoreMeta.name,
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: JuTheme.light(),
        darkTheme: JuTheme.dark(),
        routerConfig: _router,
        // The app draws three pages; a link to any other loads that page.
        builder: (context, child) =>
            AppRoutes(owns: StoreRoutes.isAppPath, child: child!),
      ),
    );
  }
}

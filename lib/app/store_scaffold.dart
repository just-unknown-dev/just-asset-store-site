import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../core/auth/store_auth.dart';
import '../core/di/app_config.dart';
import '../core/router/route_state.dart';
import '../features/shared/avatar.dart';

/// The store's chrome around every page: the shared [SiteScaffold] plus the
/// account button.
class StoreScaffold extends StatelessWidget {
  const StoreScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = getIt<RouteState>();
    final auth = getIt<StoreAuth>();
    return SignalBuilder<String>(
      signal: route.location,
      builder: (context, location, _) => SiteScaffold(
        chrome: StoreMeta.chrome,
        theme: getIt<ThemeController>(),
        location: location,
        actions: [if (auth.available) AccountButton(auth: auth)],
        drawerActions: [if (auth.available) AccountTiles(auth: auth)],
        child: child,
      ),
    );
  }
}

/// Sign in, or the signed-in user's menu.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key, required this.auth});

  final StoreAuth auth;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder2<bool, StoreUser?>(
      signal1: auth.ready,
      signal2: auth.user,
      builder: (context, ready, user, _) {
        if (!ready) return const SizedBox(width: 40);
        if (user == null && !context.isDesktop) {
          // Room for the wordmark on phones and tablets.
          return IconButton(
            tooltip: 'Sign in',
            onPressed: auth.signIn,
            icon: const Icon(Icons.login_rounded),
          );
        }
        if (user == null) {
          return Padding(
            padding: const EdgeInsets.only(left: JuSpacing.x2),
            child: OutlinedButton.icon(
              onPressed: auth.signIn,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Sign in'),
            ),
          );
        }
        return PopupMenuButton<String>(
          tooltip: user.label,
          position: PopupMenuPosition.under,
          onSelected: (v) {
            if (v == 'out') {
              auth.signOut();
            } else {
              context.go(v);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(user.label, style: context.text.labelLarge),
            ),
            const PopupMenuDivider(),
            if (StoreAccess.mayPublish(user.githubId)) ...[
              const PopupMenuItem<String>(
                value: StoreRoutes.minePath,
                child: Text('My packages'),
              ),
              const PopupMenuItem<String>(
                value: StoreRoutes.publishPath,
                child: Text('Publish a package'),
              ),
            ],
            const PopupMenuItem<String>(value: 'out', child: Text('Sign out')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: JuSpacing.x2),
            child: UserAvatar(user: user),
          ),
        );
      },
    );
  }
}

/// The account entries in the narrow-screen drawer.
class AccountTiles extends StatelessWidget {
  const AccountTiles({super.key, required this.auth});

  final StoreAuth auth;

  @override
  Widget build(BuildContext context) {
    void go(String path) {
      Navigator.of(context).pop();
      context.go(path);
    }

    return SignalBuilder<StoreUser?>(
      signal: auth.user,
      builder: (context, user, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: user == null
            ? [
                ListTile(
                  leading: const Icon(Icons.login_rounded),
                  title: const Text('Sign in with GitHub'),
                  onTap: () {
                    Navigator.of(context).pop();
                    auth.signIn();
                  },
                ),
              ]
            : [
                ListTile(
                  leading: UserAvatar(user: user, size: 24),
                  title: Text(user.label),
                ),
                if (StoreAccess.mayPublish(user.githubId))
                  ListTile(
                    leading: const Icon(Icons.inventory_2_rounded),
                    title: const Text('My packages'),
                    onTap: () => go(StoreRoutes.minePath),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Sign out'),
                  onTap: () {
                    Navigator.of(context).pop();
                    auth.signOut();
                  },
                ),
              ],
      ),
    );
  }
}

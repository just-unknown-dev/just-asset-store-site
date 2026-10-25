import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../theme/tokens.dart';
import 'app_link.dart';
import 'brand_mark.dart';

/// The narrow-screen menu: [chrome]'s navigation ([active] highlighted),
/// [actions], then its icon links.
class NavDrawer extends StatelessWidget {
  const NavDrawer({
    super.key,
    required this.chrome,
    this.active,
    this.actions = const [],
  });

  final SiteChrome chrome;
  final SiteLink? active;

  /// Extra entries under the navigation (a sign-in tile, say).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    void go(String href) {
      Navigator.of(context).pop();
      followHref(context, href);
    }

    return Drawer(
      width: 300,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(JuSpacing.x4),
          children: [
            Row(
              children: [
                Flexible(child: BrandMark(chrome: chrome)),
                const Spacer(),
                IconButton(
                  tooltip: 'Close menu',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: JuSpacing.x4),
            for (final l in chrome.nav)
              l.isExternal
                  ? _ExternalTile(l)
                  : ListTile(
                      selected: identical(l, active),
                      selectedColor: context.colors.primary,
                      leading: glyphIcon(l.glyph) == null
                          ? null
                          : Icon(glyphIcon(l.glyph)),
                      title: Text(l.label),
                      onTap: () => go(l.href),
                    ),
            if (actions.isNotEmpty) ...[
              const Divider(height: JuSpacing.x8),
              ...actions,
            ],
            if (chrome.iconLinks.isNotEmpty) ...[
              const Divider(height: JuSpacing.x8),
              for (final l in chrome.iconLinks) _ExternalTile(l),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExternalTile extends StatelessWidget {
  const _ExternalTile(this.link);

  final SiteLink link;

  @override
  Widget build(BuildContext context) {
    return AppLink(
      href: link.href,
      builder: (context, follow) => ListTile(
        leading: glyphIcon(link.glyph) == null
            ? null
            : Icon(glyphIcon(link.glyph)),
        title: Text(link.label),
        trailing: const Icon(Icons.north_east_rounded, size: 16),
        onTap: follow,
      ),
    );
  }
}

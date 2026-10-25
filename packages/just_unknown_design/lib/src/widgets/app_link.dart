import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_unknown_site/just_unknown_site.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/tokens.dart';

/// The icon for [glyph], or null for none.
IconData? glyphIcon(LinkGlyph glyph) => switch (glyph) {
  LinkGlyph.none => null,
  LinkGlyph.home => Icons.home_rounded,
  LinkGlyph.github => Icons.code_rounded,
  LinkGlyph.docs => Icons.menu_book_rounded,
  LinkGlyph.mail => Icons.mail_rounded,
  LinkGlyph.external => Icons.north_east_rounded,
};

/// Which of the site's paths the app routes itself. A site whose app is
/// one part of it — static pages around a Flutter app, say — puts this
/// above its pages: a link to any other path on the site loads that page,
/// as a plain link would. Without one, the app routes every path.
class AppRoutes extends InheritedWidget {
  /// The app owns the paths [owns] says yes to.
  const AppRoutes({super.key, required this.owns, required super.child});

  /// Whether the app routes [path] (without its query).
  final bool Function(String path) owns;

  /// Whether the app around [context] routes [href].
  static bool routes(BuildContext context, String href) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppRoutes>();
    return scope == null || scope.owns(href.split('?').first.split('#').first);
  }

  @override
  bool updateShouldNotify(AppRoutes oldWidget) => oldWidget.owns != owns;
}

/// Goes to [href] as the site's links do: through go_router when the app
/// routes it ([AppRoutes]); otherwise the page loads in this tab, or an
/// outside one opens in a new tab.
void followHref(BuildContext context, String href) {
  if (isExternalHref(href)) {
    launchUrl(Uri.parse(href), webOnlyWindowName: '_blank');
  } else if (AppRoutes.routes(context, href)) {
    context.go(href);
  } else {
    launchUrl(Uri.parse(href), webOnlyWindowName: '_self');
  }
}

/// Routes the app's own hrefs through go_router, and other pages and
/// outside sites through a real anchor (url_launcher `Link`), so
/// middle-click / right-click work on web.
class AppLink extends StatelessWidget {
  const AppLink({super.key, required this.href, required this.builder});

  final String href;
  final Widget Function(BuildContext context, VoidCallback? follow) builder;

  @override
  Widget build(BuildContext context) {
    if (isExternalHref(href)) {
      return Link(
        uri: Uri.parse(href),
        target: LinkTarget.blank,
        builder: (context, follow) => builder(context, follow),
      );
    }
    if (!AppRoutes.routes(context, href)) {
      return Link(
        uri: Uri.parse(href),
        target: LinkTarget.self,
        builder: (context, follow) => builder(context, follow),
      );
    }
    return builder(context, () => context.go(href));
  }
}

/// A [SiteLink] as a filled (primary) or outlined button.
class LinkButton extends StatelessWidget {
  const LinkButton(this.link, {super.key, this.compact = false});

  final SiteLink link;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = Text(link.label);
    final icon = link.isExternal
        ? const Icon(Icons.north_east_rounded, size: 16)
        : null;
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
        : null;
    return AppLink(
      href: link.href,
      builder: (context, follow) => link.primary
          ? FilledButton.icon(
              onPressed: follow,
              style: padding == null
                  ? null
                  : FilledButton.styleFrom(padding: padding),
              icon: icon ?? const SizedBox.shrink(),
              iconAlignment: IconAlignment.end,
              label: label,
            )
          : OutlinedButton.icon(
              onPressed: follow,
              style: padding == null
                  ? null
                  : OutlinedButton.styleFrom(padding: padding),
              icon: icon ?? const SizedBox.shrink(),
              iconAlignment: IconAlignment.end,
              label: label,
            ),
    );
  }
}

/// Small inline "Label →" link in the primary colour.
class InlineLink extends StatelessWidget {
  const InlineLink(this.link, {super.key});

  final SiteLink link;

  @override
  Widget build(BuildContext context) {
    return AppLink(
      href: link.href,
      builder: (context, follow) => TextButton(
        onPressed: follow,
        style: TextButton.styleFrom(
          foregroundColor: context.colors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(link.label)),
            const SizedBox(width: 4),
            Icon(
              link.isExternal
                  ? Icons.north_east_rounded
                  : Icons.arrow_forward_rounded,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

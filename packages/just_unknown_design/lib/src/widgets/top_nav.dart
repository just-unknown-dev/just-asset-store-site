import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../layout/breakpoints.dart';
import '../theme/theme_controller.dart';
import '../theme/tokens.dart';
import 'app_link.dart';
import 'brand_mark.dart';
import 'section.dart';
import 'theme_toggle_button.dart';

const double kTopNavHeight = 68;

/// The sticky header: brand, navigation (with [active] underlined), icon
/// links, [actions] and the theme switch; on narrow screens a menu button
/// ([onMenu]) instead of the links. Transparent until the page is
/// [scrolled], then frosted.
class TopNav extends StatelessWidget {
  const TopNav({
    super.key,
    required this.chrome,
    required this.theme,
    required this.onMenu,
    this.active,
    this.scrolled = false,
    this.actions = const [],
  });

  final SiteChrome chrome;
  final ThemeController theme;
  final VoidCallback onMenu;
  final SiteLink? active;
  final bool scrolled;

  /// Extra controls before the theme switch (a sign-in button, say). Shown
  /// on every form factor.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final desktop = context.isDesktop;
    final bg = context.colors.surface.withValues(alpha: scrolled ? 0.82 : 0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: scrolled ? 14 : 0,
          sigmaY: scrolled ? 14 : 0,
        ),
        child: AnimatedContainer(
          duration: JuDurations.normal,
          height: kTopNavHeight,
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: BorderSide(
                color: context.tokens.border.withValues(
                  alpha: scrolled ? 1 : 0,
                ),
              ),
            ),
          ),
          child: ContentColumn(
            child: Row(
              children: [
                if (desktop)
                  BrandMark(chrome: chrome)
                else
                  // The wordmark gives way (ellipsis) before the controls.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandMark(chrome: chrome),
                    ),
                  ),
                if (desktop) ...[
                  const SizedBox(width: JuSpacing.x8),
                  // Right-aligned; scales down rather than overflowing on
                  // narrow desktops.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final l in chrome.nav)
                              _NavLink(link: l, active: identical(l, active)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: JuSpacing.x2),
                  for (final l in chrome.iconLinks)
                    AppLink(
                      href: l.href,
                      builder: (context, follow) => IconButton(
                        tooltip: l.label,
                        onPressed: follow,
                        icon: Icon(glyphIcon(l.glyph) ?? Icons.link_rounded),
                      ),
                    ),
                  ThemeToggleButton(theme),
                  ...actions,
                ] else ...[
                  ThemeToggleButton(theme),
                  ...actions,
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: onMenu,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({required this.link, required this.active});

  final SiteLink link;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? context.colors.onSurface : context.tokens.textMuted;
    return Semantics(
      link: true,
      selected: active,
      child: AppLink(
        href: link.href,
        builder: (context, follow) => TextButton(
          onPressed: follow,
          style: TextButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(link.label),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: JuDurations.fast,
                height: 2,
                width: active ? 18 : 0,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

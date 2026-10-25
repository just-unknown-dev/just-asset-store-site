import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../theme/tokens.dart';
import 'app_link.dart';

/// Bordered card with a hover lift. Used for feature grids and item cards.
/// With [onTap] the whole card is clickable.
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(JuSpacing.x6),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final card = AnimatedContainer(
      duration: JuDurations.fast,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(JuRadii.md),
        border: Border.all(
          color: _hover
              ? context.colors.primary.withValues(alpha: 0.6)
              : tokens.border,
        ),
        boxShadow: _hover
            ? [
                BoxShadow(
                  color: tokens.glow.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: widget.child,
    );
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.onTap == null
          ? card
          : GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: card,
            ),
    );
  }
}

/// An icon on a soft primary tile.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(JuRadii.sm + 2),
      ),
      child: Icon(icon, color: context.colors.primary, size: size * 0.5),
    );
  }
}

/// A small pill label. [color] tints its border and text (a trust level,
/// say); [icon] goes before the label.
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color, this.icon});

  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color;
    final fg = tint ?? context.colors.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tint == null
            ? context.tokens.surfaceSoft
            : tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(JuRadii.pill),
        border: Border.all(
          color: tint == null
              ? context.tokens.border
              : tint.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with an icon, a badge, a title, a body and a link.
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.badge,
    this.link,
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? badge;
  final SiteLink? link;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[IconTile(icon!), const Spacer()],
              if (badge != null) StatusBadge(badge!),
            ],
          ),
          if (icon != null || badge != null)
            const SizedBox(height: JuSpacing.x5),
          Text(title, style: context.text.titleLarge),
          const SizedBox(height: JuSpacing.x2),
          Text(body, style: context.text.bodyMedium),
          if (link != null) ...[
            const Spacer(),
            const SizedBox(height: JuSpacing.x4),
            InlineLink(link!),
          ],
        ],
      ),
    );
  }
}

/// A list row: icon, title, badge, body and a trailing link.
class FeatureRow extends StatelessWidget {
  const FeatureRow({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.badge,
    this.link,
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? badge;
  final SiteLink? link;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: JuSpacing.x5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.tokens.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            IconTile(icon!, size: 40),
            const SizedBox(width: JuSpacing.x4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(title, style: context.text.titleMedium),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: JuSpacing.x2),
                      StatusBadge(badge!),
                    ],
                  ],
                ),
                const SizedBox(height: JuSpacing.x1),
                Text(body, style: context.text.bodyMedium),
                if (link != null) ...[
                  const SizedBox(height: JuSpacing.x1),
                  InlineLink(link!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

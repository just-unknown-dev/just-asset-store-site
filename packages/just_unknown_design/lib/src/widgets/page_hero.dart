import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';
import 'app_link.dart';
import 'glow_container.dart';
import 'section.dart';

/// A page's opening: eyebrow, the page's heading, the lede and its actions
/// over the brand glow. [bottom] goes under them (a search box, say).
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.title,
    required this.lede,
    this.eyebrow,
    this.actions = const [],
    this.logoAsset,
    this.compact = false,
    this.bottom,
  });

  final String title;
  final String lede;
  final String? eyebrow;
  final List<SiteLink> actions;

  /// A picture shown beside the text on desktops.
  final String? logoAsset;

  /// Smaller type for secondary pages.
  final bool compact;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final ff = context.formFactor;
    final titleStyle = switch ((ff, compact)) {
      (FormFactor.mobile, _) => context.text.displaySmall,
      (FormFactor.tablet, _) => context.text.displayMedium,
      (FormFactor.desktop, true) => context.text.displayMedium,
      (FormFactor.desktop, false) => context.text.displayLarge,
    };
    final showLogo = logoAsset != null && ff == FormFactor.desktop;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Eyebrow(eyebrow!),
          const SizedBox(height: JuSpacing.x4),
        ],
        Semantics(
          header: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Text(title, style: titleStyle),
          ),
        ),
        const SizedBox(height: JuSpacing.x6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(lede, style: context.text.bodyLarge),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: JuSpacing.x8),
          Wrap(
            spacing: JuSpacing.x3,
            runSpacing: JuSpacing.x3,
            children: [for (final a in actions) LinkButton(a)],
          ),
        ],
        if (bottom != null) ...[
          const SizedBox(height: JuSpacing.x8),
          bottom!,
        ],
      ],
    );

    final mobile = ff == FormFactor.mobile;
    return GlowContainer(
      child: Padding(
        padding: EdgeInsets.only(
          top: mobile
              ? JuSpacing.x12
              : (compact ? JuSpacing.x16 : JuSpacing.x24),
          bottom: mobile ? JuSpacing.x8 : JuSpacing.x12,
        ),
        child: ContentColumn(
          child: showLogo
              ? Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: JuSpacing.x16),
                    _HeroLogo(logoAsset!),
                  ],
                )
              : text,
        ),
      ),
    );
  }
}

class _HeroLogo extends StatelessWidget {
  const _HeroLogo(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(JuSpacing.x8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(JuRadii.lg),
        border: Border.all(color: context.tokens.border),
        boxShadow: [
          BoxShadow(
            color: context.tokens.glow.withValues(alpha: 0.25),
            blurRadius: 60,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Image.asset(
        asset,
        filterQuality: FilterQuality.medium,
        semanticLabel: '',
      ),
    );
  }
}

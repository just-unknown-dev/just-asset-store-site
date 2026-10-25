import 'package:flutter/material.dart';
import 'package:just_unknown_site/just_unknown_site.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';
import 'app_link.dart';
import 'brand_mark.dart';
import 'section.dart';

/// The footer: brand and tagline, [SiteChrome.footer]'s columns, and the
/// copyright line.
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key, required this.chrome, this.year});

  final SiteChrome chrome;

  /// The copyright year; this year when null.
  final int? year;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandMark(chrome: chrome),
        const SizedBox(height: JuSpacing.x3),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(chrome.tagline, style: context.text.bodySmall),
        ),
      ],
    );
    final columns = [
      for (final c in chrome.footer) _FooterColumn(column: c),
    ];
    final copyright = chrome.copyrightFor(year ?? DateTime.now().year);

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.tokens.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: JuSpacing.x12),
      child: ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (compact) ...[
              brand,
              for (final c in columns) ...[
                const SizedBox(height: JuSpacing.x6),
                c,
              ],
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: brand),
                  for (final c in columns) Expanded(child: c),
                ],
              ),
            if (copyright.isNotEmpty) ...[
              const SizedBox(height: JuSpacing.x10),
              Divider(color: context.tokens.border),
              const SizedBox(height: JuSpacing.x4),
              Text(copyright, style: context.text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.column});

  final FooterColumn column;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(column.title, style: context.text.titleSmall),
        const SizedBox(height: JuSpacing.x3),
        for (final l in column.links)
          Padding(
            padding: const EdgeInsets.only(bottom: JuSpacing.x1),
            child: AppLink(
              href: l.href,
              builder: (context, follow) => TextButton(
                onPressed: follow,
                style: TextButton.styleFrom(
                  foregroundColor: context.tokens.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: context.text.bodySmall,
                ),
                child: Text(l.label),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../layout/breakpoints.dart';
import '../theme/tokens.dart';

/// Centres content in the 1120px column with responsive gutters.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // Always the column's full width, so a short page starts at the same
        // left edge as a long one instead of being centred as a block.
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.gutter),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small uppercase label in the brand colour.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(color: context.colors.primary),
    );
  }
}

/// Section wrapper: eyebrow, heading, optional body, then content.
class SectionBlock extends StatelessWidget {
  const SectionBlock({
    super.key,
    required this.title,
    this.eyebrow,
    this.body,
    this.content,
    this.trailing,
    this.headingLevel = 2,
  });

  final String title;
  final String? eyebrow;
  final String? body;
  final Widget? content;
  final Widget? trailing;
  final int headingLevel;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final titleStyle = headingLevel <= 2
        ? (compact ? context.text.headlineMedium : context.text.headlineLarge)
        : context.text.headlineSmall;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? JuSpacing.x10 : JuSpacing.x16,
      ),
      child: ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              Eyebrow(eyebrow!),
              const SizedBox(height: JuSpacing.x3),
            ],
            Semantics(
              header: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(title, style: titleStyle),
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: JuSpacing.x4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(body!, style: context.text.bodyLarge),
              ),
            ],
            if (content != null) ...[
              const SizedBox(height: JuSpacing.x8),
              content!,
            ],
            if (trailing != null) ...[
              const SizedBox(height: JuSpacing.x8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

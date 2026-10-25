import 'package:flutter/material.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

/// How loud a [Notice] is.
enum NoticeTone { info, warning, error }

/// A bordered line of text with an icon: a sample-data warning, an
/// unavailable package, a form error.
class Notice extends StatelessWidget {
  const Notice(
    this.text, {
    super.key,
    this.tone = NoticeTone.info,
    this.icon,
    this.action,
  });

  final String text;
  final NoticeTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      NoticeTone.info => context.tokens.textMuted,
      NoticeTone.warning => context.colors.primary,
      NoticeTone.error => context.colors.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JuSpacing.x4,
        vertical: JuSpacing.x3,
      ),
      decoration: BoxDecoration(
        color: tone == NoticeTone.info
            ? context.tokens.surfaceSoft
            : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(JuRadii.sm),
        border: Border.all(
          color: tone == NoticeTone.info
              ? context.tokens.border
              : color.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              icon ??
                  switch (tone) {
                    NoticeTone.info => Icons.info_outline_rounded,
                    NoticeTone.warning => Icons.warning_amber_rounded,
                    NoticeTone.error => Icons.error_outline_rounded,
                  },
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: JuSpacing.x3),
          Expanded(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: context.colors.onSurface,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: JuSpacing.x3),
            action!,
          ],
        ],
      ),
    );
  }
}

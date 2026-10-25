import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_asset_store_pages/content.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../../core/auth/store_auth.dart';
import 'notice.dart';

/// The signed-in user's claim code, with how to use it and a copy button.
class ClaimCard extends StatelessWidget {
  const ClaimCard({super.key, required this.user});

  final StoreUser user;

  @override
  Widget build(BuildContext context) {
    final code = user.claim;
    return Container(
      padding: const EdgeInsets.all(JuSpacing.x5),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(JuRadii.md),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(PublishCopy.claimTitle, style: context.text.titleLarge),
          const SizedBox(height: JuSpacing.x2),
          Text(PublishCopy.claimBody, style: context.text.bodySmall),
          const SizedBox(height: JuSpacing.x4),
          if (code == null)
            const Notice(
              'GitHub didn’t say which account you signed in with. Sign out '
              'and in again.',
              tone: NoticeTone.warning,
            )
          else
            Wrap(
              spacing: JuSpacing.x3,
              runSpacing: JuSpacing.x2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  code,
                  style: juMonoStyle.copyWith(
                    fontSize: 15,
                    color: context.colors.onSurface,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(content: Text('Claim code copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

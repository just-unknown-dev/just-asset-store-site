import 'package:flutter/material.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import '../../core/auth/store_auth.dart';

/// A signed-in user's GitHub picture, or their initial.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 32});

  final StoreUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      user.label.replaceFirst('@', '').characters.first.toUpperCase(),
      style: context.text.labelLarge?.copyWith(color: context.colors.primary),
    );
    final photo = user.photoUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.primary.withValues(alpha: 0.14),
        border: Border.all(color: context.tokens.border),
      ),
      alignment: Alignment.center,
      child: photo == null
          ? initial
          : Image.network(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (context, _, _) => initial,
            ),
    );
  }
}

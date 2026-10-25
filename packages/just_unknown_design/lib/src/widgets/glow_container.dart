import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Soft radial glow in the brand colour, used behind heroes.
class GlowContainer extends StatelessWidget {
  const GlowContainer({
    super.key,
    required this.child,
    this.alignment = const Alignment(0.9, -1),
    this.radius = 1.1,
    this.intensity = 0.55,
  });

  final Widget child;
  final Alignment alignment;
  final double radius;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final glow = context.tokens.glow.withValues(
      alpha: context.tokens.glow.a * intensity,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [glow, glow.withValues(alpha: 0)],
          stops: const [0, 1],
        ),
      ),
      child: child,
    );
  }
}

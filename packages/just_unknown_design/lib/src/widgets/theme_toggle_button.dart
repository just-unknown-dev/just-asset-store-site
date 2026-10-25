import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';

import '../theme/theme_controller.dart';

/// Switches [controller] between dark and light.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton(this.controller, {super.key});

  final ThemeController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder<bool>(
      signal: controller.isDark,
      builder: (context, isDark, _) => IconButton(
        tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
        onPressed: controller.toggle,
        icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      ),
    );
  }
}

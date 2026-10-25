import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_unknown_design/just_unknown_design.dart';

import 'helpers/in_memory_storage.dart';

void main() {
  test('defaults to dark when nothing is stored', () async {
    final c = ThemeController(InMemoryStorage());
    await c.init();
    expect(c.mode.value, ThemeMode.dark);
    expect(c.isDark.value, isTrue);
  });

  test('toggle persists "light" and flips the computed', () async {
    final storage = InMemoryStorage();
    final c = ThemeController(storage);
    await c.init();
    await c.toggle();
    expect(c.mode.value, ThemeMode.light);
    expect(c.isDark.value, isFalse);
    expect(storage.snapshot[ThemeController.defaultStorageKey], 'light');
    await c.toggle();
    expect(storage.snapshot[ThemeController.defaultStorageKey], 'dark');
  });

  test('init restores a stored preference under its own key', () async {
    final c = ThemeController(
      InMemoryStorage({'site_theme': 'light'}),
      storageKey: 'site_theme',
    );
    await c.init();
    expect(c.mode.value, ThemeMode.light);
  });

  test('both themes carry the tokens and the package fonts', () {
    for (final t in [JuTheme.dark(), JuTheme.light()]) {
      expect(t.extension<JuTokens>(), isNotNull);
      expect(t.textTheme.displayLarge?.fontFamily, JuFonts.display);
      expect(t.textTheme.bodyMedium?.fontFamily, JuFonts.body);
    }
    expect(JuTheme.dark().colorScheme.primary, JuColors.primary);
    // Light mode darkens the coral so it reads as text.
    expect(JuTheme.light().colorScheme.primary, JuColorsLight.primary);
    expect(JuTheme.dark().scaffoldBackgroundColor, JuColors.background);
    expect(JuTheme.light().scaffoldBackgroundColor, JuColorsLight.background);
  });
}

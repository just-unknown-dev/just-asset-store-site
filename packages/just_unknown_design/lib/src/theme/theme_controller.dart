import 'package:flutter/material.dart';
import 'package:just_signals/just_signals.dart';
import 'package:just_storage/just_storage.dart';

/// Holds the current [ThemeMode] as a signal and persists it with
/// just_storage. Dark unless light was chosen. On the web the static shell
/// reads the same key from `localStorage` (`just_storage:<storageKey>`)
/// before the first paint, so the page never flashes the wrong theme.
final class ThemeController {
  /// A controller saving to [_storage] under [storageKey].
  ThemeController(this._storage, {this.storageKey = defaultStorageKey});

  static const String defaultStorageKey = 'theme_mode';
  static const String _light = 'light';
  static const String _dark = 'dark';

  final JustStandardStorage _storage;

  /// The key the choice is saved under.
  final String storageKey;

  final Signal<ThemeMode> mode = Signal<ThemeMode>(
    ThemeMode.dark,
    debugLabel: 'themeMode',
  );
  late final Computed<bool> isDark = Computed<bool>(
    () => mode.value != ThemeMode.light,
  );

  /// Restores the saved choice.
  Future<void> init() async {
    final stored = await _storage.read(storageKey);
    mode.value = stored == _light ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() => set(isDark.value ? ThemeMode.light : ThemeMode.dark);

  Future<void> set(ThemeMode next) async {
    mode.value = next;
    await _storage.write(storageKey, next == ThemeMode.light ? _light : _dark);
  }
}

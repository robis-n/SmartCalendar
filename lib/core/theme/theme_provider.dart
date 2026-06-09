import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Name of the Hive box opened in main().
const String kSettingsBox = 'settings';
const String _kThemeKey   = 'theme_mode';

/// Persisted app theme mode (light / dark / system). Defaults to dark.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) => ThemeModeNotifier());

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_load());

  static ThemeMode _load() {
    try {
      final raw = Hive.box(kSettingsBox).get(_kThemeKey) as String?;
      return switch (raw) {
        'light'  => ThemeMode.light,
        'system' => ThemeMode.system,
        _        => ThemeMode.dark,
      };
    } catch (_) {
      return ThemeMode.dark;
    }
  }

  void set(ThemeMode mode) {
    state = mode;
    try {
      Hive.box(kSettingsBox).put(_kThemeKey, mode.name);
    } catch (_) {/* best-effort persistence */}
  }
}

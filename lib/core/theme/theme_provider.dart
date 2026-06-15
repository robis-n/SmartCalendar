import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_theme.dart';

/// Name of the Hive box opened in main().
const String kSettingsBox = 'settings';
const String _kThemeKey     = 'theme_mode';
const String _kTextScaleKey = 'text_scale';
const String _kAccentKey    = 'accent_color_idx';

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

/// Global text-size multiplier (applied via MediaQuery.textScaler). Steps
/// chosen so type stays in HIG-comfortable proportions: 0.9 / 1.0 / 1.15 / 1.3.
final textScaleProvider =
    StateNotifierProvider<TextScaleNotifier, double>((ref) => TextScaleNotifier());

class TextScaleNotifier extends StateNotifier<double> {
  TextScaleNotifier() : super(_load());

  static const List<double> steps = [0.9, 1.0, 1.15, 1.3];
  static const List<String> labels = ['S', 'M', 'L', 'XL'];

  static double _load() {
    try {
      final v = Hive.box(kSettingsBox).get(_kTextScaleKey) as double?;
      return (v != null && steps.contains(v)) ? v : 1.0;
    } catch (_) {
      return 1.0;
    }
  }

  void set(double scale) {
    state = scale;
    try {
      Hive.box(kSettingsBox).put(_kTextScaleKey, scale);
    } catch (_) {}
  }
}

// ── Accent color ──────────────────────────────────────────────────────────────
// 6 preset hues + null (ink/monochrome default). Applied to reminder dots,
// selected-day circles, and the primary + FAB. Text stays monochrome always.
const List<Color?> accentPresets = [
  null,                    // Ink — monochrome
  Color(0xFF007AFF),       // Blue
  Color(0xFF34C759),       // Green
  Color(0xFFFF9500),       // Orange
  Color(0xFFAF52DE),       // Purple
  Color(0xFFFF3B30),       // Red
];

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, Color?>(
        (ref) => AccentColorNotifier());

class AccentColorNotifier extends StateNotifier<Color?> {
  AccentColorNotifier() : super(_load()) {
    AppColors.accentHue = state;
  }

  static Color? _load() {
    try {
      final i = Hive.box(kSettingsBox).get(_kAccentKey, defaultValue: 0) as int;
      return i >= 0 && i < accentPresets.length ? accentPresets[i] : null;
    } catch (_) {
      return null;
    }
  }

  void pick(int index) {
    if (index < 0 || index >= accentPresets.length) return;
    final c = accentPresets[index];
    state = c;
    AppColors.accentHue = c;
    try {
      Hive.box(kSettingsBox).put(_kAccentKey, index);
    } catch (_) {}
  }
}

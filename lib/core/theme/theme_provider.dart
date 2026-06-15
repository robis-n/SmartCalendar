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

// ── Theme palette (duotone) ─────────────────────────────────────────────────
// Index 0 = Ink (monochrome default). 1..N map to kAccentPalettes[index-1] —
// bold complementary duotones that recolour the WHOLE app. State is the index
// so the picker can show a tidy row; AppColors.palette is the resolved palette.
/// Resolve a stored accent index to its palette (null = Ink/monochrome).
/// Public so app.dart can keep AppColors in sync each frame.
AccentPalette? accentPaletteForIndex(int index) =>
    (index >= 1 && index <= kAccentPalettes.length)
        ? kAccentPalettes[index - 1]
        : null;

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, int>(
        (ref) => AccentColorNotifier());

class AccentColorNotifier extends StateNotifier<int> {
  AccentColorNotifier() : super(_load()) {
    AppColors.palette = accentPaletteForIndex(state);
  }

  static int _load() {
    try {
      final i = Hive.box(kSettingsBox).get(_kAccentKey, defaultValue: 0) as int;
      return (i >= 0 && i <= kAccentPalettes.length) ? i : 0;
    } catch (_) {
      return 0;
    }
  }

  void pick(int index) {
    if (index < 0 || index > kAccentPalettes.length) return;
    state = index;
    AppColors.palette = accentPaletteForIndex(index);
    try {
      Hive.box(kSettingsBox).put(_kAccentKey, index);
    } catch (_) {}
  }
}

// ── Feature visibility flags ─────────────────────────────────────────────────
// Lets the user hide optional surfaces so the app stays lean. Persisted in Hive
// as a map of key→bool; defaults all on. Watched by the dashboard + settings so
// toggling reflects immediately even though tab branches stay alive.
const String _kFeaturesKey = 'feature_flags';

class Feature {
  static const weekStrip  = 'home_week_strip';
  static const anytime    = 'home_anytime';
  static const weekAgenda = 'home_week_agenda';
  static const social     = 'social';   // friends, challenges, statistics

  // (key, title, subtitle) for the settings checklist.
  static const List<(String, String, String)> all = [
    (weekStrip,  'Week strip',        'The swipeable week at the top of Home'),
    (anytime,    'Anytime list',      'Timeless reminders with no deadline'),
    (weekAgenda, "This week agenda",  "Upcoming days listed on Home"),
    (social,     'Friends & social',  'Friends, challenges and statistics'),
  ];
}

final featureFlagsProvider =
    StateNotifierProvider<FeatureFlagsNotifier, Map<String, bool>>(
        (ref) => FeatureFlagsNotifier());

class FeatureFlagsNotifier extends StateNotifier<Map<String, bool>> {
  FeatureFlagsNotifier() : super(_load());

  static Map<String, bool> _load() {
    final out = {for (final f in Feature.all) f.$1: true};
    try {
      final raw = Hive.box(kSettingsBox).get(_kFeaturesKey);
      if (raw is Map) {
        for (final e in raw.entries) {
          if (out.containsKey(e.key) && e.value is bool) {
            out[e.key as String] = e.value as bool;
          }
        }
      }
    } catch (_) {}
    return out;
  }

  bool isOn(String key) => state[key] ?? true;

  void toggle(String key, bool value) {
    state = {...state, key: value};
    try {
      Hive.box(kSettingsBox).put(_kFeaturesKey, state);
    } catch (_) {}
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app_theme.dart';
import '../utils/time_utils.dart';
import '../../services/supabase_service.dart';

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
    try { Hive.box(kSettingsBox).put(_kThemeKey, mode.name); } catch (_) {}
    SupabaseService.syncSetting(_kThemeKey, mode.name);
  }

  void applyFromCloud(ThemeMode mode) {
    state = mode;
    try { Hive.box(kSettingsBox).put(_kThemeKey, mode.name); } catch (_) {}
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
    try { Hive.box(kSettingsBox).put(_kTextScaleKey, scale); } catch (_) {}
    SupabaseService.syncSetting(_kTextScaleKey, scale);
  }

  void applyFromCloud(double scale) {
    state = scale;
    try { Hive.box(kSettingsBox).put(_kTextScaleKey, scale); } catch (_) {}
  }
}

// ── Theme palette (duotone) ─────────────────────────────────────────────────
// Index 0 = Ink (monochrome default). 1..N map to kAccentPalettes[index-1] —
// curated complementary duotones. Index kCustomAccentIndex is "Custom": the
// palette is generated live from a user-picked Color stored in
// customAccentColorProvider. State is the index; AppColors.palette is resolved.
const String _kCustomColorKey = 'custom_accent_color'; // stored as int ARGB
final int kCustomAccentIndex = kAccentPalettes.length + 1;

// Keep legacy hue key so existing users don't lose their custom choice.
const String _kCustomHueKey = 'custom_accent_hue';

/// Resolve a stored accent index to its palette (null = Ink/monochrome).
/// Public so app.dart can keep AppColors in sync each frame. [customColor] is
/// only consulted when [index] selects the custom slot.
AccentPalette? accentPaletteForIndex(int index, [Color? customColor]) {
  if (index >= 1 && index <= kAccentPalettes.length) {
    return kAccentPalettes[index - 1];
  }
  if (index == kCustomAccentIndex) {
    return derivePaletteFromColor(customColor ?? const Color(0xFF0A84FF));
  }
  return null;
}

final accentColorProvider =
    StateNotifierProvider<AccentColorNotifier, int>(
        (ref) => AccentColorNotifier());

class AccentColorNotifier extends StateNotifier<int> {
  AccentColorNotifier() : super(_load()) {
    AppColors.palette = accentPaletteForIndex(state, _loadColor());
  }

  static int _load() {
    try {
      final i = Hive.box(kSettingsBox).get(_kAccentKey, defaultValue: 0) as int;
      return (i >= 0 && i <= kCustomAccentIndex) ? i : 0;
    } catch (_) {
      return 0;
    }
  }

  static Color _loadColor() {
    try {
      final box = Hive.box(kSettingsBox);
      // Prefer the new full-color key; fall back to legacy hue if it exists.
      final argb = box.get(_kCustomColorKey) as int?;
      if (argb != null) return Color(argb);
      final hue = box.get(_kCustomHueKey) as double?;
      if (hue != null) return HSLColor.fromAHSL(1, hue, 0.85, 0.62).toColor();
    } catch (_) {}
    return const Color(0xFF0A84FF);
  }

  // Reads the freshly-persisted color, so picking right after the color sheet
  // closes (which writes via CustomAccentColorNotifier.set first) resolves
  // correctly — Hive's in-memory box is consistent immediately.
  void pick(int index) {
    if (index < 0 || index > kCustomAccentIndex) return;
    state = index;
    AppColors.palette = accentPaletteForIndex(index, _loadColor());
    try { Hive.box(kSettingsBox).put(_kAccentKey, index); } catch (_) {}
    SupabaseService.syncSetting(_kAccentKey, index);
  }

  void applyFromCloud(int index, Color customColor) {
    if (index < 0 || index > kCustomAccentIndex) return;
    state = index;
    AppColors.palette = accentPaletteForIndex(index, customColor);
    try { Hive.box(kSettingsBox).put(_kAccentKey, index); } catch (_) {}
  }
}

/// The persisted fully-custom accent color.
final customAccentColorProvider =
    StateNotifierProvider<CustomAccentColorNotifier, Color>(
        (ref) => CustomAccentColorNotifier());

class CustomAccentColorNotifier extends StateNotifier<Color> {
  CustomAccentColorNotifier() : super(AccentColorNotifier._loadColor());

  void set(Color color) {
    state = color;
    try { Hive.box(kSettingsBox).put(_kCustomColorKey, color.toARGB32()); } catch (_) {}
    SupabaseService.syncSetting(_kCustomColorKey, color.toARGB32());
  }

  void applyFromCloud(Color color) {
    state = color;
    try { Hive.box(kSettingsBox).put(_kCustomColorKey, color.toARGB32()); } catch (_) {}
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
  static const undone     = 'home_undone';   // unfinished-tasks button
  static const quotes     = 'home_quotes';   // daily motivational quote card
  static const social     = 'social';        // friends, challenges, statistics

  // (key, title, subtitle) for the settings checklist.
  static const List<(String, String, String)> all = [
    (weekStrip,  'Week strip',        'The swipeable week at the top of Home'),
    (anytime,    'Anytime list',      'Timeless reminders with no deadline'),
    (weekAgenda, 'This week agenda',  'Upcoming days listed on Home'),
    (undone,     'Unfinished button', 'Quick access to overdue tasks on Home'),
    (quotes,     'Daily quote',       'A little motivation at the top of Home'),
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
    out[Feature.quotes] = false; // opt-in — off by default to stay lean
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
    try { Hive.box(kSettingsBox).put(_kFeaturesKey, state); } catch (_) {}
    SupabaseService.syncSetting(_kFeaturesKey, state);
  }

  void applyFromCloud(Map<String, bool> merged) {
    state = merged;
    try { Hive.box(kSettingsBox).put(_kFeaturesKey, merged); } catch (_) {}
  }
}

// ── Time format (12h AM/PM vs 24h) ───────────────────────────────────────────
// State is `use24h`. Mirrored into TimeFmt.use24h (set in app.dart each frame)
// so every clock label across the app respects it from one place.
const String _kUse24hKey = 'time_use_24h';

final timeFormatProvider =
    StateNotifierProvider<TimeFormatNotifier, bool>(
        (ref) => TimeFormatNotifier());

class TimeFormatNotifier extends StateNotifier<bool> {
  TimeFormatNotifier() : super(_load()) {
    TimeFmt.use24h = state;
  }

  static bool _load() {
    try {
      return Hive.box(kSettingsBox).get(_kUse24hKey, defaultValue: false) as bool;
    } catch (_) {
      return false;
    }
  }

  void set(bool use24h) {
    state = use24h;
    TimeFmt.use24h = use24h;
    try { Hive.box(kSettingsBox).put(_kUse24hKey, use24h); } catch (_) {}
    SupabaseService.syncSetting(_kUse24hKey, use24h);
  }

  void applyFromCloud(bool use24h) {
    state = use24h;
    TimeFmt.use24h = use24h;
    try { Hive.box(kSettingsBox).put(_kUse24hKey, use24h); } catch (_) {}
  }
}

// ── Cross-device settings sync ───────────────────────────────────────────────

/// Applies a map of preferences (from Supabase) to the Riverpod providers AND
/// to Hive so the values persist locally for offline startup.
/// Called on sign-in to pull cloud settings onto the current device.
void applyCloudSettings(Map<String, dynamic> prefs, WidgetRef ref) {
  // Theme mode
  if (prefs[_kThemeKey] is String) {
    final mode = switch (prefs[_kThemeKey] as String) {
      'light'  => ThemeMode.light,
      'system' => ThemeMode.system,
      _        => ThemeMode.dark,
    };
    ref.read(themeModeProvider.notifier).applyFromCloud(mode);
  }

  // Text scale
  if (prefs[_kTextScaleKey] is num) {
    final scale = (prefs[_kTextScaleKey] as num).toDouble();
    if (TextScaleNotifier.steps.contains(scale)) {
      ref.read(textScaleProvider.notifier).applyFromCloud(scale);
    }
  }

  // Time format
  if (prefs[_kUse24hKey] is bool) {
    ref.read(timeFormatProvider.notifier).applyFromCloud(prefs[_kUse24hKey] as bool);
  }

  // Custom accent color (must be applied before accent index)
  if (prefs[_kCustomColorKey] is num) {
    final color = Color((prefs[_kCustomColorKey] as num).toInt());
    ref.read(customAccentColorProvider.notifier).applyFromCloud(color);
  }

  // Accent index
  if (prefs[_kAccentKey] is num) {
    final idx = (prefs[_kAccentKey] as num).toInt();
    final customColor = ref.read(customAccentColorProvider);
    ref.read(accentColorProvider.notifier).applyFromCloud(idx, customColor);
  }

  // Feature flags
  if (prefs[_kFeaturesKey] is Map) {
    final raw = Map<String, dynamic>.from(prefs[_kFeaturesKey] as Map);
    final current = ref.read(featureFlagsProvider);
    final merged = Map<String, bool>.from(current);
    for (final e in raw.entries) {
      if (merged.containsKey(e.key) && e.value is bool) {
        merged[e.key] = e.value as bool;
      }
    }
    ref.read(featureFlagsProvider.notifier).applyFromCloud(merged);
  }
}

/// Resets Hive settings to defaults so the next sign-in starts clean.
Future<void> clearLocalSettings() async {
  try { await Hive.box(kSettingsBox).clear(); } catch (_) {}
}

// ── Daily quote ──────────────────────────────────────────────────────────────
// A tiny offline rotation — no network. Index by day-of-year so it changes
// once a day and is stable within the day.
const List<String> kQuotes = [
  'Small steps every day.',
  'Done is better than perfect.',
  'Discipline is choosing what you want most over what you want now.',
  'You don\'t have to be extreme, just consistent.',
  'The secret of getting ahead is getting started.',
  'Motivation gets you going; habit keeps you growing.',
  'A year from now you\'ll wish you started today.',
  'Focus on progress, not perfection.',
  'What gets scheduled gets done.',
  'Win the morning, win the day.',
];

String quoteOfTheDay([DateTime? now]) {
  final d = now ?? DateTime.now();
  final dayOfYear = d.difference(DateTime(d.year)).inDays;
  return kQuotes[dayOfYear % kQuotes.length];
}

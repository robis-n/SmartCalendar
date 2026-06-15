import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PURE TWO-COLOUR SYSTEM  —  ink + paper, inverted per theme.
///
///  There are only two real colours in the whole app:
///    • paper  (background)
///    • ink    (foreground / text / accent / selection fill)
///
///  Everything else is an opacity step of ink on paper. Status, selection and
///  emphasis are expressed with FILL / RING / STRIKETHROUGH — never with hue.
///
///  Because the legacy codebase references AppColors.* directly (not through
///  Theme.of(context)), these are runtime getters that read a single global
///  brightness flag. MaterialApp rebuilds the whole tree when the theme mode
///  changes, so every getter re-resolves automatically.
/// ─────────────────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  static bool _dark = true;
  static bool get isDark => _dark;
  static set dark(bool v) => _dark = v;

  // ── The two anchors (pure-ink default, no accent chosen) ─────────
  static const _inkDark   = Color(0xFFF4F3EF); // near-white ink (used on dark)
  static const _paperDark = Color(0xFF0B0B0D); // near-black paper
  static const _inkLight  = Color(0xFF0B0B0D); // near-black ink (used on light)
  static const _paperLight = Color(0xFFF6F5F1); // warm near-white paper

  // ── Optional accent hue — GLOBAL palette seed ────────────────────
  // null  = pure ink/paper monochrome (the default identity).
  // When set, the WHOLE palette is re-derived as a tinted-neutral triad
  // (Surface · Ink · Accent): the background, cards and ink all pick up a
  // restrained amount of the chosen hue, the way Apple's tinted grays and
  // GitHub's "dimmed" themes do — never a flat wash of pure colour.
  // Synced in app.dart's builder each frame.
  static Color? _accentHue;
  static set accentHue(Color? c) => _accentHue = c;
  static double get _hue => HSLColor.fromColor(_accentHue!).hue;

  // HSL helper: opaque colour from the accent hue at a given saturation /
  // lightness. Keeps the tints consistent and tunable from one place.
  static Color _tint(double sat, double light) =>
      HSLColor.fromAHSL(1, _hue, sat, light).toColor();

  /// Paper — the background. Tinted-neutral when an accent is active.
  static Color get bg {
    if (_accentHue == null) return _dark ? _paperDark : _paperLight;
    return _dark ? _tint(0.22, 0.069) : _tint(0.46, 0.965);
  }

  /// Ink — the foreground / text. Tinted-neutral when an accent is active.
  static Color get label {
    if (_accentHue == null) return _dark ? _inkDark : _inkLight;
    return _dark ? _tint(0.14, 0.945) : _tint(0.55, 0.095);
  }

  // ── Elevated surfaces (subtle steps on paper) ────────────────────
  static Color get card {
    if (_accentHue == null) {
      return _dark ? const Color(0xFF161618) : Colors.white;
    }
    return _dark ? _tint(0.18, 0.108) : _tint(0.60, 0.995);
  }

  static Color get bg2 {
    if (_accentHue == null) {
      return _dark ? const Color(0xFF202023) : const Color(0xFFECEBE6);
    }
    return _dark ? _tint(0.18, 0.16) : _tint(0.42, 0.912);
  }

  // ── Ink at reduced strength (text hierarchy / hairlines) ─────────
  static Color get label2      => label.withValues(alpha: 0.55);
  static Color get label3      => label.withValues(alpha: 0.34);
  static Color get separator   => label.withValues(alpha: 0.10);
  static Color get accentLight => label.withValues(alpha: 0.07); // faint ink tint bg

  // ── Glass (iOS "material" translucent chrome) ────────────────────
  // Derived from the (possibly tinted) card surface so the chrome carries the
  // same hue as the rest of the app. Pair with BackdropFilter(sigma 22).
  static Color get glass => card.withValues(alpha: _dark ? 0.72 : 0.78);
  // Subtle bright rim along the edge, like light catching glass.
  static Color get glassBorder =>
      _dark ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.55);
  // Recommended blur radius for glass surfaces.
  static const double glassBlur = 22;

  // ── Accent (the vivid third colour) ──────────────────────────────
  // The saturated seed itself — selection fills, the + FAB, reminder dots,
  // the nav pill. Falls back to ink in mono mode, so any accent/onAccent
  // pairing is a no-op in the default theme.
  static Color get accent => _accentHue ?? label;
  // Legible text/icon colour to sit ON an accent fill.
  static Color get onAccent {
    if (_accentHue == null) return bg;
    return ThemeData.estimateBrightnessForColor(_accentHue!) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static Color get accentDark   => label;
  static Color get success       => label;
  static Color get successBg     => label.withValues(alpha: 0.08);
  static Color get warning       => label;
  static Color get warningBg     => label.withValues(alpha: 0.08);
  static Color get destructive   => label;
  static Color get destructiveBg => label.withValues(alpha: 0.08);

  // ── Priority — monochrome weight, not colour ─────────────────────
  static Color priorityColor(String? p) => label;
  static Color priorityBg(String? p) => label.withValues(alpha: 0.07);
}

/// ─────────────────────────────────────────────────────────────────────────
///  MOTION — one place for the curves & durations that give the app its
///  "human" feel. These mirror the easing the best web/native UIs lean on:
///   • emphasized:    Material 3 emphasized-decelerate — fast out, soft land.
///                    Ideal for entering content (sections, sheets, zoom-in).
///   • emphasizedIn:  emphasized-accelerate — for content leaving.
///   • standard:      the everyday ease for small state changes.
///   • spring:        a gentle overshoot for the nav pill / tactile controls,
///                    the closest Curves equivalent to a UIKit spring.
///  Durations follow the iOS rhythm: quick taps ~220ms, page-level ~360ms.
/// ─────────────────────────────────────────────────────────────────────────
class AppMotion {
  AppMotion._();

  static const Curve emphasized   = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve emphasizedIn = Cubic(0.3, 0.0, 0.8, 0.15);
  static const Curve standard     = Cubic(0.4, 0.0, 0.2, 1.0);
  static const Curve spring       = Cubic(0.34, 1.32, 0.42, 1.0); // soft overshoot

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration base = Duration(milliseconds: 360);
  static const Duration slow = Duration(milliseconds: 460);
}

/// Ink "gradient" — a flat inked fill (kept as a gradient for call-site compat).
LinearGradient get accentGradient => LinearGradient(
  colors: [AppColors.label, AppColors.label.withValues(alpha: 0.86)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Soft, neutral elevation shadow (lighter in light mode).
List<BoxShadow> get cardShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: AppColors.isDark ? 0.45 : 0.06),
    blurRadius: 24,
    offset: const Offset(0, 10),
  ),
];

/// ─────────────────────────────────────────────────────────────────────────
///  ThemeData builders. We expose `light` and `dark` and a `.themed(bool)`
///  factory so app.dart can pick based on the provider.
/// ─────────────────────────────────────────────────────────────────────────
class AppTheme {
  static ThemeData _build(bool dark) {
    // Resolve colours for this build by flipping the global flag first.
    AppColors.dark = dark;
    final ink   = AppColors.label;
    final paper = AppColors.bg;

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: paper,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: ink,
        onPrimary: paper,
        surface: AppColors.card,
        onSurface: ink,
        secondary: ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: ink,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
        subtitleTextStyle: TextStyle(fontSize: 13, color: AppColors.label3),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.separator,
        thickness: 0.5,
        space: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.separator),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: AppColors.label3),
        hintStyle: TextStyle(color: AppColors.label3),
      ),
      textTheme: TextTheme(
        displayLarge:   TextStyle(fontSize: 64, fontWeight: FontWeight.w800, letterSpacing: -3.0, color: ink, height: 0.95),
        displayMedium:  TextStyle(fontSize: 48, fontWeight: FontWeight.w800, letterSpacing: -2.0, color: ink, height: 1.0),
        displaySmall:   TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: ink),
        headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: ink),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: ink),
        headlineSmall:  TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: ink),
        titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: ink),
        titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: ink),
        bodyLarge:      TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: ink),
        bodyMedium:     TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: ink),
        bodySmall:      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.label3),
        labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.label2, letterSpacing: 0.2),
        labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.label3, letterSpacing: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: ink),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? paper : AppColors.label3),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? ink : AppColors.separator),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bg2,
        contentTextStyle: TextStyle(color: ink),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.card,
        headerBackgroundColor: AppColors.bg2,
        dayForegroundColor: WidgetStatePropertyAll(ink),
        todayBorder: BorderSide(color: ink),
      ),
      timePickerTheme: TimePickerThemeData(backgroundColor: AppColors.card),
    );
  }

  static ThemeData get dark  => _build(true);
  static ThemeData get light => _build(false);
}

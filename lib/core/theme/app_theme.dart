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

  // ── Theme palette — a bold DUOTONE, not a tint ───────────────────
  // null  = pure ink/paper monochrome (the default identity).
  // When a palette is chosen the whole app becomes a real two-colour world:
  // a richly-coloured surface family (clearly blue / green / plum …) PLUS a
  // complementary accent (gold / coral / lime …) for the FAB, selection, dots
  // and nav pill. Solid, high-contrast — see [AccentPalette] for the curated
  // pairs. Synced in app.dart's builder each frame.
  static AccentPalette? palette;

  /// Background — the dominant colour of the duotone.
  static Color get bg {
    final p = palette;
    if (p == null) return _dark ? _paperDark : _paperLight;
    return _dark ? p.darkBg : p.lightBg;
  }

  /// Ink — the foreground / text (high-contrast against [bg]).
  static Color get label {
    final p = palette;
    if (p == null) return _dark ? _inkDark : _inkLight;
    return _dark ? p.darkInk : p.lightInk;
  }

  // ── Elevated surfaces (steps above the background) ───────────────
  static Color get card {
    final p = palette;
    if (p == null) return _dark ? const Color(0xFF161618) : Colors.white;
    return _dark ? p.darkSurface : p.lightSurface;
  }

  static Color get bg2 {
    final p = palette;
    if (p == null) {
      return _dark ? const Color(0xFF202023) : const Color(0xFFECEBE6);
    }
    return _dark ? p.darkSurface2 : p.lightSurface2;
  }

  // ── Ink at reduced strength (text hierarchy / hairlines) ─────────
  static Color get label2      => label.withValues(alpha: 0.55);
  static Color get label3      => label.withValues(alpha: 0.34);
  static Color get separator   => label.withValues(alpha: 0.10);
  static Color get accentLight => label.withValues(alpha: 0.07); // faint ink tint bg

  // ── Glass (iOS "material" translucent chrome) ────────────────────
  // Derived from the surface so the chrome carries the same hue as the app.
  // Less opaque than before — true vibrancy materials let more of the
  // blurred+saturated backdrop show through; see GlassSurface for the rest
  // of the recipe (gradient fill, rim highlight, sheen).
  static Color get glass => card.withValues(alpha: _dark ? 0.58 : 0.66);
  static Color get glassBorder =>
      _dark ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.55);
  static const double glassBlur = 22;

  // ── Accent (the complementary second colour) ─────────────────────
  // The vivid complement — FAB, selection fills, reminder dots, nav pill.
  // Falls back to ink in mono mode, so any accent/onAccent pairing is a
  // no-op in the default theme.
  static Color get accent {
    final p = palette;
    if (p == null) return label;
    return _dark ? p.darkAccent : p.lightAccent;
  }
  // Legible text/icon colour to sit ON an accent fill.
  static Color get onAccent {
    if (palette == null) return bg;
    return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
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
///  DUOTONE PALETTES — curated, solid complementary pairs.
///
///  Each palette is a full surface family (bg / surface / surface2 / ink) in a
///  single dominant hue, plus a COMPLEMENTARY accent — the colour-theory
///  opposite, so the two read as a real pair (blue↔gold, green↔coral,
///  plum↔lime, crimson↔teal, sunset-orange↔sky-blue). Dark mode uses a deep,
///  saturated surface with near-white ink; light mode uses a clearly-tinted
///  (not whitish) surface with near-black ink. Hand-tuned for AA contrast.
/// ─────────────────────────────────────────────────────────────────────────
class AccentPalette {
  final String name;
  // Dark mode
  final Color darkBg, darkSurface, darkSurface2, darkInk, darkAccent;
  // Light mode
  final Color lightBg, lightSurface, lightSurface2, lightInk, lightAccent;
  const AccentPalette({
    required this.name,
    required this.darkBg,
    required this.darkSurface,
    required this.darkSurface2,
    required this.darkInk,
    required this.darkAccent,
    required this.lightBg,
    required this.lightSurface,
    required this.lightSurface2,
    required this.lightInk,
    required this.lightAccent,
  });

  /// Swatch shown in the picker (the dominant colour) + its accent dot.
  Color get swatch => darkBg == const Color(0xFF000000) ? darkSurface : darkBg;
}

/// The selectable palettes. `null` (Ink) is represented separately in the
/// provider as the monochrome default — these are the colourful options.
const List<AccentPalette> kAccentPalettes = [
  // Ocean × Gold — deep navy with warm gold.
  AccentPalette(
    name: 'Ocean',
    darkBg: Color(0xFF0C1A2B), darkSurface: Color(0xFF132840),
    darkSurface2: Color(0xFF1C3756), darkInk: Color(0xFFEAF2FF),
    darkAccent: Color(0xFFFFC24B),
    lightBg: Color(0xFFDDEAFB), lightSurface: Color(0xFFFFFFFF),
    lightSurface2: Color(0xFFCBDDF4), lightInk: Color(0xFF0C1A2B),
    lightAccent: Color(0xFFD8860B),
  ),
  // Forest × Coral — deep green with warm coral.
  AccentPalette(
    name: 'Forest',
    darkBg: Color(0xFF0D1F16), darkSurface: Color(0xFF143024),
    darkSurface2: Color(0xFF1E4533), darkInk: Color(0xFFE9F6EE),
    darkAccent: Color(0xFFFF7A59),
    lightBg: Color(0xFFDDEFE3), lightSurface: Color(0xFFFFFFFF),
    lightSurface2: Color(0xFFC8E6D2), lightInk: Color(0xFF0D1F16),
    lightAccent: Color(0xFFE2552B),
  ),
  // Plum × Lime — deep purple with electric lime.
  AccentPalette(
    name: 'Plum',
    darkBg: Color(0xFF1A1026), darkSurface: Color(0xFF271637),
    darkSurface2: Color(0xFF38214E), darkInk: Color(0xFFF3EAFB),
    darkAccent: Color(0xFFB6E021),
    lightBg: Color(0xFFEDE4F7), lightSurface: Color(0xFFFFFFFF),
    lightSurface2: Color(0xFFDDCEEF), lightInk: Color(0xFF1A1026),
    lightAccent: Color(0xFF5E7C00),
  ),
  // Crimson × Teal — deep maroon with bright teal.
  AccentPalette(
    name: 'Crimson',
    darkBg: Color(0xFF230F13), darkSurface: Color(0xFF34161C),
    darkSurface2: Color(0xFF4A1F27), darkInk: Color(0xFFFCEAED),
    darkAccent: Color(0xFF2BD4C0),
    lightBg: Color(0xFFFBE2E6), lightSurface: Color(0xFFFFFFFF),
    lightSurface2: Color(0xFFF1CDD3), lightInk: Color(0xFF230F13),
    lightAccent: Color(0xFF0E8C7D),
  ),
  // Sunset × Sky — warm umber with cool sky-blue.
  AccentPalette(
    name: 'Sunset',
    darkBg: Color(0xFF241606), darkSurface: Color(0xFF34230E),
    darkSurface2: Color(0xFF4A3115), darkInk: Color(0xFFFFF2E4),
    darkAccent: Color(0xFF4DA3FF),
    lightBg: Color(0xFFFBEEDD), lightSurface: Color(0xFFFFFFFF),
    lightSurface2: Color(0xFFF1DEC4), lightInk: Color(0xFF241606),
    lightAccent: Color(0xFF0A6BD6),
  ),
];

/// Builds a full [AccentPalette] from a single seed hue (0–360°).
/// Kept for legacy callers — prefer [derivePaletteFromColor].
AccentPalette derivePaletteFromHue(double hue) =>
    derivePaletteFromColor(HSLColor.fromAHSL(1, hue % 360, 0.85, 0.62).toColor());

/// Builds a full [AccentPalette] from an arbitrary Color the user picked.
/// Uses the picked color directly as the accent; derives the surface family
/// from its HSV hue (scaled by the picked saturation so a muted pick gives a
/// muted surface, not a vivid one).
AccentPalette derivePaletteFromColor(Color picked) {
  final hsv = HSVColor.fromColor(picked);
  final h   = hsv.hue;
  final sat = hsv.saturation.clamp(0.3, 1.0); // never go fully grey
  Color hsl(double hue, double s, double l) =>
      HSLColor.fromAHSL(1, hue, s, l).toColor();
  // Darken for light-mode accent to keep contrast on white background.
  final lightAccent = HSLColor.fromColor(picked)
      .withLightness((HSLColor.fromColor(picked).lightness * 0.65).clamp(0.2, 0.55))
      .toColor();
  return AccentPalette(
    name: 'Custom',
    darkBg:        hsl(h, sat * 0.55, 0.10),
    darkSurface:   hsl(h, sat * 0.50, 0.15),
    darkSurface2:  hsl(h, sat * 0.42, 0.21),
    darkInk:       hsl(h, 0.15, 0.95),
    darkAccent:    picked,
    lightBg:       hsl(h, sat * 0.55, 0.92),
    lightSurface:  hsl(h, sat * 0.30, 0.99),
    lightSurface2: hsl(h, sat * 0.40, 0.86),
    lightInk:      hsl(h, sat * 0.55, 0.11),
    lightAccent:   lightAccent,
  );
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

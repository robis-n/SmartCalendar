import 'package:flutter/material.dart';

class AppColors {
  // ── Brand accent — warm editorial gold ───────────────
  static const accent      = Color(0xFFD4AF7A); // warm gold (luxury editorial)
  static const accentLight = Color(0xFF2A2118); // gold tint bg on dark
  static const accentDark  = Color(0xFFB08040); // deeper gold

  // ── Semantic ─────────────────────────────────────────
  static const success      = Color(0xFF34D399); // emerald
  static const successBg    = Color(0xFF0C2B1E);
  static const warning      = Color(0xFFFFB347); // warm amber
  static const warningBg    = Color(0xFF2B1E08);
  static const destructive  = Color(0xFFFF6B6B); // coral
  static const destructiveBg = Color(0xFF2B0D0D);

  // ── Surfaces (warm dark editorial) ───────────────────
  static const bg   = Color(0xFF100F1A); // near-black, slight warm purple
  static const card = Color(0xFF1A1928); // dark card surface
  static const bg2  = Color(0xFF222135); // elevated card / icon bg

  // ── Text ─────────────────────────────────────────────
  static const label  = Color(0xFFF0EDE8); // warm cream white
  static const label2 = Color(0xFFB8B3C0); // cool-warm midtone
  static const label3 = Color(0xFF6A677A); // darker subtext

  // ── Dividers ─────────────────────────────────────────
  static const separator = Color(0xFF252440);

  // ── Priority ─────────────────────────────────────────
  static Color priorityColor(String? p) => switch (p) {
    'high'   => destructive,
    'medium' => warning,
    _        => success,
  };
  static Color priorityBg(String? p) => switch (p) {
    'high'   => destructiveBg,
    'medium' => warningBg,
    _        => successBg,
  };
}

// Gold editorial gradient
LinearGradient get accentGradient => const LinearGradient(
  colors: [Color(0xFFE8C890), Color(0xFFB08040)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Subtle dark card shadow — warm, not harsh
List<BoxShadow> get cardShadow => [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.40),
    blurRadius: 24,
    offset: const Offset(0, 8),
  ),
  BoxShadow(
    color: const Color(0xFFD4AF7A).withValues(alpha: 0.03),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

class AppTheme {
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.card,
      onSurface: AppColors.label,
      secondary: AppColors.accentDark,
      surfaceContainer: AppColors.bg2,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.label,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.label,
        letterSpacing: -0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      titleTextStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label),
      subtitleTextStyle: const TextStyle(fontSize: 13, color: AppColors.label3),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg2,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.separator),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.separator),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: AppColors.label3),
      hintStyle: const TextStyle(color: AppColors.label3),
    ),
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 56, fontWeight: FontWeight.w900, letterSpacing: -2.5, color: AppColors.label, height: 1),
      displayMedium:  TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: AppColors.label, height: 1.1),
      displaySmall:   TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: AppColors.label),
      headlineLarge:  TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: AppColors.label),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: AppColors.label),
      headlineSmall:  TextStyle(fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: AppColors.label),
      titleLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.label),
      titleMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label),
      bodyLarge:      TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: AppColors.label),
      bodyMedium:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.label),
      bodySmall:      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.label3),
      labelLarge:     TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.label2, letterSpacing: 0.3),
      labelSmall:     TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.label3, letterSpacing: 1.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? AppColors.bg : AppColors.label3),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.separator),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.bg2,
      contentTextStyle: TextStyle(color: AppColors.label),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
    datePickerTheme: const DatePickerThemeData(
      backgroundColor: AppColors.card,
      headerBackgroundColor: AppColors.bg2,
      dayForegroundColor: WidgetStatePropertyAll(AppColors.label),
      todayBorder: BorderSide(color: AppColors.accent),
    ),
    timePickerTheme: const TimePickerThemeData(
      backgroundColor: AppColors.card,
    ),
  );

  // Keep light as alias so nothing breaks if referenced elsewhere
  static final light = dark;
}

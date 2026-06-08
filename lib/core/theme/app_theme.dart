import 'package:flutter/material.dart';

class AppColors {
  // ── Brand ──────────────────────────────────────────────
  static const accent      = Color(0xFF7C5CFC); // soft violet — the signature color
  static const accentLight = Color(0xFFEDE9FF); // violet tint for backgrounds
  static const accentDark  = Color(0xFF5B3FD9); // deeper violet for gradients

  // ── Semantic ───────────────────────────────────────────
  static const success     = Color(0xFF00C48C); // emerald green
  static const successBg   = Color(0xFFE6FBF4);
  static const warning     = Color(0xFFFF9F43); // warm orange
  static const warningBg   = Color(0xFFFFF3E0);
  static const destructive = Color(0xFFFF5C78); // coral red (softer than harsh red)
  static const destructiveBg = Color(0xFFFFECEF);

  // ── Surfaces ───────────────────────────────────────────
  static const bg          = Color(0xFFF7F7FB); // off-white with lavender tint
  static const card        = Color(0xFFFFFFFF);
  static const bg2         = Color(0xFFF0EFF8); // slightly more lavender

  // ── Text ───────────────────────────────────────────────
  static const label       = Color(0xFF1A1825); // near-black with purple warmth
  static const label2      = Color(0xFF4A4760);
  static const label3      = Color(0xFF9896A8); // cool mid-gray

  // ── Dividers ───────────────────────────────────────────
  static const separator   = Color(0xFFEAE9F2);

  // ── Priority ───────────────────────────────────────────
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

// Shared gradient
LinearGradient get accentGradient => const LinearGradient(
  colors: [Color(0xFF7C5CFC), Color(0xFF5B3FD9)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Soft card shadow
List<BoxShadow> get cardShadow => [
  BoxShadow(
    color: const Color(0xFF7C5CFC).withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
  ),
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.04),
    blurRadius: 6,
    offset: const Offset(0, 1),
  ),
];

class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.accent,
      surface: AppColors.card,
      onSurface: AppColors.label,
      secondary: AppColors.accentDark,
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
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      elevation: 0,
      indicatorColor: AppColors.accentLight,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.label2),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.separator,
      thickness: 0.5,
      space: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
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
      displayLarge:  TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: AppColors.label),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.7, color: AppColors.label),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: AppColors.label),
      headlineMedium:TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.label),
      titleLarge:    TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: AppColors.label),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.label),
      bodyLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: AppColors.label),
      bodyMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.label),
      bodySmall:     TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.label3),
      labelSmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.label3, letterSpacing: 0.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
          s.contains(WidgetState.selected) ? AppColors.accent : Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accent.withValues(alpha: 0.5)
              : AppColors.separator),
    ),
  );
}

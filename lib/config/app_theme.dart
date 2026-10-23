import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0B6B57);
  static const Color dark = Color(0xFF073B32);
  static const Color accent = Color(0xFFF4B942);
  static const Color background = Color(0xFFF5F8F7);
  static const Color surface = Color(0xFFFFFFFF);

  // Status & severity colors
  static const Color critical = Color(0xFFD64545);
  static const Color success = Color(0xFF198754);
  static const Color warning = Color(0xFFE9A23B);
  static const Color info = Color(0xFF3B82F6);

  // Surface variations
  static const Color surfaceMuted = Color(0xFFEFF3F2);
  static const Color borderLight = Color(0xFFE1E8E5);
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primary.withValues(alpha: 0.12),
      onPrimaryContainer: AppColors.dark,
      secondary: AppColors.accent,
      onSecondary: AppColors.dark,
      secondaryContainer: AppColors.accent.withValues(alpha: 0.2),
      onSecondaryContainer: AppColors.dark,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.info.withValues(alpha: 0.15),
      onTertiaryContainer: const Color(0xFF1E40AF),
      error: AppColors.critical,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: const Color(0xFF1C2826),
      onSurfaceVariant: const Color(0xFF536360),
      outline: const Color(0xFF8B9E9A),
      outlineVariant: AppColors.borderLight,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceMuted,
      surfaceContainer: const Color(0xFFE8EFEF),
      surfaceContainerHigh: const Color(0xFFDFE8E7),
      surfaceContainerHighest: const Color(0xFFD6E2E1),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.dark,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.dark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 2,
        height: 72,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 12,
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFF6B7E7B),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : const Color(0xFF6B7E7B),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

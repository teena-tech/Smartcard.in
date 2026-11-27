import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    final colors = AppColors.of(mode);
    final isDark = mode != AppThemeMode.light;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: AppColors.primaryRed,
      scaffoldBackgroundColor: Colors.transparent, // We'll handle gradient background in a wrapper
      fontFamily: AppFonts.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        surface: colors.card,
        error: colors.danger,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      textTheme: AppFonts.textTheme().apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.menuBg,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryRed.withValues(alpha: 0.6), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryRed, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger, width: 2.0),
        ),
        hintStyle: AppFonts.poppins(color: colors.muted, fontSize: 14),
        labelStyle: AppFonts.poppins(color: colors.muted, fontSize: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

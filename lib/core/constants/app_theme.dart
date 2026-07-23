import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    final colors = AppColors.of(mode);
    final isDark = mode != AppThemeMode.light;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: AppColors.primaryRed,
      scaffoldBackgroundColor: Colors.transparent, // We'll handle gradient background in a wrapper
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryRed,
        primary: AppColors.primaryRed,
        surface: colors.card,
        error: colors.danger,
        brightness: isDark ? Brightness.dark : Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.menuBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colors.text),
        titleTextStyle: GoogleFonts.inter(
          color: colors.text,
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
    );
  }
}

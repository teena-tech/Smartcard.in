import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, black }

class AppColors {
  // Fixed Colors
  static const Color primaryRed = Color(0xFFE50000);
  static const Color primaryRedHover = Color(0xFF990000);
  static const Color secondaryRed = Color(0xFF990000);
  static const Color redLight = Color(0xFFFFF0F0);
  static const Color primary = Color(0xFFE50000);
  static const Color primaryLight = Color(0xFFFF5252);
  static const Color primaryDark = Color(0xFFB71C1C);

  // Action Brand Colors
  static const Color callGreen = Color(0xFF10B981); // Emerald 500
  static const Color smsBlue = Color(0xFF3B82F6); // Blue 500
  static const Color whatsappGreen = Color(0xFF25D366); // WhatsApp Brand
  static const Color emailOrange = Color(0xFFF97316); // Orange 500
  static const Color favoriteGold = Color(0xFFF59E0B); // Amber 500
  static const Color deleteRed = Color(0xFFEF4444); // Red 500
  static const Color success = Color(0xFF10B981); // Emerald 500

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE50000), Color(0xFFFF5252)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dynamic Avatar Gradients
  static const List<List<Color>> avatarGradients = [
    [Color(0xFFE50000), Color(0xFFFF5252)], // Red
    [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Indigo to Purple
    [Color(0xFFEC4899), Color(0xFFF43F5E)], // Pink to Rose
    [Color(0xFF3B82F6), Color(0xFF06B6D4)], // Blue to Cyan
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
    [Color(0xFF8B5CF6), Color(0xFFD946EF)], // Purple to Fuchsia
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
    [Color(0xFFF97316), Color(0xFFEA580C)], // Orange
  ];
  
  // Theme-specific colors
  final Color backgroundStart;
  final Color backgroundEnd;
  final Color panel;
  final Color card;
  final Color section;
  final Color border;
  final Color text;
  final Color muted;
  final Color accentSoft;
  final Color menuBg;
  final Color danger;

  Color get accent => primaryRed;
  bool get isDark => text.computeLuminance() > 0.5;

  AppColors({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.panel,
    required this.card,
    required this.section,
    required this.border,
    required this.text,
    required this.muted,
    required this.accentSoft,
    required this.menuBg,
    required this.danger,
  });

  static AppColors of(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return AppColors(
          backgroundStart: const Color(0xFFFFF0F2), // Light Pinkish Red
          backgroundEnd: const Color(0xFFFFFFFF),
          panel: const Color(0xFFF4F6FC),
          card: const Color(0xFFFFFFFF),
          section: const Color(0xFFE9EDF6),
          border: const Color(0xFFD9DDEA),
          text: const Color(0xFF20263A),
          muted: const Color(0xFF8B8096),
          accentSoft: const Color(0x1FFA0000),
          menuBg: AppColors.primaryRed,
          danger: const Color(0xFF991B1B),
        );
      case AppThemeMode.dark:
        // Dark (soft dark) theme - deep blues/greys
        return AppColors(
          backgroundStart: const Color(0xFF2A3447),
          backgroundEnd: const Color(0xFF1A2231),
          panel: const Color(0xFF232D3D),
          card: const Color(0xFF2A374B),
          section: const Color(0xFF36445A),
          border: const Color(0xFF7B8CA7),
          text: const Color(0xFFF8FAFC),
          muted: const Color(0xFFC2CEDE),
          accentSoft: const Color(0x33FA0000),
          menuBg: const Color(0xFF18202F),
          danger: const Color(0xFFFECACA),
        );
      case AppThemeMode.black:
        // Pure black theme: deepest black backgrounds and panels
        return AppColors(
          backgroundStart: const Color(0xFF000000),
          backgroundEnd: const Color(0xFF000000),
          panel: const Color(0xFF000000),
          card: const Color(0xFF000000),
          section: const Color(0xFF0A0A0A),
          border: const Color(0xFF222222),
          text: const Color(0xFFFFFFFF),
          muted: const Color(0xFF9CA3AF),
          accentSoft: const Color(0x33FA0000),
          menuBg: const Color(0xFF000000),
          danger: const Color(0xFFFECACA),
        );
    }
  }

  // Legacy static accessors for compatibility (optional, can be refactored later)
  static const Color textMain = Color(0xFF20263A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color inputBackground = Color(0xFFF3F4F6);
  static const Color inputBorder = Color(0xFFE5E7EB);
  static const Color cardBackground = Colors.white;
  static const Color backgroundGradientStart = Color(0xFFFCFBFE);
  static const Color backgroundGradientEnd = Color(0xFFEEF2FF);
}

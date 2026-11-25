import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/data/models/app_theme_item.dart';

@immutable
class ThemeState {
  final AppThemeMode themeMode;
  final AppThemeItem currentTheme;
  final bool isFrontSelected;

  const ThemeState({
    this.themeMode = AppThemeMode.light,
    this.currentTheme = AppThemeItem.defaultTheme,
    this.isFrontSelected = true,
  });

  AppColors get colors => AppColors.of(themeMode);
  String get selectedThemeId => currentTheme.id;
  String get selectedFrontImage => currentTheme.frontImage;
  String get selectedBackImage => currentTheme.backImage;

  ThemeState copyWith({
    AppThemeMode? themeMode,
    AppThemeItem? currentTheme,
    bool? isFrontSelected,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      currentTheme: currentTheme ?? this.currentTheme,
      isFrontSelected: isFrontSelected ?? this.isFrontSelected,
    );
  }
}

class ThemeViewModel extends Notifier<ThemeState> {
  static const String _themeKey = 'scard_user_dashboard_theme';
  static const String _activeThemeIdKey = 'scard_active_theme_id';
  static const String _activeThemeFrontKey = 'scard_active_theme_front';
  static const String _activeThemeBackKey = 'scard_active_theme_back';
  static const String _activeThemeNameKey = 'scard_active_theme_name';
  static const String _activeThemeThumbKey = 'scard_active_theme_thumb';

  @override
  ThemeState build() {
    _loadTheme();
    return const ThemeState();
  }

  // Getters for convenience
  AppThemeMode get themeMode => state.themeMode;
  AppColors get colors => state.colors;
  AppThemeItem get currentTheme => state.currentTheme;
  String get selectedThemeId => state.selectedThemeId;
  String get selectedFrontImage => state.selectedFrontImage;
  String get selectedBackImage => state.selectedBackImage;
  bool get isFrontSelected => state.isFrontSelected;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load UI mode (light/dark/black)
    final themeIndex = prefs.getInt(_themeKey);
    AppThemeMode loadedMode = state.themeMode;
    if (themeIndex != null && themeIndex < AppThemeMode.values.length) {
      loadedMode = AppThemeMode.values[themeIndex];
    }

    // 2. Load Selected Card Theme
    final savedId = prefs.getString(_activeThemeIdKey);
    final savedFront = prefs.getString(_activeThemeFrontKey);
    final savedBack = prefs.getString(_activeThemeBackKey);
    final savedName = prefs.getString(_activeThemeNameKey);
    final savedThumb = prefs.getString(_activeThemeThumbKey);

    AppThemeItem loadedTheme = state.currentTheme;
    if (savedId != null && savedId.isNotEmpty && savedFront != null && savedFront.isNotEmpty) {
      loadedTheme = AppThemeItem(
        id: savedId,
        name: savedName ?? 'Custom Theme',
        frontImage: savedFront,
        backImage: savedBack ?? savedFront,
        thumbnail: savedThumb ?? savedFront,
        isDefault: false,
      );
    } else {
      loadedTheme = AppThemeItem.defaultTheme;
    }

    state = state.copyWith(
      themeMode: loadedMode,
      currentTheme: loadedTheme,
    );
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (state.themeMode == mode) return;
    state = state.copyWith(themeMode: mode);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  void toggleFrontBack(bool showFront) {
    if (state.isFrontSelected == showFront) return;
    state = state.copyWith(isFrontSelected: showFront);
  }

  Future<void> selectTheme(AppThemeItem theme) async {
    state = state.copyWith(currentTheme: theme);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeThemeIdKey, theme.id);
    await prefs.setString(_activeThemeFrontKey, theme.frontImage);
    await prefs.setString(_activeThemeBackKey, theme.backImage);
    await prefs.setString(_activeThemeNameKey, theme.name);
    await prefs.setString(_activeThemeThumbKey, theme.thumbnail);
  }
}

final themeViewModelProvider =
    NotifierProvider<ThemeViewModel, ThemeState>(ThemeViewModel.new);

/// Global alias


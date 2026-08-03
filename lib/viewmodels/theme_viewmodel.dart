import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../models/app_theme_item.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _themeKey = 'scard_user_dashboard_theme';
  static const String _activeThemeIdKey = 'scard_active_theme_id';
  static const String _activeThemeFrontKey = 'scard_active_theme_front';
  static const String _activeThemeBackKey = 'scard_active_theme_back';
  static const String _activeThemeNameKey = 'scard_active_theme_name';
  static const String _activeThemeThumbKey = 'scard_active_theme_thumb';
  
  AppThemeMode _themeMode = AppThemeMode.light;
  AppThemeItem _currentTheme = AppThemeItem.defaultTheme;
  bool _isFrontSelected = true;
  
  AppThemeMode get themeMode => _themeMode;
  AppColors get colors => AppColors.of(_themeMode);

  AppThemeItem get currentTheme => _currentTheme;
  String get selectedThemeId => _currentTheme.id;
  String get selectedFrontImage => _currentTheme.frontImage;
  String get selectedBackImage => _currentTheme.backImage;
  bool get isFrontSelected => _isFrontSelected;

  ThemeViewModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load UI mode (light/dark/black)
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null && themeIndex < AppThemeMode.values.length) {
      _themeMode = AppThemeMode.values[themeIndex];
    }

    // 2. Load Selected Card Theme
    final savedId = prefs.getString(_activeThemeIdKey);
    final savedFront = prefs.getString(_activeThemeFrontKey);
    final savedBack = prefs.getString(_activeThemeBackKey);
    final savedName = prefs.getString(_activeThemeNameKey);
    final savedThumb = prefs.getString(_activeThemeThumbKey);

    if (savedId != null && savedId.isNotEmpty && savedFront != null && savedFront.isNotEmpty) {
      _currentTheme = AppThemeItem(
        id: savedId,
        name: savedName ?? 'Custom Theme',
        frontImage: savedFront,
        backImage: savedBack ?? savedFront,
        thumbnail: savedThumb ?? savedFront,
        isDefault: false,
      );
    } else {
      _currentTheme = AppThemeItem.defaultTheme;
    }
    
    notifyListeners();
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }

  void toggleFrontBack(bool showFront) {
    if (_isFrontSelected == showFront) return;
    _isFrontSelected = showFront;
    notifyListeners();
  }

  Future<void> selectTheme(AppThemeItem theme) async {
    _currentTheme = theme;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeThemeIdKey, theme.id);
    await prefs.setString(_activeThemeFrontKey, theme.frontImage);
    await prefs.setString(_activeThemeBackKey, theme.backImage);
    await prefs.setString(_activeThemeNameKey, theme.name);
    await prefs.setString(_activeThemeThumbKey, theme.thumbnail);
  }
}

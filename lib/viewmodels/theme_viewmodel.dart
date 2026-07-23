import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _themeKey = 'scard_user_dashboard_theme';
  
  AppThemeMode _themeMode = AppThemeMode.light;
  
  AppThemeMode get themeMode => _themeMode;
  AppColors get colors => AppColors.of(_themeMode);

  ThemeViewModel() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    if (themeIndex != null) {
      _themeMode = AppThemeMode.values[themeIndex];
      notifyListeners();
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
  }
}

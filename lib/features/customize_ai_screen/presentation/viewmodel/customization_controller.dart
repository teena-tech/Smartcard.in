import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomCardProfile {
  String name;
  String selectedTemplate;
  String? backgroundImagePath;
  Color backgroundColor;
  Color textColor;
  Color overlayColor;
  double overlayOpacity;
  bool bgImageEnabled;
  bool bgColorEnabled;
  bool overlayEnabled;
  int templateIndex;

  // New properties for Text Settings
  Color nameColor;
  Color designationColor;
  String fontFamily;
  FontWeight fontWeight;
  double fontSize;
  double letterSpacing;
  TextAlign textAlign;

  // Theme Controls
  String themeStyle;

  CustomCardProfile({
    required this.name,
    this.selectedTemplate = "Card 1",
    this.backgroundImagePath,
    this.backgroundColor = const Color(0xFFFFA500),
    this.textColor = Colors.black,
    this.overlayColor = const Color(0xFF1976D2),
    this.overlayOpacity = 0.40,
    this.bgImageEnabled = true,
    this.bgColorEnabled = true,
    this.overlayEnabled = true,
    this.templateIndex = 30, // Displays as "31/34"

    this.nameColor = Colors.white,
    this.designationColor = Colors.white70,
    this.fontFamily = 'Poppins',
    this.fontWeight = FontWeight.w800,
    this.fontSize = 16.0,
    this.letterSpacing = 0.0,
    this.textAlign = TextAlign.center,

    this.themeStyle = 'Modern',
  });

  CustomCardProfile clone({String? newName}) {
    return CustomCardProfile(
      name: newName ?? "$name (Copy)",
      selectedTemplate: selectedTemplate,
      backgroundImagePath: backgroundImagePath,
      backgroundColor: backgroundColor,
      textColor: textColor,
      overlayColor: overlayColor,
      overlayOpacity: overlayOpacity,
      bgImageEnabled: bgImageEnabled,
      bgColorEnabled: bgColorEnabled,
      overlayEnabled: overlayEnabled,
      templateIndex: templateIndex,
      nameColor: nameColor,
      designationColor: designationColor,
      fontFamily: fontFamily,
      fontWeight: fontWeight,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      textAlign: textAlign,
      themeStyle: themeStyle,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'selectedTemplate': selectedTemplate,
    'backgroundImagePath': backgroundImagePath,
    'backgroundColor': backgroundColor.value,
    'textColor': textColor.value,
    'overlayColor': overlayColor.value,
    'overlayOpacity': overlayOpacity,
    'bgImageEnabled': bgImageEnabled,
    'bgColorEnabled': bgColorEnabled,
    'overlayEnabled': overlayEnabled,
    'templateIndex': templateIndex,
    'nameColor': nameColor.value,
    'designationColor': designationColor.value,
    'fontFamily': fontFamily,
    'fontWeightIndex': fontWeight.index,
    'fontSize': fontSize,
    'letterSpacing': letterSpacing,
    'textAlignIndex': textAlign.index,
    'themeStyle': themeStyle,
  };

  factory CustomCardProfile.fromJson(Map<String, dynamic> json) {
    return CustomCardProfile(
      name: json['name'] ?? 'Card',
      selectedTemplate: json['selectedTemplate'] ?? "Card 1",
      backgroundImagePath: json['backgroundImagePath'],
      backgroundColor: json['backgroundColor'] != null
          ? Color(json['backgroundColor'])
          : const Color(0xFFFFA500),
      textColor: json['textColor'] != null
          ? Color(json['textColor'])
          : Colors.black,
      overlayColor: json['overlayColor'] != null
          ? Color(json['overlayColor'])
          : const Color(0xFF1976D2),
      overlayOpacity: json['overlayOpacity']?.toDouble() ?? 0.40,
      bgImageEnabled: json['bgImageEnabled'] ?? true,
      bgColorEnabled: json['bgColorEnabled'] ?? true,
      overlayEnabled: json['overlayEnabled'] ?? true,
      templateIndex: json['templateIndex'] ?? 30,
      nameColor: json['nameColor'] != null
          ? Color(json['nameColor'])
          : Colors.white,
      designationColor: json['designationColor'] != null
          ? Color(json['designationColor'])
          : Colors.white70,
      fontFamily: json['fontFamily'] ?? 'Poppins',
      fontWeight: json['fontWeightIndex'] != null
          ? FontWeight.values[json['fontWeightIndex']]
          : FontWeight.w800,
      fontSize: json['fontSize']?.toDouble() ?? 16.0,
      letterSpacing: json['letterSpacing']?.toDouble() ?? 0.0,
      textAlign: json['textAlignIndex'] != null
          ? TextAlign.values[json['textAlignIndex']]
          : TextAlign.center,
      themeStyle: json['themeStyle'] ?? 'Modern',
    );
  }
}


@immutable
class CustomizationState {
  final List<CustomCardProfile> profiles;
  final int activeProfileIndex;
  final int version;

  const CustomizationState({
    this.profiles = const [],
    this.activeProfileIndex = 0,
    this.version = 0,
  });

  CustomCardProfile get activeProfile =>
      (profiles.isNotEmpty && activeProfileIndex < profiles.length && activeProfileIndex >= 0)
          ? profiles[activeProfileIndex]
          : CustomCardProfile(name: 'Default');

  CustomizationState copyWith({
    List<CustomCardProfile>? profiles,
    int? activeProfileIndex,
    int? version,
  }) {
    return CustomizationState(
      profiles: profiles ?? this.profiles,
      activeProfileIndex: activeProfileIndex ?? this.activeProfileIndex,
      version: version ?? (this.version + 1),
    );
  }
}

class CustomizationController extends Notifier<CustomizationState> {
  int _version = 0;

  @override
  CustomizationState build() {
    _initCustomization();
    return _buildState();
  }

  CustomizationState _buildState() {
    return CustomizationState(
      profiles: List.unmodifiable(_profiles),
      activeProfileIndex: _activeProfileIndex,
      version: _version,
    );
  }

  void _notify() {
    _version++;
    state = _buildState();
  }
  static const String _keyProfiles = 'cust_profiles_v2';
  static const int maxCards = 20;

  List<CustomCardProfile> _profiles = [CustomCardProfile(name: 'Card 1')];
  int _activeProfileIndex = 0;
  final int _totalTemplates = 34;
  bool _isSaving = false;

  // Getters
  List<CustomCardProfile> get profiles => _profiles;
  int get activeProfileIndex => _activeProfileIndex;
  CustomCardProfile get activeProfile => _profiles[_activeProfileIndex];

  // Legacy getters mapped to active profile to prevent breaking other screens temporarily
  String get selectedTemplate => activeProfile.selectedTemplate;
  String? get backgroundImagePath => activeProfile.backgroundImagePath;
  Color get backgroundColor => activeProfile.backgroundColor;
  Color get textColor => activeProfile.textColor;
  Color get overlayColor => activeProfile.overlayColor;
  double get overlayOpacity => activeProfile.overlayOpacity;
  bool get bgImageEnabled => activeProfile.bgImageEnabled;
  bool get bgColorEnabled => activeProfile.bgColorEnabled;
  bool get overlayEnabled => activeProfile.overlayEnabled;
  int get templateIndex => activeProfile.templateIndex;
  int get totalTemplates => _totalTemplates;
  bool get isSaving => _isSaving;

  void _initCustomization() {
    loadSettings();
  }

  // Card Management
  void setActiveProfile(int index) {
    if (index >= 0 && index < _profiles.length) {
      _activeProfileIndex = index;
      _notify();
    }
  }

  void addNewCard() {
    if (_profiles.length < maxCards) {
      _profiles.add(CustomCardProfile(name: 'Card ${_profiles.length + 1}'));
      _activeProfileIndex = _profiles.length - 1;
      _notify();
    }
  }

  // Note: Card deletion and duplication are handled via CardViewModel connected to Backend API.

  void renameCard(int index, String newName) {
    if (index >= 0 && index < _profiles.length && newName.trim().isNotEmpty) {
      _profiles[index].name = newName.trim();
      _notify();
    }
  }

  // Setters for active profile
  void setSelectedTemplate(String val) {
    activeProfile.selectedTemplate = val;
    _notify();
  }

  void setBackgroundImagePath(String? path) {
    activeProfile.backgroundImagePath = path;
    _notify();
  }

  void setBackgroundColor(Color color) {
    activeProfile.backgroundColor = color;
    _notify();
  }

  void setTextColor(Color color) {
    activeProfile.textColor = color;
    _notify();
  }

  void setOverlayColor(Color color) {
    activeProfile.overlayColor = color;
    _notify();
  }

  void setOverlayOpacity(double opacity) {
    activeProfile.overlayOpacity = opacity;
    _notify();
  }

  void setBgImageEnabled(bool enabled) {
    activeProfile.bgImageEnabled = enabled;
    _notify();
  }

  void setBgColorEnabled(bool enabled) {
    activeProfile.bgColorEnabled = enabled;
    _notify();
  }

  void setOverlayEnabled(bool enabled) {
    activeProfile.overlayEnabled = enabled;
    _notify();
  }

  // New Text Settings Setters
  void setNameColor(Color color) {
    activeProfile.nameColor = color;
    _notify();
  }

  void setDesignationColor(Color color) {
    activeProfile.designationColor = color;
    _notify();
  }

  void setFontFamily(String font) {
    activeProfile.fontFamily = font;
    _notify();
  }

  void setFontWeight(FontWeight weight) {
    activeProfile.fontWeight = weight;
    _notify();
  }

  void setFontSize(double size) {
    activeProfile.fontSize = size;
    _notify();
  }

  void setLetterSpacing(double spacing) {
    activeProfile.letterSpacing = spacing;
    _notify();
  }

  void setTextAlign(TextAlign align) {
    activeProfile.textAlign = align;
    _notify();
  }

  // Theme Setter
  void setThemeStyle(String style) {
    activeProfile.themeStyle = style;
    _notify();
  }

  void setTemplateIndex(int index) {
    if (index < 0) {
      activeProfile.templateIndex = 0;
    } else {
      activeProfile.templateIndex = index % _totalTemplates;
    }
    _notify();
  }

  void nextTemplate() {
    activeProfile.templateIndex =
        (activeProfile.templateIndex + 1) % _totalTemplates;
    _notify();
  }

  void prevTemplate() {
    activeProfile.templateIndex =
        (activeProfile.templateIndex - 1 + _totalTemplates) % _totalTemplates;
    _notify();
  }

  // Load from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = prefs.getString(_keyProfiles);
      if (profilesJson != null) {
        final List<dynamic> decoded = jsonDecode(profilesJson);
        if (decoded.isNotEmpty) {
          _profiles = decoded
              .map((e) => CustomCardProfile.fromJson(e))
              .toList();
        }
      }
      _notify();
    } catch (e) {
      debugPrint('Error loading customization settings: $e');
    }
  }

  // Save changes to SharedPreferences
  Future<bool> saveChanges() async {
    _isSaving = true;
    _notify();
    try {
      final prefs = await SharedPreferences.getInstance();
      final profilesJson = jsonEncode(
        _profiles.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_keyProfiles, profilesJson);

      _isSaving = false;
      _notify();
      return true;
    } catch (e) {
      debugPrint('Error saving customization settings: $e');
      _isSaving = false;
      _notify();
      return false;
    }
  }
}


final customizationControllerProvider =
    NotifierProvider<CustomizationController, CustomizationState>(CustomizationController.new);

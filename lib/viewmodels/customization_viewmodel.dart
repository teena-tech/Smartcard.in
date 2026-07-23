import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../repositories/theme_repository.dart';
import '../core/state/app_loading_service.dart';

class CustomizeViewModel extends ChangeNotifier {
  final ThemeRepository _themeRepository;
  
  CustomizeViewModel({required ThemeRepository themeRepository}) 
      : _themeRepository = themeRepository;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String? _successMessage;
  
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  String? get successMessage => _successMessage;

  // State
  Map<String, dynamic>? _themeData;
  List<dynamic> _backgroundImages = [];
  List<dynamic> _templates = [];

  Map<String, dynamic>? get themeData => _themeData;
  List<dynamic> get backgroundImages => _backgroundImages;
  List<dynamic> get templates => _templates;

  void clearMessages() {
    _error = null;
    _successMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  Future<void> fetchTheme(String userId, {int? workProfileId}) async {
    _setLoading(true);
    try {
      final scope = workProfileId != null && workProfileId > 0 
          ? {'work_profile_id': workProfileId} 
          : null;
          
      _themeData = await _themeRepository.getTheme(userId, scope: scope);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchBackgroundImages() async {
    try {
      _backgroundImages = await _themeRepository.listBackgroundImages();
    } catch (e) {
      debugPrint('Error fetching bg images: $e');
    }
  }

  Future<void> fetchTemplates() async {
    try {
      _templates = await _themeRepository.listTemplates();
    } catch (e) {
      debugPrint('Error fetching templates: $e');
    }
  }

  Future<bool> saveSolidColors(
    String userId, 
    Map<String, dynamic> payload, 
    {int? workProfileId}
  ) async {
    _setSaving(true);
    try {
      final scope = workProfileId != null && workProfileId > 0 
          ? {'work_profile_id': workProfileId} 
          : null;
          
      final result = await _themeRepository.saveSolidColors(userId, payload, scope: scope);
      if (result != null) {
        _themeData = result;
        _successMessage = 'Colors saved successfully';
        return true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setSaving(false);
    }
    return false;
  }

  Future<bool> uploadBackgroundImage(
    String userId, 
    String filePath, 
    String fileName, 
    {Uint8List? bytes, Map<String, dynamic>? payload, int? workProfileId}
  ) async {
    _setSaving(true);
    AppLoadingService.instance.startTask();
    try {
      final scope = workProfileId != null && workProfileId > 0 
          ? {'work_profile_id': workProfileId} 
          : null;
          
      final result = await _themeRepository.uploadBackgroundImage(
        userId, 
        fileName, 
        filePath: filePath,
        bytes: bytes,
        payload: payload, 
        scope: scope
      );
      if (result != null) {
        _themeData = result;
        _successMessage = 'Background image uploaded successfully';
        return true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setSaving(false);
      AppLoadingService.instance.endTask();
    }
    return false;
  }

  Future<bool> extractLogoColors(
    String userId, 
    String filePath, 
    String fileName, 
    {Uint8List? bytes, int? workProfileId}
  ) async {
    _setSaving(true);
    AppLoadingService.instance.startTask();
    try {
      final scope = workProfileId != null && workProfileId > 0 
          ? {'work_profile_id': workProfileId} 
          : null;
          
      final result = await _themeRepository.extractLogoColors(
        userId, 
        fileName, 
        filePath: filePath,
        bytes: bytes,
        scope: scope
      );
      if (result != null) {
        _themeData = result;
        _successMessage = 'Logo uploaded and theme colors extracted successfully';
        return true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setSaving(false);
      AppLoadingService.instance.endTask();
    }
    return false;
  }

  Future<bool> saveTemplate(
    String userId, 
    Map<String, dynamic> payload, 
    {int? workProfileId}
  ) async {
    _setSaving(true);
    try {
      final scope = workProfileId != null && workProfileId > 0 
          ? {'work_profile_id': workProfileId} 
          : null;
          
      final result = await _themeRepository.saveTemplate(userId, payload, scope: scope);
      if (result != null) {
        _themeData = result;
        _successMessage = 'Template saved successfully';
        return true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setSaving(false);
    }
    return false;
  }

  Future<bool> saveBackgroundSelection(
    String userId,
    Map<String, dynamic> payload, {
    int? workProfileId,
  }) async {
    _setSaving(true);
    try {
      final scope = workProfileId != null && workProfileId > 0
          ? {'work_profile_id': workProfileId}
          : null;

      final result = await _themeRepository.saveBackgroundImage(
        userId,
        payload,
        scope: scope,
      );
      if (result != null) {
        _themeData = result;
        _successMessage = 'Background updated successfully';
        return true;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _setSaving(false);
    }
    return false;
  }

  Future<bool> saveColorSelection(
    String userId,
    Map<String, dynamic> payload, {
    int? workProfileId,
  }) async {
    return saveSolidColors(
      userId,
      payload,
      workProfileId: workProfileId,
    );
  }
}

import 'package:flutter/foundation.dart';
import '../repositories/theme_repository.dart';

class CustomizeViewModel extends ChangeNotifier {
  final ThemeRepository _themeRepository = ThemeRepository();

  Map<String, dynamic>? themeData = {};
  List<dynamic> templates = [];
  List<dynamic> backgroundImages = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchTemplates() async {
    try {
      templates = await _themeRepository.listTemplates();
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchBackgroundImages() async {
    try {
      final rawImages = await _themeRepository.listBackgroundImages();
      // Deduplicate images by using a Set on their JSON representation or identifying key.
      // Assuming they are strings or maps with an identifier.
      final uniqueSet = <String>{};
      final uniqueImages = [];
      for (var img in rawImages) {
        final key = img.toString();
        if (!uniqueSet.contains(key)) {
          uniqueSet.add(key);
          uniqueImages.add(img);
        }
      }
      backgroundImages = uniqueImages;
      notifyListeners();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> fetchTheme(String userId, {int? workProfileId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      themeData = await _themeRepository.getTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveTemplate(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveTemplate(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> uploadBackgroundImage(
    String userId, 
    String url, 
    String filename, 
    {Uint8List? bytes, Map<String, dynamic>? payload, int? workProfileId}
  ) async {
    try {
      await _themeRepository.uploadBackgroundImage(
        userId, 
        filename, 
        filePath: url.isNotEmpty ? url : null, 
        bytes: bytes,
        payload: payload, 
        scope: {'work_profile_id': workProfileId}
      );
      await fetchTheme(userId, workProfileId: workProfileId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> saveBackgroundSelection(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveBackgroundImage(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> saveColorSelection(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveSolidColors(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> extractLogoColors(String userId, String url, String filename, {Uint8List? bytes, int? workProfileId}) async {
    try {
      await _themeRepository.extractLogoColors(
        userId, 
        filename, 
        filePath: url.isNotEmpty ? url : null,
        bytes: bytes, 
        scope: {'work_profile_id': workProfileId}
      );
      await fetchTheme(userId, workProfileId: workProfileId);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> clearBackground(String userId, {int? workProfileId}) async {
    try {
      await _themeRepository.clearBackground(userId, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}

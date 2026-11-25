import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/data/repositories/theme_repository.dart';


@immutable
class CustomizeUiState {
  final Map<String, dynamic>? themeData;
  final List<dynamic> templates;
  final List<dynamic> backgroundImages;
  final bool isLoading;
  final String? errorMessage;

  const CustomizeUiState({
    this.themeData = const {},
    this.templates = const [],
    this.backgroundImages = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  CustomizeUiState copyWith({
    Map<String, dynamic>? themeData,
    List<dynamic>? templates,
    List<dynamic>? backgroundImages,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomizeUiState(
      themeData: themeData ?? this.themeData,
      templates: templates ?? this.templates,
      backgroundImages: backgroundImages ?? this.backgroundImages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CustomizeViewModel extends Notifier<CustomizeUiState> {
  late final ThemeRepository _themeRepository = ThemeRepository();
  

  @override
  CustomizeUiState build() {
    return const CustomizeUiState();
  }

  CustomizeUiState _buildState() {
    return CustomizeUiState(
      themeData: themeData,
      templates: templates,
      backgroundImages: backgroundImages,
      isLoading: isLoading,
      errorMessage: errorMessage,
    );
  }

  void _notify() {
    state = _buildState();
  }
  

  Map<String, dynamic>? themeData = {};
  List<dynamic> templates = [];
  List<dynamic> backgroundImages = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> fetchTemplates() async {
    try {
      templates = await _themeRepository.listTemplates();
      _notify();
    } catch (e) {
      errorMessage = e.toString();
      _notify();
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
      _notify();
    } catch (e) {
      errorMessage = e.toString();
      _notify();
    }
  }

  Future<void> fetchTheme(String userId, {int? workProfileId}) async {
    isLoading = true;
    errorMessage = null;
    _notify();
    try {
      themeData = await _themeRepository.getTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<void> saveTemplate(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveTemplate(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      _notify();
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
      _notify();
      return false;
    }
  }

  Future<void> saveBackgroundSelection(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveBackgroundImage(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      _notify();
      rethrow;
    }
  }

  Future<void> saveColorSelection(String userId, Map<String, dynamic> payload, {int? workProfileId}) async {
    try {
      await _themeRepository.saveSolidColors(userId, payload, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      _notify();
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
      _notify();
      return false;
    }
  }

  Future<void> clearBackground(String userId, {int? workProfileId}) async {
    try {
      await _themeRepository.clearBackground(userId, scope: {'work_profile_id': workProfileId});
      await fetchTheme(userId, workProfileId: workProfileId);
    } catch (e) {
      errorMessage = e.toString();
      _notify();
      rethrow;
    }
  }
}


final customizeViewModelProvider =
    NotifierProvider<CustomizeViewModel, CustomizeUiState>(CustomizeViewModel.new);

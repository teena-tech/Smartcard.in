import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

class ThemeRepository {
  final DioClient _dioClient = DioClient();

  Map<String, dynamic> _normalizeScope(Map<String, dynamic>? scope) {
    final Map<String, dynamic> normalized = {};
    if (scope == null) return normalized;

    final workProfileId = scope['workProfileId'] ??
        scope['work_profile_id'] ??
        scope['user_work_profile_id'];

    if (workProfileId != null) {
      final parsed = int.tryParse(workProfileId.toString());
      if (parsed != null && parsed > 0) {
        normalized['work_profile_id'] = parsed;
      }
    }
    return normalized;
  }

  Future<Map<String, dynamic>?> getTheme(String userId, {Map<String, dynamic>? scope, int? workProfileId}) async {
    try {
      final combinedScope = scope ?? {};
      if (workProfileId != null) combinedScope['workProfileId'] = workProfileId;
      final queryParams = _normalizeScope(combinedScope);
      final response = await _dioClient.dio.get(
        ApiConfig.theme(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is Map<String, dynamic>) {
          final nestedTheme = data['theme'] ?? data['data'] ?? data['payload'];
          if (nestedTheme is Map) {
            return Map<String, dynamic>.from(nestedTheme);
          }
          return Map<String, dynamic>.from(data);
        }
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final nestedTheme = map['theme'] ?? map['data'] ?? map['payload'];
          if (nestedTheme is Map) {
            return Map<String, dynamic>.from(nestedTheme);
          }
          return map;
        }
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to fetch theme');
    }
  }

  Future<List<dynamic>> listBackgroundImages() async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.backgroundImages);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is List) return data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final key in ['images', 'background_images', 'backgroundImages', 'data', 'items', 'rows']) {
            final value = map[key];
            if (value is List) return value;
          }
        }
      }
      return [];
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to fetch background images');
    }
  }

  Future<Map<String, dynamic>?> saveSolidColors(
    String userId,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final response = await _dioClient.dio.post(
        ApiConfig.themeSolidColors(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: {
          ...payload,
          ...queryParams,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to save solid colors');
    }
  }

  Future<Map<String, dynamic>?> saveBackgroundImage(
    String userId,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final response = await _dioClient.dio.post(
        ApiConfig.themeBackground(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: {
          ...payload,
          ...queryParams,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to save background image');
    }
  }

  Future<Map<String, dynamic>?> uploadBackgroundImage(
    String userId,
    String fileName, {
    String? filePath,
    Uint8List? bytes,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final filePart = bytes != null
          ? MultipartFile.fromBytes(bytes, filename: fileName)
          : await MultipartFile.fromFile(filePath ?? '', filename: fileName);
      
      final formData = FormData.fromMap({
        'bg_image': filePart,
        'bg_image_upload': filePart,
        ...(payload ?? {}),
        ...queryParams,
      });

      final response = await _dioClient.dio.post(
        ApiConfig.themeBackgroundUpload(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to upload background image');
    }
  }

  Future<Map<String, dynamic>?> extractLogoColors(
    String userId,
    String fileName, {
    String? filePath,
    Uint8List? bytes,
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final filePart = bytes != null
          ? MultipartFile.fromBytes(bytes, filename: fileName)
          : await MultipartFile.fromFile(filePath ?? '', filename: fileName);
      
      final formData = FormData.fromMap({
        'logo': filePart,
        ...queryParams,
      });

      final response = await _dioClient.dio.post(
        ApiConfig.themeLogoColors(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to extract logo colors');
    }
  }

  Future<Map<String, dynamic>?> clearBackground(
    String userId, {
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final response = await _dioClient.dio.post(
        ApiConfig.clearBackground(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: queryParams,
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to clear background');
    }
  }

  Future<List<dynamic>> listTemplates() async {
    try {
      final response = await _dioClient.dio.get(ApiConfig.templates);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        if (data is List) return data;
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final key in ['templates', 'data', 'items', 'rows']) {
            final value = map[key];
            if (value is List) return value;
          }
        }
      }
      return [];
    } catch (e) {
      // Backend error (e.g. 500 operator does not exist: smallint = boolean)
      return [];
    }
  }


  Future<Map<String, dynamic>?> saveTemplate(
    String userId,
    Map<String, dynamic> payload, {
    Map<String, dynamic>? scope,
  }) async {
    try {
      final queryParams = _normalizeScope(scope);
      final response = await _dioClient.dio.post(
        ApiConfig.themeTemplate(userId),
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        data: {
          ...payload,
          ...queryParams,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw DioClient.getErrorMessage(e, 'Failed to save template');
    }
  }
}

import 'package:dio/dio.dart';
import 'dio_client.dart';

class ThemeService {
  final Dio _dio = DioClient().dio;

  Future<List<dynamic>> listBackgroundImages() async {
    try {
      final response = await _dio.get('/themes/background-images');
      return response.data['images'] ?? [];
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to fetch background images'));
    }
  }

  Future<Map<String, dynamic>> getTheme(String userId, {int? workProfileId}) async {
    try {
      final response = await _dio.get(
        '/themes/$userId',
        queryParameters: workProfileId != null ? {'work_profile_id': workProfileId} : null,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to fetch theme'));
    }
  }

  Future<void> saveBackgroundImage(String userId, Map<String, dynamic> data, {int? workProfileId}) async {
    try {
      await _dio.post(
        '/themes/$userId/background-image',
        data: data,
        queryParameters: workProfileId != null ? {'work_profile_id': workProfileId} : null,
      );
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to save background image'));
    }
  }

  Future<void> saveSolidColors(String userId, Map<String, dynamic> data, {int? workProfileId}) async {
    try {
      await _dio.post(
        '/themes/$userId/solid-colors',
        data: data,
        queryParameters: workProfileId != null ? {'work_profile_id': workProfileId} : null,
      );
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to save solid colors'));
    }
  }

  Future<Map<String, dynamic>> extractLogoColors(String userId, String path, String name, {int? workProfileId}) async {
    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(path, filename: name),
      });
      final response = await _dio.post(
        '/themes/$userId/extract-logo-colors',
        data: formData,
        queryParameters: workProfileId != null ? {'work_profile_id': workProfileId} : null,
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to extract logo colors'));
    }
  }
}

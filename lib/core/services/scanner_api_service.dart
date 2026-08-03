import 'package:dio/dio.dart';
import 'dio_client.dart';
import 'api_config.dart';

class ScannerApiService {
  ScannerApiService._();
  static final ScannerApiService instance = ScannerApiService._();

  final Dio _dio = DioClient().dio;

  /// List scanned contacts
  Future<Map<String, dynamic>> getContacts() async {
    try {
      final response = await _dio.get(ApiConfig.qrContacts);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        DioClient.getErrorMessage(e, 'Failed to fetch contacts.'),
      );
    }
  }

  /// Preview a scanned QR
  Future<Map<String, dynamic>> previewContact(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.post(
        ApiConfig.qrPreview,
        data: payload,
      );
      if (response.data != null && response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data != null && response.data['message'] != null) {
        throw Exception(response.data['message']);
      }
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['message']?.toString();
      if (serverMsg != null && serverMsg.isNotEmpty) {
        throw Exception(serverMsg);
      }
      throw Exception(DioClient.getErrorMessage(e, 'Failed to preview contact.'));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }

    throw Exception('Failed to preview contact.');
  }

  /// Save a scanned QR
  Future<Map<String, dynamic>> saveContact(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.post(ApiConfig.qrContacts, data: payload);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to save contact.'));
    }
  }

  /// Delete a saved scanned contact
  Future<Map<String, dynamic>> deleteContact(int contactId) async {
    try {
      final response = await _dio.delete(ApiConfig.qrDelete(contactId));
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(
        DioClient.getErrorMessage(e, 'Failed to delete contact.'),
      );
    }
  }
}

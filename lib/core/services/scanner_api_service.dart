import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

class ScannerApiService {
  ScannerApiService._();
  static final ScannerApiService instance = ScannerApiService._();

  final Dio _dio = DioClient().dio;

  /// List scanned contacts with pagination, high-scale delta sync, and transient retry
  Future<Map<String, dynamic>> getContacts({
    int page = 1,
    int limit = 50,
    String? since,
    String? source,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;
    while (attempts < maxAttempts) {
      attempts++;
      try {
        final query = <String, dynamic>{
          'page': page,
          'limit': limit,
          if (since != null && since.isNotEmpty) 'since': since,
          if (source != null && source.isNotEmpty) 'source': source,
        };
        final response = await _dio.get(
          ApiConfig.qrContacts,
          queryParameters: query,
        );
        return response.data as Map<String, dynamic>;
      } catch (e) {
        if (e is DioException && (e.response?.statusCode ?? 500) < 500 && e.response?.statusCode != null) {
          // Do not retry 4xx errors
          throw Exception(DioClient.getErrorMessage(e, 'Failed to fetch contacts.'));
        }
        if (attempts >= maxAttempts) {
          throw Exception(DioClient.getErrorMessage(e, 'Failed to fetch contacts.'));
        }
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
    throw Exception('Failed to fetch contacts.');
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

  /// Delete a saved scanned contact permanently by ID, phone, email, or name.
  /// The contactId param is the Flutter local id (may be a UUID string or a
  /// numeric string from the server). We resolve the numeric DB id for the
  /// URL path and always send phone/email/name in the body so the backend can
  /// match even when the path id is 0 (locally-created contacts).
  Future<Map<String, dynamic>> deleteContact(
    String contactId, {
    String? phone,
    String? email,
    String? name,
  }) async {
    try {
      // Use the numeric DB id when available; fall back to 0 so the backend
      // falls through to matching by phone / email / name in the DELETE body.
      final numericId = int.tryParse(contactId) ?? 0;
      final response = await _dio.delete(
        ApiConfig.qrDelete(numericId),
        data: {
          'id': contactId,
          // Only pass phone/email if numericId > 0 so the backend never deletes separate profiles sharing the same phone
          if (numericId > 0 && phone != null && phone.isNotEmpty) 'phone': phone,
          if (numericId > 0 && email != null && email.isNotEmpty) 'email': email,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final serverMsg = e.response?.data?['message']?.toString();
      throw Exception(serverMsg?.isNotEmpty == true
          ? serverMsg
          : DioClient.getErrorMessage(e, 'Failed to delete contact.'));
    } catch (e) {
      throw Exception(DioClient.getErrorMessage(e, 'Failed to delete contact.'));
    }
  }

  /// Batch match phone numbers against system database
  Future<List<dynamic>> matchPhoneContacts(List<String> phoneNumbers) async {
    if (phoneNumbers.isEmpty) return [];
    try {
      final response = await _dio.post(
        ApiConfig.matchPhones,
        data: {'phoneNumbers': phoneNumbers},
      );
      if (response.data != null && response.data['matchedContacts'] is List) {
        return response.data['matchedContacts'] as List;
      }
      return [];
    } catch (e) {
      debugPrint('Error in matchPhoneContacts: $e');
      return [];
    }
  }
}


import 'package:smartcard_flutter/core/network/dio_client.dart';
import 'package:smartcard_flutter/core/network/api_exceptions.dart';
import 'package:dio/dio.dart';

/// A base class providing common network functionality for all repositories.
/// It uses the singleton [DioClient] to get a configured [Dio] instance with
/// authentication headers and detailed request/response logging.
///
/// Subâ€‘classes can call [_handleResponse] to parse the response body and
/// [_handleError] to convert DioException into a userâ€‘friendly error message.
abstract class BaseRepository {
  final Dio _dio = DioClient().dio;

  /// Parses the successful response and returns the data part. Adjust this
  /// method if the API wraps data in a specific envelope.
  dynamic _handleResponse(Response response) {
    // Assuming the API returns JSON with a topâ€‘level "data" field.
    if (response.data is Map<String, dynamic>) {
      return response.data['data'] ?? response.data;
    }
    return response.data;
  }

  /// Converts a [DioException] to a readable error message, delegating to the
  /// helper defined in DioClient.
  String _handleError(DioException e) {
    return DioClient.getErrorMessage(e, 'An unexpected error occurred');
  }

  /// Helper for making GET requests.
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw ApiException(_handleError(e));
    }
  }

  /// Helper for POST requests.
  Future<dynamic> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.post(path, data: data, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw ApiException(_handleError(e));
    }
  }

  /// Helper for PUT requests.
  Future<dynamic> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.put(path, data: data, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw ApiException(_handleError(e));
    }
  }

  /// Helper for DELETE requests.
  Future<dynamic> delete(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.delete(path, queryParameters: queryParameters);
      return _handleResponse(response);
    } on DioException catch (e) {
      throw ApiException(_handleError(e));
    }
  }
}

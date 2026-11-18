import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';
import 'api_constants.dart';
import 'api_exceptions.dart';

class DioService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  DioService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ));

    _dio.interceptors.addAll([
      _authInterceptor(),
      _retryInterceptor(),
      LogInterceptor(responseBody: true, requestBody: true),
    ]);
  }

  Dio get client => _dio;

  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Dynamically set baseUrl to pick up changes during hot-reloads
        options.baseUrl = ApiConstants.baseUrl;

        // Universal cache buster for ALL requests to prevent aggressive CORS preflight caching
        options.queryParameters['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();

        // Extract auth token from secure storage if we need a custom token header.
        // React's credentials: 'include' relies on cookies.
        // If the backend requires a Bearer token or CSRF token, we attach it here.
        final csrfToken = await _storage.read(key: 'csrf_token');
        if (csrfToken != null && _isStateChangingMethod(options.method)) {
          options.headers['X-CSRF-Token'] = csrfToken;
        }

        // Attach Authorization token if available
        final authToken = await _storage.read(key: 'auth_token');
        if (authToken != null) {
          options.headers['Authorization'] = 'Bearer $authToken';
        }

        // Attach session id if available (backend may require both auth token and session header)
        final sessionId = await _storage.read(key: 'session_id');
        if (sessionId != null) {
          options.headers['x-user-session'] = sessionId;
        }

        // Attach card API key for backend routes
        options.headers['x-card-api-key'] = ApiConfig.cardApiKey;

        return handler.next(options);
      },
      onResponse: (response, handler) async {
        // Save cookies/CSRF from headers if provided by the backend
        final setCookieHeader = response.headers.map['set-cookie'];
        if (setCookieHeader != null) {
          for (var cookie in setCookieHeader) {
            if (cookie.contains('csrf_token')) {
              // Extract CSRF token and save it
              final token = _extractCookieValue(cookie, 'csrf_token');
              if (token != null) {
                await _storage.write(key: 'csrf_token', value: token);
              }
            }
          }
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: UnauthorizedException(),
            ),
          );
        }
        
        final errorMessage = _extractErrorMessage(e);
        
        if (_isNetworkError(e)) {
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: NetworkException(),
            ),
          );
        }
        
        if (e.response?.statusCode == 404) {
          return handler.reject(
            DioException(
              requestOptions: e.requestOptions,
              error: NotFoundException(errorMessage ?? 'Endpoint not found. Restart backend server and retry.'),
            ),
          );
        }

        return handler.reject(
          DioException(
            requestOptions: e.requestOptions,
            error: ApiException(errorMessage ?? 'Request failed', statusCode: e.response?.statusCode),
          ),
        );
      },
    );
  }

  Interceptor _retryInterceptor() {
    return InterceptorsWrapper(
      onError: (DioException e, handler) async {
        // Retry logic for GET, HEAD, OPTIONS matching API_RETRY_ATTEMPTS
        final method = e.requestOptions.method.toUpperCase();
        if (['GET', 'HEAD', 'OPTIONS'].contains(method) && _isNetworkError(e)) {
          int retryCount = e.requestOptions.extra['retry_count'] ?? 0;
          if (retryCount < 2) {
            retryCount++;
            e.requestOptions.extra['retry_count'] = retryCount;
            await Future.delayed(Duration(milliseconds: 250 * retryCount));
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (err) {
              return handler.next(err is DioException ? err : e);
            }
          }
        }
        return handler.next(e);
      },
    );
  }

  bool _isStateChangingMethod(String method) {
    final m = method.toUpperCase();
    return !['GET', 'HEAD', 'OPTIONS'].contains(m);
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.error is SocketException;
  }

  String? _extractErrorMessage(DioException e) {
    if (e.response?.data is Map<String, dynamic>) {
      final data = e.response!.data as Map<String, dynamic>;
      return data['message'] ?? data['error'];
    }
    return null;
  }

  String? _extractCookieValue(String cookieString, String key) {
    final parts = cookieString.split(';');
    for (var part in parts) {
      final trimmed = part.trim();
      if (trimmed.startsWith('$key=')) {
        return trimmed.substring(key.length + 1);
      }
    }
    return null;
  }
}

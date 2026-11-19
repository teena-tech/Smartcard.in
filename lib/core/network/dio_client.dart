import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart' as legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_config.dart';
import '../services/telemetry_service.dart';
import '../../viewmodels/message_viewmodel.dart';
import '../providers/app_riverpod_providers.dart';

class DioClient {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();
  bool _isHandlingUnauthorized = false;

  static const Set<String> _sensitiveKeys = {
    'authorization',
    'x-user-session',
    'x-api-key',
    'x-card-api-key',
    'x-agent-session',
    'otp',
    'token',
    'session_id',
    'verification_token',
    'password',
    'phone',
    'mobile',
    'full_phone',
    'whatsapp_number',
    'email',
  };

  dynamic _redactSensitive(dynamic value) {
    if (value is Map) {
      final redacted = <String, dynamic>{};
      value.forEach((k, v) {
        final keyStr = k.toString();
        if (_sensitiveKeys.contains(keyStr.toLowerCase())) {
          redacted[keyStr] = '[REDACTED]';
        } else {
          redacted[keyStr] = _redactSensitive(v);
        }
      });
      return redacted;
    }
    if (value is List) {
      return value.map(_redactSensitive).toList();
    }
    return value;
  }

  DioClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (!kIsWeb) 'User-Agent': 'SmartCardFlutterApp/1.0',
      },
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    // ── Auth + debug logging interceptor ───────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Dynamically set baseUrl to pick up changes during hot-reloads
          options.baseUrl = ApiConfig.baseUrl;

          // Apply cache buster on GET requests only
          if (options.method.toUpperCase() == 'GET') {
            options.queryParameters['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();
          }

          if (kDebugMode) {
            debugPrint('========== REQUEST ==========');
            debugPrint('URL: ${options.uri}');
            debugPrint('Method: ${options.method}');
            debugPrint('Headers: ${_redactSensitive(options.headers)}');
            debugPrint('Data: ${options.data is FormData ? '[FormData]' : _redactSensitive(options.data)}');
            debugPrint('===============================');
          }

          // Add User Auth Headers from secure storage (Web falls back to SharedPreferences)
          String? token;
          String? sessionId;
          try {
            token = await _storage.read(key: 'auth_token');
            sessionId = await _storage.read(key: 'session_id');
          } catch (e) {
            if (kDebugMode) debugPrint('Error reading secure storage: $e');
          }

          if (kIsWeb && (token == null || sessionId == null)) {
            try {
              final prefs = await SharedPreferences.getInstance();
              final rawTok = prefs.getString('auth_token');
              final rawSess = prefs.getString('session_id');
              token ??= rawTok != null ? _decodeWebToken(rawTok) : null;
              sessionId ??= rawSess != null ? _decodeWebToken(rawSess) : null;
            } catch (e) {
              if (kDebugMode) debugPrint('Error reading web storage fallback: $e');
            }
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (sessionId != null) {
            options.headers['x-user-session'] = sessionId;
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('========== RESPONSE ==========');
            debugPrint('URL: ${response.requestOptions.uri}');
            debugPrint('Status Code: ${response.statusCode}');
            debugPrint('Data: ${_redactSensitive(response.data)}');
            debugPrint('================================');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            debugPrint('========== ERROR ==========');
            debugPrint('URL: ${e.requestOptions.uri}');
            debugPrint('Status Code: ${e.response?.statusCode}');
            debugPrint('Response Data: ${_redactSensitive(e.response?.data)}');
            debugPrint('Error: ${e.error}');
            debugPrint('Message: ${e.message}');
            debugPrint('=============================');
          }

          // Report API failure to central telemetry (avoid recursive loop on telemetry endpoint)
          if (!e.requestOptions.path.contains('telemetry/app-error')) {
            TelemetryService.instance.reportDioError(e);
          }
          
          final reqPath = e.requestOptions.path.toLowerCase();
          final isAppBackend = e.requestOptions.uri.toString().startsWith(ApiConfig.baseUrl);

          if (e.response?.statusCode == 401 &&
              isAppBackend &&
              !reqPath.contains('login') &&
              !reqPath.contains('preview') &&
              !_isHandlingUnauthorized) {
            final hasAuthToken = e.requestOptions.headers.containsKey('Authorization') &&
                e.requestOptions.headers['Authorization']?.toString().startsWith('Bearer ') == true;

            if (hasAuthToken) {
              _isHandlingUnauthorized = true;
              try {
                final storage = const FlutterSecureStorage();
                await storage.delete(key: 'auth_token');
                await storage.delete(key: 'session_id');
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('auth_token');
                await prefs.remove('session_id');
              } catch (_) {}
              
              // Stop background message polling
              try {
                final context = navigatorKey.currentContext;
                if (context != null) {
                  final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
                      context.findAncestorWidgetOfExactType<ProviderScope>() != null;
                  if (hasScope) {
                    ProviderScope.containerOf(context, listen: false).read(messageViewModelProvider).stopPolling();
                  } else {
                    legacy.Provider.of<MessageViewModel>(context, listen: false).stopPolling();
                  }
                }
              } catch (_) {}
              
              // Redirect to Login page and clear all stacks
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);

              // Cooldown to reset flag
              Future.delayed(const Duration(seconds: 4), () {
                _isHandlingUnauthorized = false;
              });
            }
          }
          
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<void> saveTokens(String token, String sessionId) async {
    try {
      await _storage.write(key: 'auth_token', value: token);
      await _storage.write(key: 'session_id', value: sessionId);
    } catch (e) {
      if (kDebugMode) debugPrint('Error writing secure storage tokens: $e');
    }
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _encodeWebToken(token));
        await prefs.setString('session_id', _encodeWebToken(sessionId));
      } catch (e) {
        if (kDebugMode) debugPrint('Error writing web fallback tokens: $e');
      }
    } else {
      // Remove any legacy plaintext tokens from SharedPreferences on mobile
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('session_id');
      } catch (_) {}
    }
  }

  static String _encodeWebToken(String value) => base64Encode(utf8.encode('scard_sec_$value'));
  static String _decodeWebToken(String encoded) {
    try {
      final decoded = utf8.decode(base64Decode(encoded));
      return decoded.startsWith('scard_sec_') ? decoded.substring(10) : encoded;
    } catch (_) {
      return encoded;
    }
  }

  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'session_id');
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing secure storage tokens: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('session_id');
    } catch (e) {
      if (kDebugMode) debugPrint('Error clearing shared preferences tokens: $e');
    }
  }

  static String getErrorMessage(dynamic e, String defaultMessage) {
    if (e is DioException) {
      if (kDebugMode) {
        debugPrint('----------------------------------------------------');
        debugPrint('SMART CARD NETWORK ERROR DIAGNOSTICS:');
        debugPrint('  Base URL: ${ApiConfig.baseUrl}');
        debugPrint('  Exception Type: ${e.type}');
        debugPrint('  Error Object: ${e.error}');
        debugPrint('  Underlying Message: ${e.message}');
        debugPrint('----------------------------------------------------');
      }

      if (e.response != null) {
        if (e.response?.statusCode == 429) {
          final retryAfter = e.response?.headers.value('retry-after');
          if (retryAfter != null && retryAfter.isNotEmpty) {
            return 'Too many attempts. For security reasons, please wait $retryAfter seconds before trying again.';
          }
          return 'Too many attempts. For security reasons, please wait a few minutes before trying again.';
        }

        if (e.response?.statusCode == 413) {
          return 'The selected file is too large. Please select a smaller photo or compress it before uploading.';
        }

        final data = e.response?.data;
        if (data is Map) {
          if (data['message'] != null) return data['message'].toString();
          if (data['error'] != null) return data['error'].toString();
          if (data['errors'] != null) {
            final errs = data['errors'];
            if (errs is List) {
              return errs.map((e) => e.toString()).join('\n');
            } else if (errs is Map) {
              return errs.values.map((v) => v.toString()).join('\n');
            }
          }
          return defaultMessage;
        } else if (data is String && data.isNotEmpty) {
          final trimmed = data.trim();
          if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html') || trimmed.startsWith('<HTML')) {
            return 'Server error (status code: ${e.response?.statusCode})';
          }
          return trimmed;
        }
        return 'Server error (status code: ${e.response?.statusCode})';
      }

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. The server took too long to respond. Please try again.';
      }

      // Check for SocketException, Host Lookup Failures, or Connection Refused
      final errorStr = e.error?.toString() ?? '';
      final messageStr = e.message?.toString() ?? '';

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown ||
          errorStr.contains('SocketException') ||
          messageStr.contains('SocketException') ||
          errorStr.contains('XMLHttpRequest') ||
          messageStr.contains('XMLHttpRequest')) {
        
        if (errorStr.contains('XMLHttpRequest') || messageStr.contains('XMLHttpRequest')) {
          return 'Browser blocked request (CORS). Run in Chrome with web security disabled, or enable CORS on your backend server.';
        }
        if (errorStr.contains('Failed host lookup') || messageStr.contains('Failed host lookup')) {
          return 'Server not found. Please check your internet connection or the server URL.';
        }
        if (errorStr.contains('Connection refused') || messageStr.contains('Connection refused')) {
          if (ApiConfig.useLocalBackend) {
            return 'Connection refused to local server. Make sure your backend server is running and accessible on port 5000.';
          }
          return 'Connection refused by the server. The server might be down. Please try again later.';
        }
        if (ApiConfig.useLocalBackend) {
          return 'Unable to connect to local server. If testing on a physical device, ensure you are using your computer\'s local IP instead of localhost.';
        }
        return 'Unable to connect to the server. Please check your internet connection.';
      }
    }
    return defaultMessage;
  }
}

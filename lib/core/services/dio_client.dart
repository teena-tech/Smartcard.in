import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'api_config.dart';
import '../state/app_loading_service.dart';
import '../../viewmodels/message_viewmodel.dart';

class DioClient {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio _dio;
  final _storage = const FlutterSecureStorage();

  DioClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (!kIsWeb) 'User-Agent': 'SmartCardFlutterApp/1.0',
      },
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
    ));

    // ── Global loading interceptor removed ─────────────────────────────────
    // Loading overlay should only be triggered manually by ViewModels
    // for specific actions like photo upload, login, and logout.


    // ── Auth + logging interceptor ─────────────────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Dynamically set baseUrl to pick up changes during hot-reloads
          options.baseUrl = ApiConfig.baseUrl;

          // Universal cache buster for ALL requests to prevent aggressive CORS preflight caching
          options.queryParameters['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();
          
          debugPrint('========== REQUEST ==========');
          debugPrint('URL: ${options.uri}');
          debugPrint('Method: ${options.method}');
          
          final sanitizedHeaders = {...options.headers};
          final keysToRedact = ['Authorization', 'x-user-session', 'x-api-key', 'x-agent-session'];
          for (var key in keysToRedact) {
            if (sanitizedHeaders.containsKey(key)) {
              sanitizedHeaders[key] = '[REDACTED]';
            }
          }
          debugPrint('Headers: $sanitizedHeaders');
          debugPrint('Data: ${options.data}');
          debugPrint('===============================');
          
          // Add User Auth Headers
          String? token;
          String? sessionId;
          try {
            token = await _storage.read(key: 'auth_token');
            sessionId = await _storage.read(key: 'session_id');
          } catch (e) {
            debugPrint('Error reading secure storage: $e');
          }

          // Fallback to shared preferences if secure storage returns null or fails
          if (token == null || sessionId == null) {
            try {
              final prefs = await SharedPreferences.getInstance();
              token ??= prefs.getString('auth_token');
              sessionId ??= prefs.getString('session_id');
            } catch (e) {
              debugPrint('Error reading shared preferences fallback: $e');
            }
          }

          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (sessionId != null) {
            options.headers['x-user-session'] = sessionId;
          }

          // Inject card API key for ALL backend routes
          options.headers['x-card-api-key'] = ApiConfig.cardApiKey;

          // Optionally, add Agent Auth Headers if calling /api/agents/*
          if (options.path.startsWith('/api/agents') ||
              options.path.startsWith('/agents')) {
            String? agentId;
            String? agentSession;
            try {
              agentId = await _storage.read(key: 'agent_id');
              agentSession = await _storage.read(key: 'agent_session');
            } catch (e) {
              debugPrint('Error reading agent secure storage: $e');
            }

            if (agentId == null || agentSession == null) {
              try {
                final prefs = await SharedPreferences.getInstance();
                agentId ??= prefs.getString('agent_id');
                agentSession ??= prefs.getString('agent_session');
              } catch (_) {}
            }

            if (agentId != null) {
              options.headers['x-agent-id'] = agentId;
            }
            if (agentSession != null) {
              options.headers['x-agent-session'] = agentSession;
            }
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('========== RESPONSE ==========');
          debugPrint('URL: ${response.requestOptions.uri}');
          debugPrint('Status Code: ${response.statusCode}');
          debugPrint('Data: ${response.data}');
          debugPrint('================================');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          debugPrint('========== ERROR ==========');
          debugPrint('URL: ${e.requestOptions.uri}');
          debugPrint('Status Code: ${e.response?.statusCode}');
          debugPrint('Response Data: ${e.response?.data}');
          debugPrint('Error: ${e.error}');
          debugPrint('Message: ${e.message}');
          debugPrint('=============================');
          
          final reqPath = e.requestOptions.path.toLowerCase();
          final isAppBackend = e.requestOptions.uri.toString().startsWith(ApiConfig.baseUrl);

          if (e.response?.statusCode == 401 &&
              isAppBackend &&
              !reqPath.contains('login') &&
              !reqPath.contains('preview')) {
            final hasAuthToken = e.requestOptions.headers.containsKey('Authorization') &&
                e.requestOptions.headers['Authorization']?.toString().startsWith('Bearer ') == true;

            if (hasAuthToken) {
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
                  Provider.of<MessageViewModel>(context, listen: false).stopPolling();
                }
              } catch (_) {}
              
              // Redirect to Login page and clear all stacks
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
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
      debugPrint('Error writing secure storage tokens: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('session_id', sessionId);
    } catch (e) {
      debugPrint('Error writing shared preferences tokens: $e');
    }
  }

  Future<void> clearTokens() async {
    try {
      await _storage.delete(key: 'auth_token');
      await _storage.delete(key: 'session_id');
      await _storage.delete(key: 'agent_id');
      await _storage.delete(key: 'agent_session');
    } catch (e) {
      debugPrint('Error clearing secure storage tokens: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('session_id');
      await prefs.remove('agent_id');
      await prefs.remove('agent_session');
    } catch (e) {
      debugPrint('Error clearing shared preferences tokens: $e');
    }
  }

  static String getErrorMessage(dynamic e, String defaultMessage) {
    if (e is DioException) {
      // Print detailed error to console to diagnose exactly why the connection is failing
      debugPrint('----------------------------------------------------');
      debugPrint('🚨 SMART CARD NETWORK ERROR DIAGNOSTICS:');
      debugPrint('  Base URL: ${ApiConfig.baseUrl}');
      debugPrint('  Exception Type: ${e.type}');
      debugPrint('  Error Object: ${e.error}');
      debugPrint('  Underlying Message: ${e.message}');
      debugPrint('----------------------------------------------------');

      if (e.response != null) {
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

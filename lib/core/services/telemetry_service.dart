import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../network/api_config.dart';

/// Central Telemetry & Crash Reporting Service for Flutter App.
/// Captures unhandled UI errors, async exceptions, and network failures,
/// and silently forwards them to the backend admin error log system.
class TelemetryService {
  static final TelemetryService instance = TelemetryService._internal();
  factory TelemetryService() => instance;

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));
  final _storage = const FlutterSecureStorage();

  // Deduplication & Rate Limiting
  final Map<String, int> _recentErrorTimestamps = {};
  final List<int> _reportTimestampsInWindow = [];
  static const int _dedupWindowMs = 15000; // 15 seconds
  static const int _maxReportsPerMinute = 10;

  // Offline retry queue (in-memory buffer, max 20)
  final List<Map<String, dynamic>> _offlineQueue = [];
  bool _isFlushingQueue = false;

  TelemetryService._internal();

  /// Initialize connectivity listener to automatically flush queued errors when online.
  void init() {
    try {
      Connectivity().onConnectivityChanged.listen((results) {
        final isConnected = results.any((r) => r != ConnectivityResult.none);
        if (isConnected && _offlineQueue.isNotEmpty) {
          flushQueue();
        }
      });
    } catch (_) {
      // Ignore if connectivity listener cannot be initialized
    }
  }

  /// Report a Flutter framework rendering or widget error.
  void reportFlutterError(FlutterErrorDetails details) {
    final exceptionStr = details.exception.toString();
    final stackStr = details.stack?.toString() ?? '';
    final screenOrContext = details.context?.toDescription() ?? 'FlutterWidget';

    unawaited(reportError(
      errorMessage: exceptionStr,
      exceptionClass: details.exception.runtimeType.toString(),
      screenName: screenOrContext,
      stackTrace: stackStr,
      severity: 'critical',
    ));
  }

  /// Report an unhandled asynchronous or platform error.
  void reportPlatformError(Object error, StackTrace stack) {
    unawaited(reportError(
      errorMessage: error.toString(),
      exceptionClass: error.runtimeType.toString(),
      screenName: 'PlatformAsync',
      stackTrace: stack.toString(),
      severity: 'critical',
    ));
  }

  /// Report a Dio HTTP network failure.
  void reportDioError(DioException dioError) {
    // Ignore user cancellations
    if (dioError.type == DioExceptionType.cancel) {
      return;
    }

    final statusCode = dioError.response?.statusCode ?? 0;
    // Don't report normal 401s if user is just logging out
    final uri = dioError.requestOptions.uri.toString();
    final severity = (statusCode >= 500 || statusCode == 0) ? 'critical' : 'important';

    final networkInfo = <String, dynamic>{
      'failed_endpoint': uri,
      'http_status': statusCode,
      'method': dioError.requestOptions.method,
      'error_type': dioError.type.toString(),
    };

    unawaited(reportError(
      errorMessage: 'HTTP ${statusCode > 0 ? statusCode : 'Network'}: ${dioError.message ?? dioError.error?.toString() ?? 'Dio error'}',
      exceptionClass: 'DioException',
      screenName: 'API: ${dioError.requestOptions.path}',
      stackTrace: dioError.stackTrace.toString(),
      severity: severity,
      networkInfo: networkInfo,
      statusCode: statusCode > 0 ? statusCode : 500,
    ));
  }

  /// Core reporting method. Fire-and-forget, never throws or blocks UI.
  Future<void> reportError({
    required String errorMessage,
    String? exceptionClass,
    String? screenName,
    String? stackTrace,
    String severity = 'critical',
    Map<String, dynamic>? networkInfo,
    int? statusCode,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      // 1. Deduplication check: Avoid flooding if same error fires in a loop
      final dedupKey = '${exceptionClass ?? ''}_${errorMessage.trim()}';
      final lastReported = _recentErrorTimestamps[dedupKey] ?? 0;
      if (now - lastReported < _dedupWindowMs) {
        return; // Skip duplicate within window
      }
      _recentErrorTimestamps[dedupKey] = now;

      // Clean old entries from recent map
      _recentErrorTimestamps.removeWhere((_, time) => now - time > _dedupWindowMs);

      // 2. Global Rate Limiter: Max N reports per minute
      _reportTimestampsInWindow.removeWhere((time) => now - time > 60000);
      if (_reportTimestampsInWindow.length >= _maxReportsPerMinute) {
        return; // Rate limit reached
      }
      _reportTimestampsInWindow.add(now);

      // 3. Collect device context
      final deviceInfo = _getDeviceInfo();

      // 4. Retrieve optional logged-in user context
      final userContext = await _getUserContext();

      // 5. Construct payload
      final payload = <String, dynamic>{
        'source': 'flutter_mobile',
        'severity': severity,
        'error_message': _sanitize(errorMessage, 2048),
        'exception_class': exceptionClass ?? 'Error',
        'screen_name': _sanitize(screenName ?? 'Unknown', 512),
        'stack_trace': _sanitize(stackTrace ?? '', 16384),
        'device_info': deviceInfo,
        'network_info': networkInfo ?? {},
        'user_context': userContext,
        'status_code': statusCode ?? 500,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      // 6. Attempt transmission
      await _sendPayload(payload);
    } catch (_) {
      // Intentionally swallowed: Crash reporting must NEVER crash the application
    }
  }

  /// Sends payload to backend, queues locally if failed/offline.
  Future<void> _sendPayload(Map<String, dynamic> payload) async {
    final endpoint = '${ApiConfig.baseUrl}/api/telemetry/app-error';

    try {
      final response = await _dio.post(
        endpoint,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        _enqueueOffline(payload);
      }
    } catch (_) {
      _enqueueOffline(payload);
    }
  }

  /// Enqueues error locally for later dispatch when internet returns.
  void _enqueueOffline(Map<String, dynamic> payload) {
    if (_offlineQueue.length >= 20) {
      _offlineQueue.removeAt(0); // Evict oldest
    }
    _offlineQueue.add(payload);
  }

  /// Flushes any pending offline queued errors.
  Future<void> flushQueue() async {
    if (_isFlushingQueue || _offlineQueue.isEmpty) return;
    _isFlushingQueue = true;

    try {
      final itemsToSend = List<Map<String, dynamic>>.from(_offlineQueue);
      _offlineQueue.clear();

      for (final item in itemsToSend) {
        try {
          final endpoint = '${ApiConfig.baseUrl}/api/telemetry/app-error';
          await _dio.post(endpoint, data: item);
        } catch (_) {
          // Put back if still failing
          _enqueueOffline(item);
          break;
        }
      }
    } finally {
      _isFlushingQueue = false;
    }
  }

  Map<String, dynamic> _getDeviceInfo() {
    return {
      'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
      'os_version': kIsWeb ? 'Browser' : Platform.operatingSystemVersion,
      'is_release': kReleaseMode,
      'is_debug': kDebugMode,
    };
  }

  Future<Map<String, dynamic>> _getUserContext() async {
    try {
      final sessionId = await _storage.read(key: 'session_id');
      final userId = await _storage.read(key: 'user_id');
      return {
        if (userId != null) 'user_id': userId,
        if (sessionId != null) 'session_id': sessionId,
      };
    } catch (_) {
      return {};
    }
  }

  String _sanitize(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return value.substring(0, maxLength);
  }
}

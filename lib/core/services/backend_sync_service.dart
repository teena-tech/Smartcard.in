import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dio_client.dart';
import '../database/hive_database.dart';
import '../../models/scanned_contact_model.dart';
import 'api_config.dart';

class BackendSyncService {
  static final BackendSyncService _instance = BackendSyncService._internal();
  factory BackendSyncService() => _instance;

  final Dio _dio = DioClient().dio;
  bool _isSyncing = false;

  BackendSyncService._internal();

  /// Starts listening to connectivity changes to trigger automatic syncs.
  void initConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.isNotEmpty && results.first != ConnectivityResult.none) {
        debugPrint(
          '🌐 Internet restored. Checking offline contacts sync queue...',
        );
        syncPendingContacts();
      }
    });
  }

  /// Syncs all locally queued contacts that are in 'pending' status.
  Future<void> syncPendingContacts() async {
    if (_isSyncing) return;

    final pending = HiveDatabase.getPendingContacts();
    if (pending.isEmpty) {
      debugPrint('📬 Offline sync queue is empty. Nothing to sync.');
      return;
    }

    _isSyncing = true;
    debugPrint(
      '🔄 Found ${pending.length} pending contacts in sync queue. Syncing now...',
    );

    for (var contact in pending) {
      try {
        final success = await uploadContact(contact);
        if (success) {
          await HiveDatabase.updateSyncStatus(contact.id, 'synced');
        }
      } catch (e) {
        debugPrint('🚨 Failed to sync contact ${contact.name}: $e');
        // Stop current sync batch, retry on next network change or manual trigger
        break;
      }
    }

    _isSyncing = false;
  }

  /// Uploads a single scanned contact to the backend REST API.
  ///
  /// Throws an [Exception] with a human-readable message on failure so the
  /// caller can surface it to the user (replacing the generic "Unknown API
  /// error" text that appeared previously).
  Future<bool> uploadContact(ScannedContactModel contact) async {
    try {
      // ── Resolve user_id from secure storage (with SharedPreferences fallback) ─
      const storage = FlutterSecureStorage();
      String? userId = await storage.read(key: 'user_id');
      if (userId == null || userId.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          userId = prefs.getString('user_id');
        } catch (_) {}
      }
      debugPrint('📤 BackendSync: resolved userId=$userId');

      // ── Flat payload matching backend DB table columns exactly ──────────────
      // Using a flat structure prevents "Column count doesn't match value count"
      // SQL errors that occurred when nested arrays were included in the body.
      final payload = <String, dynamic>{
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'name': contact.name,
        'company': contact.company,
        'company_name': contact.company,
        'designation': contact.designation,
        'phone': contact.phone,
        'alternative_phone': contact.alternativePhone ?? '',
        'landline': contact.landline ?? '',
        'whatsapp': contact.whatsApp ?? '',
        'email': contact.email,
        'website': contact.website,
        'address': contact.address,
        'pin_code': contact.pinCode ?? '',
        'social_links': contact.socialLinks.join(','),
        'source': contact.source ?? 'scan',
        'created_at': contact.createdAt.toIso8601String(),
      };

      debugPrint(
        '📤 BackendSync: POST ${ApiConfig.qrContacts} | payload keys: ${payload.keys.join(', ')}',
      );

      final response = await _dio.post(
        ApiConfig.qrContacts,
        data: payload,
        options: Options(headers: {'x-background-sync': 'true'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('☁️ Successfully synced contact: ${contact.name}');
        return true;
      }

      debugPrint(
        '⚠️ Unexpected status code: ${response.statusCode} for contact: ${contact.name}',
      );
      return false;
    } on DioException catch (e) {
      // ── Extract meaningful server-side error message ─────────────────────
      String serverMessage;
      try {
        final data = e.response?.data;
        if (data is Map) {
          serverMessage = data['message']?.toString()
              ?? data['error']?.toString()
              ?? data['detail']?.toString()
              ?? 'Server error (${e.response?.statusCode})';
        } else if (data is String && data.isNotEmpty) {
          // Some backends return plain text errors
          serverMessage = data.length > 200 ? '${data.substring(0, 200)}...' : data;
        } else {
          serverMessage = e.message ?? 'Server error (${e.response?.statusCode})';
        }
      } catch (_) {
        serverMessage = e.message ?? 'Unknown server error';
      }
      debugPrint('🚨 BackendSync DioError: $serverMessage');
      throw Exception(serverMessage);
    } catch (e) {
      debugPrint('🚨 BackendSync unexpected error: $e');
      rethrow;
    }
  }
}

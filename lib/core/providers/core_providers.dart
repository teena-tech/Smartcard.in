import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/connectivity_service.dart';
import '../database/sqlite_database.dart';
import '../database/hive_scan_database.dart';

/// Provider for FlutterSecureStorage instance
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Provider for SharedPreferences instance (asynchronous initialization)
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

/// Provider for network connectivity monitor
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Provider for central DioClient singleton / service
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

/// Provider for the underlying configured Dio instance
final dioProvider = Provider<Dio>((ref) {
  return ref.watch(dioClientProvider).dio;
});

/// Provider referencing SQLite database engine
final sqliteDatabaseProvider = Provider<Type>((ref) {
  return SqliteDatabase;
});

/// Provider referencing Hive persistent scan database engine
final hiveScanDatabaseProvider = Provider<Type>((ref) {
  return HiveScanDatabase;
});



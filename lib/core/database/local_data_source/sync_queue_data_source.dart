import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SyncQueueDataSource {
  static const String _syncQueueKey = 'app_sync_queue_list';

  static Future<void> init() async {
    // No-op for SharedPreferences initialization
  }

  Future<void> addItem(String key, Map<String, dynamic> value) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMap = _getRawMap(prefs);
    currentMap[key] = value;
    await prefs.setString(_syncQueueKey, jsonEncode(currentMap));
  }

  Future<void> removeItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final currentMap = _getRawMap(prefs);
    currentMap.remove(key);
    await prefs.setString(_syncQueueKey, jsonEncode(currentMap));
  }

  List<Map<String, dynamic>> getAllItems() {
    // Synchronous fallback read if needed, preferred via asyncSharedPreferences
    return [];
  }

  Future<List<Map<String, dynamic>>> getAllItemsAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final currentMap = _getRawMap(prefs);
    return currentMap.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  Map<String, dynamic> _getRawMap(SharedPreferences prefs) {
    final jsonStr = prefs.getString(_syncQueueKey);
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
    } catch (_) {
      return {};
    }
  }
}

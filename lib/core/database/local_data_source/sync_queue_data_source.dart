import 'package:hive_flutter/hive_flutter.dart';

class SyncQueueDataSource {
  static const String _boxName = 'sync_queue_box';
  static Box<Map<dynamic, dynamic>>? _box;

  static Future<void> init() async {
    _box ??= await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
  }

  Future<void> addItem(String key, Map<String, dynamic> value) async {
    await _box?.put(key, value);
  }

  Future<void> removeItem(String key) async {
    await _box?.delete(key);
  }

  List<Map<String, dynamic>> getAllItems() {
    if (_box == null) return [];
    return _box!.values
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

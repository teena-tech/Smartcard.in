import 'package:hive_flutter/hive_flutter.dart';
import '../../../models/user_model.dart';

class ProfileLocalDataSource {
  static const String _boxName = 'user_profile_box';
  static Box<Map<dynamic, dynamic>>? _box;

  static Future<void> init() async {
    _box ??= await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
  }

  Future<UserModel?> getUser(String userId) async {
    final userJson = _box?.get(userId);
    if (userJson == null) return null;
    return UserModel.fromJson(Map<String, dynamic>.from(userJson));
  }

  Future<void> saveUser(UserModel user) async {
    await _box?.put(user.id, user.toJson());
  }
}

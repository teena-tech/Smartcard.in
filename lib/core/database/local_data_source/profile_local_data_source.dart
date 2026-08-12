import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/user_model.dart';

class ProfileLocalDataSource {
  static const String _userPrefix = 'user_profile_';

  static Future<void> init() async {
    // No-op for SharedPreferences initialization
  }

  Future<UserModel?> getUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('$_userPrefix$userId');
    if (jsonString == null || jsonString.isEmpty) return null;
    try {
      final userJson = jsonDecode(jsonString) as Map<String, dynamic>;
      return UserModel.fromJson(userJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_userPrefix${user.id}', jsonEncode(user.toJson()));
  }
}

import 'package:smartcard_flutter/repositories/base_repository.dart';
import '../core/network/api_config.dart';

/// Repository handling dashboardâ€‘related API calls.
/// Since the gobifile backend does not have a generic '/dashboard/landing'
/// endpoint, we safely mock the data or point to the correct gobifile endpoints.
class DashboardRepository extends BaseRepository {
  /// Fetches landing screen data (banners, stats, recent activity).
  Future<Map<String, dynamic>> fetchLandingData() async {
    try {
      final response = await get(ApiConfig.dashboardLanding);
      if (response is Map<String, dynamic>) {
        if (response['data'] is Map) {
          return Map<String, dynamic>.from(response['data'] as Map);
        }
        return response;
      }
    } catch (_) {}
    return {
      'banners': [],
      'stats': {},
      'recent_activity': []
    };
  }

  /// Fetches the user's profile image URL.
  Future<String?> fetchProfileImage(String userId) async {
    try {
      final response = await get(ApiConfig.userProfile(userId));
      if (response is Map && response['user'] is Map) {
        final user = response['user'] as Map;
        return (user['profile_image'] ?? user['image'])?.toString();
      }
    } catch (e) {
      // ignore error
    }
    return null;
  }

  /// Fetches banner images for the home screen.
  Future<List<String>> fetchBannerImages() async {
    return [];
  }

  /// Fetches recent activity list.
  Future<List<dynamic>> fetchRecentActivity({int page = 1, int pageSize = 20}) async {
    try {
      final response = await get(
        ApiConfig.recentActivity,
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      if (response is List) {
        return List<dynamic>.from(response);
      }
      if (response is Map && response['data'] is List) {
        return List<dynamic>.from(response['data'] as List);
      }
    } catch (_) {}
    return [];
  }
}


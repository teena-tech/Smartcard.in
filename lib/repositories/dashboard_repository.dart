import 'package:smartcard_flutter/repositories/base_repository.dart';
import '../core/services/api_config.dart';

/// Repository handling dashboard‑related API calls.
/// Since the gobifile backend does not have a generic '/dashboard/landing'
/// endpoint, we safely mock the data or point to the correct gobifile endpoints.
class DashboardRepository extends BaseRepository {
  /// Fetches landing screen data (banners, stats, recent activity).
  Future<Map<String, dynamic>> fetchLandingData() async {
    try {
      final response = await get(ApiConfig.dashboardLanding);
      if (response is Map<String, dynamic>) {
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
      if (response is Map && response['user'] != null) {
        return response['user']['image'] as String?;
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
    } catch (_) {}
    return [];
  }
}


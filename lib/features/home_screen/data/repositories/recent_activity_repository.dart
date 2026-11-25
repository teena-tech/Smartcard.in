import 'package:smartcard_flutter/core/repositories/base_repository.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

/// Repository for recent activity API calls with pagination.
class RecentActivityRepository extends BaseRepository {
  /// Fetch recent activity list for a user.
  Future<List<dynamic>> fetchRecentActivity({required String userId, int page = 1, int pageSize = 20}) async {
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


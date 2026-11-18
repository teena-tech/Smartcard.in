import 'package:flutter/material.dart';
import '../repositories/dashboard_repository.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardRepository _repo = DashboardRepository();

  // Data holders
  List<String> _banners = [];
  String? _profileImageUrl;
  List<dynamic> _recentActivity = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;
int _currentIndex = 0;
  int _currentPage = 1;

  // Getters
  List<String> get banners => _banners;
  String? get profileImageUrl => _profileImageUrl;
  List<dynamic> get recentActivity => _recentActivity;
  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
int get currentIndex => _currentIndex;

  // Set navigation index
  void setIndex(int index) {
    if (index != _currentIndex) {
      _currentIndex = index;
      notifyListeners();
    }
  }
  void refresh() {
    notifyListeners();
  }
  int get currentPage => _currentPage;

  // Fetch all dashboard data
  Future<void> loadDashboard() async {
    _isLoading = true;
    _error = null;
    _currentPage = 1;
    notifyListeners();
    try {
      final landing = await _repo.fetchLandingData();
      // Assuming landing contains fields: banners, profile_image, stats, recent_activity
      if (landing.containsKey('banners')) {
        _banners = List<String>.from(landing['banners'] ?? []);
      }
      if (landing.containsKey('profile_image')) {
        _profileImageUrl = landing['profile_image'] as String?;
      }
      if (landing.containsKey('stats')) {
        _stats = Map<String, dynamic>.from(landing['stats'] ?? {});
      }
      if (landing.containsKey('recent_activity')) {
        _recentActivity = List<dynamic>.from(landing['recent_activity'] ?? []);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Optional paginated recent activity loader
  Future<void> loadMoreActivity({int page = 1, int pageSize = 20}) async {
    try {
      final more = await _repo.fetchRecentActivity(page: page, pageSize: pageSize);
      if (page == 1) {
        _recentActivity = more;
      } else {
        _recentActivity.addAll(more);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}

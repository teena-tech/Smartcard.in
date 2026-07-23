import 'package:flutter/material.dart';
import '../repositories/recent_activity_repository.dart';

class RecentActivityViewModel extends ChangeNotifier {
  final RecentActivityRepository _repo = RecentActivityRepository();

  List<dynamic> _activities = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get activities => _activities;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadActivities({required String userId, int page = 1, int pageSize = 20}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo.fetchRecentActivity(userId: userId, page: page, pageSize: pageSize);
      if (page == 1) {
        _activities = list;
      } else {
        _activities.addAll(list);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

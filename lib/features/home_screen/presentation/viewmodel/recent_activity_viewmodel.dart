import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/home_screen/data/repositories/recent_activity_repository.dart';

@immutable
class RecentActivityState {
  final List<dynamic> activities;
  final bool isLoading;
  final String? error;

  const RecentActivityState({
    this.activities = const [],
    this.isLoading = false,
    this.error,
  });

  RecentActivityState copyWith({
    List<dynamic>? activities,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RecentActivityState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RecentActivityViewModel extends Notifier<RecentActivityState> {
  final RecentActivityRepository _repo = RecentActivityRepository();

  @override
  RecentActivityState build() {
    return const RecentActivityState();
  }

  List<dynamic> get activities => state.activities;
  bool get isLoading => state.isLoading;
  String? get error => state.error;

  Future<void> loadActivities({required String userId, int page = 1, int pageSize = 20}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await _repo.fetchRecentActivity(userId: userId, page: page, pageSize: pageSize);
      final updated = page == 1 ? list : [...state.activities, ...list];
      state = state.copyWith(activities: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final recentActivityViewModelProvider =
    NotifierProvider<RecentActivityViewModel, RecentActivityState>(RecentActivityViewModel.new);

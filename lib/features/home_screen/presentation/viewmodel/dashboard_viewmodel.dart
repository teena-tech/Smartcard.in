import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/home_screen/data/repositories/dashboard_repository.dart';

@immutable
class DashboardState {
  final List<String> banners;
  final String? profileImageUrl;
  final List<dynamic> recentActivity;
  final Map<String, dynamic> stats;
  final bool isLoading;
  final String? error;
  final int currentIndex;
  final int currentPage;

  const DashboardState({
    this.banners = const [],
    this.profileImageUrl,
    this.recentActivity = const [],
    this.stats = const {},
    this.isLoading = false,
    this.error,
    this.currentIndex = 0,
    this.currentPage = 1,
  });

  DashboardState copyWith({
    List<String>? banners,
    String? profileImageUrl,
    List<dynamic>? recentActivity,
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? error,
    int? currentIndex,
    int? currentPage,
    bool clearError = false,
  }) {
    return DashboardState(
      banners: banners ?? this.banners,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      recentActivity: recentActivity ?? this.recentActivity,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentIndex: currentIndex ?? this.currentIndex,
      currentPage: currentPage ?? this.currentPage,
    );
  }

  void setIndex(int index) {}
}

class DashboardViewModel extends Notifier<DashboardState> {
  final DashboardRepository _repo = DashboardRepository();

  @override
  DashboardState build() {
    return const DashboardState();
  }

  // Getters for convenience
  List<String> get banners => state.banners;
  String? get profileImageUrl => state.profileImageUrl;
  List<dynamic> get recentActivity => state.recentActivity;
  Map<String, dynamic> get stats => state.stats;
  bool get isLoading => state.isLoading;
  String? get error => state.error;
  int get currentIndex => state.currentIndex;
  int get currentPage => state.currentPage;

  void setIndex(int index) {
    if (index != state.currentIndex) {
      state = state.copyWith(currentIndex: index);
    }
  }

  void refresh() {
    state = state.copyWith();
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, clearError: true, currentPage: 1);
    try {
      final landing = await _repo.fetchLandingData();
      List<String> newBanners = state.banners;
      String? newProfileImage = state.profileImageUrl;
      Map<String, dynamic> newStats = state.stats;
      List<dynamic> newRecent = state.recentActivity;

      if (landing.containsKey('banners')) {
        newBanners = List<String>.from(landing['banners'] ?? []);
      }
      if (landing.containsKey('profile_image')) {
        newProfileImage = landing['profile_image'] as String?;
      }
      if (landing.containsKey('stats')) {
        newStats = Map<String, dynamic>.from(landing['stats'] ?? {});
      }
      if (landing.containsKey('recent_activity')) {
        newRecent = List<dynamic>.from(landing['recent_activity'] ?? []);
      }

      state = state.copyWith(
        banners: newBanners,
        profileImageUrl: newProfileImage,
        stats: newStats,
        recentActivity: newRecent,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMoreActivity({int page = 1, int pageSize = 20}) async {
    try {
      final more = await _repo.fetchRecentActivity(page: page, pageSize: pageSize);
      final updatedList = page == 1 ? more : [...state.recentActivity, ...more];
      state = state.copyWith(recentActivity: updatedList);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final dashboardViewModelProvider =
    NotifierProvider<DashboardViewModel, DashboardState>(DashboardViewModel.new);

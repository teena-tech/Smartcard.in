import '../state/app_loading_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'core_providers.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/card_repository.dart';
import '../../repositories/theme_repository.dart';
import '../../repositories/support_repository.dart';
import '../../repositories/contact_repository.dart';
import '../../repositories/dashboard_repository.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/support_viewmodel.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/message_viewmodel.dart';
import '../../viewmodels/landing_viewmodel.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../providers/contact_provider.dart';
import '../../providers/group_provider.dart';
import '../../viewmodels/customize_viewmodel.dart';
import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../models/card_model.dart';

// ==========================================
// 1. REPOSITORY PROVIDERS (Pure DI via Ref)
// ==========================================

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(dioClientProvider));
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(ref.watch(dioClientProvider));
});

final themeRepositoryProvider = Provider<ThemeRepository>((ref) {
  return ThemeRepository(ref.watch(dioClientProvider));
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(dioClientProvider));
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  return ContactRepository();
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

// ==========================================
// 2. NAVIGATION / TAB STATE NOTIFIER
// ==========================================

class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (state != index) {
      state = index;
    }
  }
}

final tabIndexProvider = NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

// ==========================================
// 3. RIVERPOD VIEWMODEL BRIDGES
// ==========================================

final themeViewModelProvider = ChangeNotifierProvider<ThemeViewModel>((ref) {
  return ThemeViewModel();
});

final authViewModelProvider = ChangeNotifierProvider<AuthViewModel>((ref) {
  return AuthViewModel(ref.watch(authRepositoryProvider));
});

final profileViewModelProvider = ChangeNotifierProvider<ProfileViewModel>((ref) {
  return ProfileViewModel(ref.watch(userRepositoryProvider));
});

final cardViewModelProvider = ChangeNotifierProvider<CardViewModel>((ref) {
  return CardViewModel(cardRepository: ref.watch(cardRepositoryProvider));
});

final supportViewModelProvider = ChangeNotifierProvider<SupportViewModel>((ref) {
  return SupportViewModel(ref.watch(supportRepositoryProvider));
});

final dashboardViewModelProvider = ChangeNotifierProvider<DashboardViewModel>((ref) {
  return DashboardViewModel();
});

final subscriptionViewModelProvider = ChangeNotifierProvider<SubscriptionViewModel>((ref) {
  return SubscriptionViewModel();
});

final messageViewModelProvider = ChangeNotifierProvider<MessageViewModel>((ref) {
  return MessageViewModel();
});

final landingViewModelProvider = ChangeNotifierProvider<LandingViewModel>((ref) {
  return LandingViewModel();
});

final contactViewModelProvider = ChangeNotifierProvider<ContactViewModel>((ref) {
  return ContactViewModel();
});

final contactProviderRiverpod = ChangeNotifierProvider<ContactProvider>((ref) {
  return ContactProvider();
});

final customizeViewModelProvider = ChangeNotifierProvider<CustomizeViewModel>((ref) {
  return CustomizeViewModel();
});

final groupProviderRiverpod = ChangeNotifierProvider<GroupProvider>((ref) {
  return GroupProvider();
});

final appLoadingServiceProvider = ChangeNotifierProvider<AppLoadingService>((ref) {
  return AppLoadingService.instance;
});

// ==========================================
// 4. REACTIVE DOMAIN & DERIVED PROVIDERS
// ==========================================

/// Current authenticated user
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authViewModelProvider).currentUser;
});

/// Authentication status boolean
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authViewModelProvider).isAuthenticated;
});

/// Theme colors reactive provider
final themeColorsProvider = Provider<AppColors>((ref) {
  return ref.watch(themeViewModelProvider).colors;
});

/// Theme mode reactive provider
final themeModeProvider = Provider<AppThemeMode>((ref) {
  return ref.watch(themeViewModelProvider).themeMode;
});

/// All user cards
final userCardsProvider = Provider<List<CardModel>>((ref) {
  return ref.watch(cardViewModelProvider).cards;
});

/// Primary smart card
final primaryCardProvider = Provider<CardModel?>((ref) {
  return ref.watch(cardViewModelProvider).primaryCard;
});

/// Currently active selected card
final currentCardProvider = Provider<CardModel?>((ref) {
  return ref.watch(cardViewModelProvider).currentCard;
});

/// Scanner tab active check
final isScanTabActiveProvider = Provider<bool>((ref) {
  return ref.watch(tabIndexProvider) == 1;
});

/// Contacts tab active check
final isContactsTabActiveProvider = Provider<bool>((ref) {
  return ref.watch(tabIndexProvider) == 4;
});




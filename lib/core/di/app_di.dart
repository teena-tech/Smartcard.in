import 'package:flutter_riverpod/flutter_riverpod.dart';

// Core Providers
import 'app_loading_notifier.dart';
import 'workspace_notifier.dart';
import 'sync_notifier.dart';

// Network & Database
import '../network/dio_service.dart';
import '../network/connectivity_service.dart';
import '../database/local_data_source/profile_local_data_source.dart';
import '../database/local_data_source/sync_queue_data_source.dart';

// Feature Repositories & Providers
import '../../features/login_screen/data/repositories/auth_repository.dart';
import '../../features/profile_screen/data/repositories/user_repository.dart';
import '../../features/customize_theme_screen/data/repositories/theme_repository.dart';
import '../../features/smart_card_list_screen/data/repositories/card_repository.dart';
import '../../features/contacts_screen/data/repositories/contact_repository.dart';
import '../../features/home_screen/data/repositories/dashboard_repository.dart';
import '../../features/home_screen/data/repositories/recent_activity_repository.dart';
import '../../features/subscription_screen/data/repositories/coupon_repository.dart';
import '../../features/support_agent_screen/data/repositories/agent_repository.dart';
import '../../features/support_chat_screen/data/repositories/support_repository.dart';
import '../../features/smart_scanner_screen/domain/repositories/scanner_repository.dart';
import '../../features/smart_scanner_screen/data/repositories/scanner_repository_impl.dart';

// Feature ViewModels
import '../../features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import '../../features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import '../../features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import '../../features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import '../../features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import '../../features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import '../../features/groups_screen/presentation/viewmodel/group_notifier.dart';
import '../../features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import '../../features/home_screen/presentation/viewmodel/recent_activity_viewmodel.dart';
import '../../features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
import '../../features/subscription_screen/presentation/viewmodel/coupon_viewmodel.dart';
import '../../features/landing_screen/presentation/viewmodel/landing_viewmodel.dart';
import '../../features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
import '../../features/support_chat_screen/presentation/viewmodel/support_viewmodel.dart';
import '../../features/support_agent_screen/presentation/viewmodel/agent_viewmodel.dart';
import '../../features/customize_ai_screen/presentation/viewmodel/customization_controller.dart';
import '../../features/customize_menu_screen/presentation/viewmodel/customize_viewmodel.dart';
import '../../features/business_card_scanner_screen/presentation/viewmodel/scanner_controller.dart';
import '../../features/smart_scanner_screen/presentation/viewmodel/scan_notifier.dart';

// Re-exports
export 'app_loading_notifier.dart';
export 'workspace_notifier.dart';
export 'sync_notifier.dart';

export '../../features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
export '../../features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
export '../../features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
export '../../features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
export '../../features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
export '../../features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
export '../../features/groups_screen/presentation/viewmodel/group_notifier.dart';
export '../../features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
export '../../features/home_screen/presentation/viewmodel/recent_activity_viewmodel.dart';
export '../../features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';
export '../../features/subscription_screen/presentation/viewmodel/coupon_viewmodel.dart';
export '../../features/landing_screen/presentation/viewmodel/landing_viewmodel.dart';
export '../../features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
export '../../features/support_chat_screen/presentation/viewmodel/support_viewmodel.dart';
export '../../features/support_agent_screen/presentation/viewmodel/agent_viewmodel.dart';
export '../../features/customize_ai_screen/presentation/viewmodel/customization_controller.dart';
export '../../features/customize_menu_screen/presentation/viewmodel/customize_viewmodel.dart';
export '../../features/business_card_scanner_screen/presentation/viewmodel/scanner_controller.dart';
export '../../features/smart_scanner_screen/presentation/viewmodel/scan_notifier.dart';

// ── Dependency Injection Providers ──────────────────────────────────────────
final dioServiceProvider = Provider<DioService>((ref) => DioService());
final connectivityServiceProvider = Provider<ConnectivityService>((ref) => ConnectivityService());
final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) => ProfileLocalDataSource());
final syncQueueDataSourceProvider = Provider<SyncQueueDataSource>((ref) => SyncQueueDataSource());

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final userRepositoryProvider = Provider<UserRepository>((ref) => UserRepository());
final themeRepositoryProvider = Provider<ThemeRepository>((ref) => ThemeRepository());
final cardRepositoryProvider = Provider<CardRepository>((ref) => CardRepository());
final contactRepositoryProvider = Provider<ContactRepository>((ref) => ContactRepository());
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());
final recentActivityRepositoryProvider = Provider<RecentActivityRepository>((ref) => RecentActivityRepository());
final couponRepositoryProvider = Provider<CouponRepository>((ref) => CouponRepository());
final agentRepositoryProvider = Provider<AgentRepository>((ref) => AgentRepository(ref.read(dioServiceProvider)));
final supportRepositoryProvider = Provider<SupportRepository>((ref) => SupportRepository(ref.read(dioServiceProvider)));
final scannerRepositoryProvider = Provider<IScannerRepository>((ref) =>
    ScannerRepositoryImpl(connectivity: ref.read(connectivityServiceProvider)));



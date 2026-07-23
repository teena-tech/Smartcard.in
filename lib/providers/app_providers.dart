import 'package:provider/provider.dart';

import '../core/state/app_loading_service.dart';
import '../core/network/connectivity_service.dart';
import '../core/database/local_data_source/profile_local_data_source.dart';
import '../core/database/local_data_source/sync_queue_data_source.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/theme_repository.dart';
import '../repositories/card_repository.dart';
import '../repositories/interfaces/scanner_repository.dart';
import '../repositories/implementations/scanner_repository_impl.dart';
import '../core/network/dio_service.dart';
import '../data/repositories/support_repository.dart';
import '../repositories/agent_repository.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/agent_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/card_viewmodel.dart';
import '../viewmodels/subscription_viewmodel.dart';
import '../viewmodels/contact_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/landing_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/support_viewmodel.dart';
import '../viewmodels/customization_controller.dart';
import '../viewmodels/customize_viewmodel.dart';

class AppProviders {
  static List<dynamic> get providers => [
    // 1. Repositories
    ChangeNotifierProvider<AppLoadingService>.value(value: AppLoadingService.instance),
    Provider<ConnectivityService>(create: (_) => ConnectivityService()),
    Provider<ProfileLocalDataSource>(create: (_) => ProfileLocalDataSource()),
    Provider<SyncQueueDataSource>(create: (_) => SyncQueueDataSource()),
    Provider<AuthRepository>(create: (_) => AuthRepository()),
    Provider<UserRepository>(create: (_) => UserRepository()),
    Provider<DioService>(create: (_) => DioService()),
    Provider<SupportRepository>(
      create: (context) => SupportRepository(context.read<DioService>()),
    ),
    Provider<AgentRepository>(
      create: (context) => AgentRepository(context.read<DioService>()),
    ),
    Provider<ThemeRepository>(create: (_) => ThemeRepository()),
    Provider<CardRepository>(create: (_) => CardRepository()),
    Provider<IScannerRepository>(
      create: (context) => ScannerRepositoryImpl(
        connectivity: context.read<ConnectivityService>(),
      ),
    ),

    // 2. ViewModels
    ChangeNotifierProvider<AuthViewModel>(
      create: (context) => AuthViewModel(context.read<AuthRepository>()),
    ),
    ChangeNotifierProvider<ProfileViewModel>(
      create: (context) => ProfileViewModel(context.read<UserRepository>()),
    ),
    ChangeNotifierProvider<SupportViewModel>(
      create: (context) => SupportViewModel(context.read<SupportRepository>()),
    ),
    ChangeNotifierProvider<AgentViewModel>(
      create: (context) => AgentViewModel(context.read<AgentRepository>()),
    ),
    ChangeNotifierProvider<ThemeViewModel>(
      create: (context) => ThemeViewModel(),
    ),
    ChangeNotifierProvider<CardViewModel>(
      create: (context) => CardViewModel(cardRepository: context.read<CardRepository>()),
    ),
    ChangeNotifierProvider<SubscriptionViewModel>(
      create: (_) => SubscriptionViewModel(),
    ),
    ChangeNotifierProvider<ContactViewModel>(
      create: (_) => ContactViewModel(),
    ),
    ChangeNotifierProvider<DashboardViewModel>(
      create: (_) => DashboardViewModel(),
    ),
    ChangeNotifierProvider<LandingViewModel>(
      create: (_) => LandingViewModel(),
    ),
    ChangeNotifierProvider<MessageViewModel>(
      create: (_) => MessageViewModel(),
    ),
    ChangeNotifierProvider<CustomizationController>(
      create: (_) => CustomizationController(),
    ),
    ChangeNotifierProvider<CustomizeViewModel>(
      create: (_) => CustomizeViewModel(),
    ),
  ];
}

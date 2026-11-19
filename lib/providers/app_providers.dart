import 'package:provider/provider.dart';

import '../core/state/app_loading_service.dart';
import '../core/network/connectivity_service.dart';
import '../core/network/dio_client.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/theme_repository.dart';
import '../repositories/card_repository.dart';
import '../repositories/support_repository.dart';

import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../viewmodels/card_viewmodel.dart';
import '../viewmodels/subscription_viewmodel.dart';
import '../viewmodels/contact_viewmodel.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import '../viewmodels/landing_viewmodel.dart';
import '../viewmodels/message_viewmodel.dart';
import '../viewmodels/support_viewmodel.dart';
import '../viewmodels/customize_viewmodel.dart';
import 'contact_provider.dart';
import 'group_provider.dart';

class AppProviders {
  static List<dynamic> get providers => [
    // 1. Repositories
    ChangeNotifierProvider<AppLoadingService>.value(value: AppLoadingService.instance),
    Provider<ConnectivityService>(create: (_) => ConnectivityService()),
    Provider<DioClient>(create: (_) => DioClient()),
    Provider<AuthRepository>(create: (_) => AuthRepository()),
    Provider<UserRepository>(create: (_) => UserRepository()),
    Provider<SupportRepository>(
      create: (context) => SupportRepository(context.read<DioClient>()),
    ),
    Provider<ThemeRepository>(create: (_) => ThemeRepository()),
    Provider<CardRepository>(create: (_) => CardRepository()),

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
    ChangeNotifierProvider<ContactProvider>(
      create: (_) => ContactProvider()..initialize(),
    ),
    ChangeNotifierProvider<GroupProvider>(
      create: (_) => GroupProvider()..loadGroups(),
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
    ChangeNotifierProvider<CustomizeViewModel>(
      create: (_) => CustomizeViewModel(),
    ),
  ];
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_theme.dart';
import 'providers/app_providers.dart';
import 'views/screens/splash_screen.dart';
import 'core/database/hive_database.dart';
import 'core/database/local_data_source/profile_local_data_source.dart';
import 'core/database/local_data_source/sync_queue_data_source.dart';
import 'core/services/backend_sync_service.dart';
import 'views/widgets/global_loading_overlay.dart';
import 'viewmodels/customization_controller.dart';
import 'views/screens/profile_mvvm_screen.dart';
import 'views/screens/login_screen.dart';
import 'core/services/dio_client.dart';
import 'viewmodels/theme_viewmodel.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'bloc/scan_bloc.dart';
import 'bloc/sync_bloc.dart';

/// Lottie composition preloaded at startup so the overlay shows it instantly.
LottieComposition? globalLottieComposition;
LottieComposition? globalDeleteLottieComposition;
LottieComposition? globalEmptyContactsLottieComposition;
LottieComposition? globalSuccessLottieComposition;

void main() async {
  // Ensure Flutter engine bindings are fully initialized before native code execution
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize dynamic local storage
  await HiveDatabase.init();
  await ProfileLocalDataSource.init();
  await SyncQueueDataSource.init();

  // Start automated cloud sync listener
  BackendSyncService().initConnectivityListener();

  // Asynchronously pre-load Lottie animations in background without blocking runApp
  _preloadLottieAssets();

  runApp(
    MultiProvider(
      providers: [
        ...AppProviders.providers,
        BlocProvider<ScanBloc>(create: (_) => ScanBloc()),
        BlocProvider<SyncBloc>(create: (_) => SyncBloc()),
      ],
      child: const SmartCardsApp(),
    ),
  );
}

void _preloadLottieAssets() {
  Future.microtask(() async {
    try {
      await Future.wait([
        rootBundle.load('assets/lottie/loading_loop.json').then((data) async {
          globalLottieComposition = await LottieComposition.fromByteData(data);
        }),
        rootBundle.load('assets/lottie/Delete animation 1.json').then((data) async {
          globalDeleteLottieComposition = await LottieComposition.fromByteData(data);
        }),
        rootBundle.load('assets/lottie/Animation - 1727287595969.json').then((data) async {
          globalEmptyContactsLottieComposition = await LottieComposition.fromByteData(data);
        }),
        rootBundle.load('assets/lottie/Success Animation 2.json').then((data) async {
          globalSuccessLottieComposition = await LottieComposition.fromByteData(data);
        }),
      ]);
    } catch (e) {
      debugPrint('⚠️ Non-critical Lottie preload error: $e');
    }
  });
}


class SmartCardsApp extends StatelessWidget {
  const SmartCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeViewModel>(
      builder: (context, themeViewModel, child) {
        return MaterialApp(
          navigatorKey: DioClient.navigatorKey,
          title: 'Smart Cards',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getTheme(themeViewModel.themeMode),
          builder: (context, child) {
            return GlobalLoadingOverlay(
              child: ThemeWrapper(child: child!),
            );
          },
          routes: {
            '/profile': (context) => const ProfileMvvmScreen(),
            '/login': (context) => const LoginScreen(),
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}

class ThemeWrapper extends StatelessWidget {
  final Widget child;
  const ThemeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // 1. Precise listeners for Theme background colors
    final bgStart = context.select<ThemeViewModel, Color>((t) => t.colors.backgroundStart);
    final bgEnd = context.select<ThemeViewModel, Color>((t) => t.colors.backgroundEnd);

    // 2. Precise listeners for Customization Controller background settings
    final bgImageEnabled = context.select<CustomizationController, bool>((c) => c.bgImageEnabled);
    final bgImagePath = context.select<CustomizationController, String?>((c) => c.backgroundImagePath);

    if (bgImageEnabled && bgImagePath != null && bgImagePath.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(bgImagePath)),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgStart, bgEnd],
        ),
        image: const DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: child,
    );
  }
}

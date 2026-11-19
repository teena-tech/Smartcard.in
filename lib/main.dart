import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/providers/app_riverpod_providers.dart';
import 'providers/app_providers.dart';
import 'views/screens/splash_screen.dart';
import 'core/database/hive_scan_database.dart';
import 'core/database/sqlite_database.dart';
import 'core/services/backend_sync_service.dart';
import 'core/services/telemetry_service.dart';
import 'views/widgets/global_loading_overlay.dart';
import 'views/screens/profile_screen.dart';
import 'views/screens/login_screen.dart';

import 'core/network/dio_client.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';

/// Lottie composition preloaded at startup so the overlay shows it instantly.
LottieComposition? globalLottieComposition;
LottieComposition? globalDeleteLottieComposition;
LottieComposition? globalEmptyContactsLottieComposition;
LottieComposition? globalSuccessLottieComposition;

void main() async {
  // Ensure Flutter engine bindings are fully initialized before native code execution
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize central telemetry & error reporting
  TelemetryService.instance.init();

  // Global safety net: intercept uncaught Flutter and async errors so Android never force-closes the app
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exception}');
    TelemetryService.instance.reportFlutterError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[PlatformDispatcher] Uncaught async error safely handled: $error');
    TelemetryService.instance.reportPlatformError(error, stack);
    return true; // Prevents process termination
  };

  try {
    await Firebase.initializeApp();
    debugPrint('ðŸ”¥ Firebase initialized successfully');
  } catch (e) {
    debugPrint('âš ï¸ Firebase initialization error: $e');
  }

  // Lock orientation to Portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables from .env
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('âœ… Environment loaded from .env');
  } catch (e) {
    debugPrint('âš ï¸ Warning loading .env file: $e');
  }

  // Initialize persistent Hive storage & boxes before repositories are accessed
  try {
    await HiveScanDatabase.init();
    debugPrint('HiveScanDatabase initialized');
  } catch (e) {
    debugPrint('Warning HiveScanDatabase init: $e');
  }

  // Initialize dynamic local storage
  try {
    await SqliteDatabase.init();
    debugPrint('SqliteDatabase initialized');
  } catch (e) {
    debugPrint('Warning SqliteDatabase init: $e');
  }

  // Start automated cloud sync listener
  try {
    BackendSyncService().initConnectivityListener();
    debugPrint('BackendSyncService initialized');
  } catch (e) {
    debugPrint('Warning BackendSyncService init: $e');
  }

  // Asynchronously pre-load Lottie animations in background without blocking runApp
  _preloadLottieAssets();

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ...AppProviders.providers,
        ],
        child: const SmartCardsApp(),
      ),
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
      debugPrint('âš ï¸ Non-critical Lottie preload error: $e');
    }
  });
}

class SmartCardsApp extends ConsumerWidget {
  const SmartCardsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: DioClient.navigatorKey,
      title: 'Smart Cards',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeMode),
      builder: (context, child) {
        return GlobalLoadingOverlay(
          child: ThemeWrapper(child: child!),
        );
      },
      routes: {
        '/profile': (context) => const ProfileScreen(),
        '/login': (context) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}

class ThemeWrapper extends ConsumerWidget {
  final Widget child;
  const ThemeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final themeVm = ref.watch(themeViewModelProvider);
    final bgStart = colors.backgroundStart;
    final bgEnd = colors.backgroundEnd;
    final bgImageEnabled = themeVm.bgImageEnabled;
    final bgImagePath = themeVm.backgroundImagePath;

    final Widget themedContent;
    if (bgImageEnabled && bgImagePath != null && bgImagePath.isNotEmpty) {
      themedContent = Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: FileImage(File(bgImagePath)),
            fit: BoxFit.cover,
          ),
        ),
        child: child,
      );
    } else {
      themedContent = Container(
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

    return themedContent;
  }
}

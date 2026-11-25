import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:rive/rive.dart' hide File;
import 'package:firebase_core/firebase_core.dart';

import 'package:smartcard_flutter/core/constants/app_theme.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:smartcard_flutter/features/splash_screen/presentation/view/splash_screen.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/view/profile_screen.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/view/login_screen.dart';
import 'package:smartcard_flutter/core/database/hive_scan_database.dart';
import 'package:smartcard_flutter/core/database/sqlite_database.dart';
import 'package:smartcard_flutter/core/database/local_data_source/profile_local_data_source.dart';
import 'package:smartcard_flutter/core/database/local_data_source/sync_queue_data_source.dart';
import 'package:smartcard_flutter/core/services/backend_sync_service.dart';
import 'package:smartcard_flutter/core/services/telemetry_service.dart';
import 'package:smartcard_flutter/core/widgets/global_loading_overlay.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';

/// Lottie composition preloaded at startup so the overlay shows it instantly.
LottieComposition? globalLottieComposition;
LottieComposition? globalDeleteLottieComposition;
LottieComposition? globalEmptyContactsLottieComposition;
LottieComposition? globalSuccessLottieComposition;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize central telemetry & error reporting
  TelemetryService.instance.init();

  // Global safety net: intercept uncaught Flutter and async errors
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

  // Fast-path: Lock orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Parallel asynchronous initializations for maximum cold-start loading speed
  await Future.wait([
    Firebase.initializeApp().then((_) {
      debugPrint('🔥 Firebase initialized');
    }).catchError((e) {
      debugPrint('⚠️ Firebase init: $e');
    }),
    RiveNative.init().catchError((e) {
      debugPrint('RiveNative init: $e');
      return false;
    }),
    dotenv.load(fileName: ".env").catchError((e) {
      debugPrint('⚠️ Dotenv init: $e');
    }),
    HiveScanDatabase.init(),
    SqliteDatabase.init(),
    ProfileLocalDataSource.init(),
    SyncQueueDataSource.init(),
    rootBundle.load('assets/lottie/loading_loop.json').then((data) async {
      globalLottieComposition = await LottieComposition.fromByteData(data);
    }).catchError((e) {
      debugPrint('⚠️ Lottie load: $e');
    }),
  ]);

  // Non-blocking background services & preloading
  BackendSyncService().initConnectivityListener();
  _preloadLottieAssets();

  runApp(
    const ProviderScope(
      child: SmartCardsApp(),
    ),
  );
}

void _preloadLottieAssets() {
  Future.microtask(() async {
    try {
      final data = await rootBundle.load('assets/lottie/loading_loop.json');
      globalLottieComposition = await LottieComposition.fromByteData(data);
    } catch (e) {
      debugPrint('⚠️ Error preloading loading_loop.json: $e');
    }

    try {
      final data = await rootBundle.load('assets/lottie/Animation - 1733557597592.json');
      globalDeleteLottieComposition = await LottieComposition.fromByteData(data);
    } catch (_) {}

    try {
      final data = await rootBundle.load('assets/lottie/Animation - 1727287595969.json');
      globalEmptyContactsLottieComposition = await LottieComposition.fromByteData(data);
    } catch (_) {}

    try {
      final data = await rootBundle.load('assets/lottie/Success Animation 2.json');
      globalSuccessLottieComposition = await LottieComposition.fromByteData(data);
    } catch (_) {}
  });
}

class SmartCardsApp extends ConsumerWidget {
  const SmartCardsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeViewModelProvider);
    return MaterialApp(
      navigatorKey: DioClient.navigatorKey,
      title: 'Smart Cards',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(themeState.themeMode),
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
    final themeState = ref.watch(themeViewModelProvider);
    final bgStart = themeState.colors.backgroundStart;
    final bgEnd = themeState.colors.backgroundEnd;

    final customState = ref.watch(customizationControllerProvider);
    final bgImageEnabled = customState.activeProfile.bgImageEnabled;
    final bgImagePath = customState.activeProfile.backgroundImagePath;

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

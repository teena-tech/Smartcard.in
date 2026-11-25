import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rive/rive.dart' hide File;
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/home_screen.dart';
import 'package:smartcard_flutter/features/landing_screen/presentation/view/landing_screen.dart';
import 'package:smartcard_flutter/core/widgets/lottie_loader.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final authViewModel = ref.read(authViewModelProvider.notifier);
    await authViewModel.checkAuthStatus();

    // Allow splash Rive animation to play smoothly
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (authViewModel.isAuthenticated) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LandingScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.backgroundStart, colors.backgroundEnd],
          ),
        ),
        child: Stack(
          children: [
            // Full-screen Rive animation background
            Positioned.fill(
              child: RiveWidgetBuilder(
                fileLoader: FileLoader.fromAsset(
                  "assets/rive/splash_screen_animation_2.riv",
                  riveFactory: Factory.rive,
                ),
                builder: (context, state) => switch (state) {
                  RiveLoaded(controller: final controller) => RiveWidget(
                      controller: controller,
                      fit: Fit.cover,
                    ),
                  _ => const Center(child: LottieLoader(size: 90)),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final landingViewModel = ref.read(landingViewModelProvider.notifier);

    // Bootstrap auth status and preload welcome slides concurrently during splash reveal
    await Future.wait([
      authViewModel.checkAuthStatus(),
      landingViewModel.fetchSlides(),
      Future<void>.delayed(const Duration(milliseconds: 750)),
    ]);

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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/smartlogo.png',
                height: 110,
                fit: BoxFit.contain,
              )
                  .animate()
                  .fadeIn(duration: 450.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              const LottieLoader(size: 56),
            ],
          ),
        ),
      ),
    );
  }
}

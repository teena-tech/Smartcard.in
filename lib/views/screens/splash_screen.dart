import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' hide File;
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import 'home_screen.dart';
import 'landing_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    final authViewModel = context.read<AuthViewModel>();
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
    final colors = context.watch<ThemeViewModel>().colors;

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
                  _ => const SizedBox.shrink(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

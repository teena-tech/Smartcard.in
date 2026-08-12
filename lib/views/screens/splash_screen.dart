import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rive/rive.dart' hide Image, LinearGradient;
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
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authViewModel = context.read<AuthViewModel>();
    await authViewModel.checkAuthStatus();
    if (!mounted) return;

    final Widget nextPage = authViewModel.isAuthenticated
        ? const HomeScreen(initialIndex: 0)
        : const LandingScreen();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
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
              child: RiveAnimation.asset(
                "assets/rive/splash_screen_animation_2.riv",
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

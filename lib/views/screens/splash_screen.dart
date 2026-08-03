import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/state/app_loading_service.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import '../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrap();
    });
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!context.mounted) return;

    final authViewModel = context.read<AuthViewModel>();

    // If auth check is still loading, wait for it (max 3 seconds)
    if (authViewModel.state == AuthState.loading ||
        authViewModel.state == AuthState.initial) {
      try {
        await authViewModel.checkAuthStatus().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            // On timeout, treat as unauthenticated
          },
        );
      } catch (_) {
        // Ignore errors — let the state decide where to navigate
      }
    }

    if (!context.mounted || _navigated) return;
    _navigate(authViewModel);
  }


  void _navigate(AuthViewModel authViewModel) {
    if (_navigated || !context.mounted) return;
    _navigated = true;

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
    return const Scaffold(
      body: Stack(
        children: [
          // Full-screen Rive animation background
          Positioned.fill(
            child: Center(
              child: Image(
                image: AssetImage('assets/images/smartlogo.png'),
                width: 180,
                height: 180,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

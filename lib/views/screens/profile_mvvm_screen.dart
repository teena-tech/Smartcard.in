import 'package:flutter/material.dart';
import 'profile_screen.dart';

// This screen acts as a simple wrapper for the existing ProfileScreen.
// It satisfies the import reference used in main.dart routes.
// Future MVVM enhancements can be added here.
class ProfileMvvmScreen extends StatelessWidget {
  const ProfileMvvmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

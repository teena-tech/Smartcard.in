import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/master_bottom_nav.dart';

class GlobalBottomNav extends ConsumerWidget {
  const GlobalBottomNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardViewModel = ref.watch(dashboardViewModelProvider);
    final int rawIndex = dashboardViewModel.currentIndex;

    int activeIndex;
    if (rawIndex == 0) {
      activeIndex = 0; // Home
    } else if (rawIndex == 4) {
      activeIndex = 1; // Contacts
    } else if (rawIndex == 1) {
      activeIndex = 2; // Scan
    } else if (rawIndex == 9) {
      activeIndex = 3; // Share
    } else {
      activeIndex = 0; // Default to Home
    }

    return MasterBottomNav(
      currentIndex: activeIndex,
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'master_bottom_nav.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardViewModel = context.watch<DashboardViewModel>();
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


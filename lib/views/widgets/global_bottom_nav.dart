import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'master_bottom_nav.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardViewModel = context.watch<DashboardViewModel>();
    final activeIndex = dashboardViewModel.currentIndex == 9 ? 2 : (dashboardViewModel.currentIndex > 2 ? 0 : dashboardViewModel.currentIndex);
    return MasterBottomNav(
      currentIndex: activeIndex,
    );
  }
}


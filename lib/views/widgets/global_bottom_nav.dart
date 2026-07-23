import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'custom_bottom_nav.dart';

class GlobalBottomNav extends StatelessWidget {
  const GlobalBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final dashboardViewModel = context.watch<DashboardViewModel>();
    return CustomBottomNav(
      currentIndex: dashboardViewModel.currentIndex > 3 ? 0 : dashboardViewModel.currentIndex,
      onTap: (index) {
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        if (index == 2) {
          dashboardViewModel.setIndex(9); // MyCardsScreen
        } else {
          dashboardViewModel.setIndex(index);
        }
      },
    );
  }
}

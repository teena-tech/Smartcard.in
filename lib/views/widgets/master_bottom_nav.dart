import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class MasterBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const MasterBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const tabs = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.qr_code_scanner_outlined),
        activeIcon: Icon(Icons.qr_code_scanner),
        label: 'Scan',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.share_outlined),
        activeIcon: Icon(Icons.share),
        label: 'Share',
      ),
    ];

    final effectiveIndex = currentIndex >= tabs.length ? 0 : currentIndex;

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: AppColors.primaryRed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 12),
        currentIndex: effectiveIndex,
        onTap: onTap ??
            (index) {
              final dashboardViewModel = context.read<DashboardViewModel>();
              final targetIndex = index == 2 ? 9 : index;
              if (Navigator.canPop(context)) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
              dashboardViewModel.setIndex(targetIndex);
            },
        items: tabs,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import '../../core/constants/app_colors.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class MasterBottomNav extends ConsumerWidget {
  final int? currentIndex;
  final ValueChanged<int>? onTap;

  const MasterBottomNav({
    super.key,
    this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const tabs = [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.contacts_outlined),
        activeIcon: Icon(Icons.contacts),
        label: 'Contacts',
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

    int computedIndex;
    if (currentIndex != null) {
      computedIndex = currentIndex!;
    } else {
      final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
          context.findAncestorWidgetOfExactType<ProviderScope>() != null;
      final rawIndex = hasScope
          ? ref.watch(tabIndexProvider)
          : legacy.Provider.of<DashboardViewModel>(context, listen: false).currentIndex;
      if (rawIndex == 0) {
        computedIndex = 0;
      } else if (rawIndex == 4) {
        computedIndex = 1;
      } else if (rawIndex == 1) {
        computedIndex = 2;
      } else if (rawIndex == 9) {
        computedIndex = 3;
      } else {
        computedIndex = 0;
      }
    }
    final effectiveIndex = computedIndex >= tabs.length ? 0 : computedIndex;

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5)),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.primaryRed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11.5),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 11.5),
        currentIndex: effectiveIndex,
        onTap: (index) {
          AppHaptics.selection();
          if (onTap != null) {
            onTap!(index);
            return;
          }
          final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
              context.findAncestorWidgetOfExactType<ProviderScope>() != null;
          int targetIndex;
          switch (index) {
            case 0:
              targetIndex = 0; // Home
              break;
            case 1:
              targetIndex = 4; // Contacts
              break;
            case 2:
              targetIndex = 1; // Scan
              break;
            case 3:
              targetIndex = 9; // Share
              break;
            default:
              targetIndex = 0;
          }

          if (Navigator.canPop(context)) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          if (hasScope) {
            ref.read(tabIndexProvider.notifier).setIndex(targetIndex);
            ref.read(dashboardViewModelProvider).setIndex(targetIndex);
          } else {
            legacy.Provider.of<DashboardViewModel>(context, listen: false).setIndex(targetIndex);
          }
        },
        items: tabs,
      ),
    );
  }
}

/// Legacy alias for MasterBottomNav to prevent breaking screens during consolidation
typedef GlobalBottomNav = MasterBottomNav;

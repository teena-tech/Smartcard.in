import 'package:flutter/material.dart';
import 'master_bottom_nav.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MasterBottomNav(
      currentIndex: currentIndex,
      onTap: onTap,
    );
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';

class ThemeToggleSwitch extends StatelessWidget {
  final double width;
  final double height;

  const ThemeToggleSwitch({
    super.key,
    this.width = 66,
    this.height = 32,
  });

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();
    final isDark = themeViewModel.themeMode != AppThemeMode.light;

    return Semantics(
      label: 'Toggle Theme',
      button: true,
      child: GestureDetector(
        onTap: () {
          final nextMode = isDark ? AppThemeMode.light : AppThemeMode.dark;
          themeViewModel.setTheme(nextMode);
        },
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              // Animated slider thumb background
              AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: height - 8,
                  height: height - 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Sun & Moon Icons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sun Icon (Light Mode)
                  Container(
                    width: height - 8,
                    height: height - 8,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.wb_sunny_outlined,
                      size: 15,
                      color: !isDark ? const Color(0xFFFFD54F) : Colors.white60,
                    ),
                  ),

                  // Crescent Moon Icon (Dark Mode)
                  Container(
                    width: height - 8,
                    height: height - 8,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.nightlight_round,
                      size: 14,
                      color: isDark ? Colors.white : Colors.white60,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

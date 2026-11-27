import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/app_haptics.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';

class _BottomNavItemData {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int targetIndex;

  const _BottomNavItemData({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.targetIndex,
  });
}

class MasterBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const MasterBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeVm = ref.watch(themeViewModelProvider);
    final colors = themeVm.colors;
    final isDark = themeVm.themeMode != AppThemeMode.light;

    const navItems = [
      _BottomNavItemData(
        activeIcon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
        label: 'Home',
        targetIndex: 0,
      ),
      _BottomNavItemData(
        activeIcon: Icons.people_rounded,
        inactiveIcon: Icons.people_outline_rounded,
        label: 'Contacts',
        targetIndex: 4,
      ),
      _BottomNavItemData(
        activeIcon: Icons.qr_code_scanner_rounded,
        inactiveIcon: Icons.qr_code_scanner_rounded,
        label: 'Scan',
        targetIndex: 1,
      ),
      _BottomNavItemData(
        activeIcon: Icons.share_rounded,
        inactiveIcon: Icons.share_outlined,
        label: 'Share',
        targetIndex: 9,
      ),
    ];

    final effectiveIndex = currentIndex.clamp(0, navItems.length - 1);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colors.card : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              final isSelected = effectiveIndex == index;

              return _BottomNavItemWidget(
                item: item,
                isSelected: isSelected,
                isDark: isDark,
                onTap: () {
                  if (onTap != null) {
                    onTap!(index);
                    return;
                  }
                  final dashboardViewModel = ref.read(dashboardViewModelProvider.notifier);
                  if (Navigator.canPop(context)) {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  }
                  dashboardViewModel.setIndex(item.targetIndex);
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItemWidget extends StatefulWidget {
  final _BottomNavItemData item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _BottomNavItemWidget({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_BottomNavItemWidget> createState() => _BottomNavItemWidgetState();
}

class _BottomNavItemWidgetState extends State<_BottomNavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.12)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.12, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
    ]).animate(_shimmerController);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void _triggerTap() {
    AppHaptics.selection();
    _shimmerController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final isAnimating = _shimmerController.isAnimating;

        Widget iconWidget = Icon(
          widget.isSelected ? widget.item.activeIcon : widget.item.inactiveIcon,
          color: widget.isSelected
              ? AppColors.primaryRed
              : AppColors.primaryRed.withValues(alpha: 0.75),
          size: 24,
        );

        if (isAnimating) {
          iconWidget = ShaderMask(
            shaderCallback: (bounds) {
              final double shift = -1.5 + (_shimmerController.value * 3.0);
              return LinearGradient(
                begin: Alignment(shift - 0.4, -0.3),
                end: Alignment(shift + 0.4, 0.3),
                colors: const [
                  AppColors.primaryRed,
                  Color(0xFFFFD700), // Rich Gold
                  Color(0xFFFFFFFF), // Pure Silver shimmer
                  Color(0xFFE2E8F0), // Platinum Silver
                  Color(0xFFF59E0B), // Warm Gold
                  AppColors.primaryRed,
                ],
                stops: const [0.0, 0.22, 0.45, 0.65, 0.85, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: iconWidget,
          );
        }

        return ScaleTransition(
          scale: isAnimating ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
          child: InkWell(
            onTap: _triggerTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: const Color(0xFFFFD700).withValues(alpha: 0.25),
            highlightColor: const Color(0xFFE2E8F0).withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? (widget.isDark
                              ? AppColors.primaryRed.withValues(alpha: 0.25)
                              : const Color(0xFFFFDADA))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: widget.isSelected
                          ? Border.all(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              width: 1.0,
                            )
                          : null,
                    ),
                    child: iconWidget,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.item.label,
                    style: AppFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: widget.isSelected
                          ? AppColors.primaryRed
                          : (widget.isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                  if (widget.isSelected) ...[
                    const SizedBox(height: 3),
                    Container(
                      width: 4.5,
                      height: 4.5,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ] else
                    const SizedBox(height: 7.5),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

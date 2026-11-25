import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/constants/app_theme.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/view/subscription_screen.dart';
import 'package:smartcard_flutter/features/subscription_screen/presentation/viewmodel/subscription_viewmodel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = ref.read(authViewModelProvider.notifier);
      final userId = authVm.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final profileVm = ref.read(profileViewModelProvider.notifier);
        if (profileVm.user == null) {
          profileVm.loadProfile(userId);
        }
        ref.read(subscriptionViewModelProvider.notifier).fetchSubscription(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeViewModelProvider);
    final isDark = themeState.themeMode == AppThemeMode.dark ||
        Theme.of(context).brightness == Brightness.dark;

    final profileState = ref.watch(profileViewModelProvider);
    final subState = ref.watch(subscriptionViewModelProvider);
    final authState = ref.watch(authViewModelProvider);

    final user = profileState.user ?? authState.currentUser;
    final isPremium = subState.subscription?.isActive == true ||
        subState.subscription?.membership == 'PREMIUM';

    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim();
    final effectiveName = displayName.isNotEmpty ? displayName : 'User';
    final profileImage = user?.profileImage;

    final primaryRed = AppColors.primaryRed;
    final cardBg = isDark ? const Color(0xFF1E233A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E233A);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141729) : const Color(0xFFF8F9FA),
        image: isDark
            ? null
            : const DecorationImage(
                image: AssetImage('assets/images/login.png'),
                fit: BoxFit.cover,
              ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top User Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18.0),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryRed.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          ref.read(dashboardViewModelProvider.notifier).setIndex(3);
                        },
                        child: CircularProfileAvatar(
                          radius: 34,
                          size: 68,
                          imageUrl: profileImage != null && profileImage.isNotEmpty
                              ? UploadUrlResolver.resolve(profileImage, type: 'profile')
                              : null,
                          fallbackText: effectiveName.isNotEmpty ? effectiveName[0].toUpperCase() : 'U',
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      if (isPremium)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: primaryRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Text('👑', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          effectiveName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user?.email?.isNotEmpty == true
                              ? user!.email!
                              : (user?.phone ?? ''),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        if (!isPremium)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SubscriptionScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryRed.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryRed,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                'UPGRADE TO PREMIUM',
                                style: GoogleFonts.inter(
                                  color: primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.shade400, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 14, color: Colors.green),
                                const SizedBox(width: 4),
                                Text(
                                  'PREMIUM MEMBER',
                                  style: GoogleFonts.inter(
                                    color: Colors.green.shade800,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Profile Tile
            _buildSettingItem(
              context: context,
              title: 'Personal & Profile Details',
              subtitle: 'Update your personal details, photo, address, and contacts.',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              onTap: () {
                ref.read(dashboardViewModelProvider.notifier).setIndex(3);
              },
            ),

            const SizedBox(height: 14),

            // Subscription Tile
            _buildSettingItem(
              context: context,
              title: 'Subscription & Membership',
              subtitle: 'Check active plan, validity, discounts, and renewal.',
              icon: Icons.card_membership_rounded,
              isDark: isDark,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              },
            ),

            const SizedBox(height: 14),

            // Dark Mode / Theme Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: primaryRed.withValues(alpha: 0.35),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryRed.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: primaryRed,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Theme Mode',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDark ? 'Dark theme enabled' : 'Light theme enabled',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: isDark,
                    activeColor: primaryRed,
                    onChanged: (val) {
                      ref.read(themeViewModelProvider.notifier).setTheme(
                            val ? AppThemeMode.dark : AppThemeMode.light,
                          );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Support & Help Tile
            _buildSettingItem(
              context: context,
              title: 'Help & Customer Support',
              subtitle: 'Chat with support agent, FAQs, or submit feedback.',
              icon: Icons.support_agent_rounded,
              isDark: isDark,
              onTap: () {
                ref.read(dashboardViewModelProvider.notifier).setIndex(6);
              },
            ),

            const SizedBox(height: 14),

            // About Screen Tile
            _buildSettingItem(
              context: context,
              title: 'About Smart Cards',
              subtitle: 'App version 1.0.0, terms of service & privacy policy.',
              icon: Icons.info_outline_rounded,
              isDark: isDark,
              onTap: () {
                ref.read(dashboardViewModelProvider.notifier).setIndex(8);
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final primaryRed = AppColors.primaryRed;
    final cardBg = isDark ? const Color(0xFF1E233A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E233A);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: primaryRed.withValues(alpha: 0.35),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primaryRed, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: subtitleColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded, size: 15, color: primaryRed),
          ],
        ),
      ),
    );
  }
}

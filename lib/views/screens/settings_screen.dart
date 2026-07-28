import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import 'subscription_screen.dart';
import '../widgets/circular_profile_avatar.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../viewmodels/dashboard_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Load profile and subscription data when settings screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      final profileVm = context.read<ProfileViewModel>();
      final subVm = context.read<SubscriptionViewModel>();
      final userId = authVm.currentUser?.id;
      if (userId != null) {
        if (profileVm.user == null) {
          profileVm.loadProfile(userId);
        }
        subVm.fetchSubscription(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibrantRed = const Color(0xFFE30613);
    final darkBlue = const Color(0xFF1E233A);
    final softPinkishWhite = const Color(0xFFFFF0F2);
    final mutedText = Colors.grey.shade600;

    final profileViewModel = context.watch<ProfileViewModel>();
    final subscriptionViewModel = context.watch<SubscriptionViewModel>();
    final user = profileViewModel.user;
    final profileImage = user?.profileImage;

    final isPremium = subscriptionViewModel.subscription?.isActive == true &&
        subscriptionViewModel.subscription?.membership.toUpperCase() != 'FREE';

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Top User Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.read<DashboardViewModel>().setIndex(3);
                        },
                        child: CircularProfileAvatar(
                          radius: 35,
                          size: 70,
                          imageUrl: profileImage != null && profileImage.isNotEmpty
                              ? UploadUrlResolver.resolve(profileImage, type: 'profile')
                              : null,
                          fallbackText: user?.initials ?? 'U',
                          backgroundColor: vibrantRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'User',
                              style: GoogleFonts.inter(
                                color: darkBlue,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: GoogleFonts.inter(
                                color: mutedText,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: vibrantRed, width: 1.5),
                                ),
                                child: Text(
                                  isPremium ? 'PREMIUM PLAN' : 'UPGRADE TO PREMIUM',
                                  style: GoogleFonts.inter(
                                    color: vibrantRed,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                ],
              ),
            ),

            const SizedBox(height: 16),

            // Settings Card: Profile
            _buildSettingItem(
              context: context,
              title: 'Profile',
              subtitle: 'Update your personal details, photo, address, and password.',
              icon: Icons.person_outline,
              onTap: () {
                context.read<DashboardViewModel>().setIndex(3);
              },
            ),

            const SizedBox(height: 16),

            // Settings Card: Subscription
            _buildSettingItem(
              context: context,
              title: 'Subscription',
              subtitle: 'Check your current plan, coupon status, payment, and renewal details.',
              icon: Icons.credit_card,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
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
    required VoidCallback onTap,
  }) {
    final darkBlue = const Color(0xFF1E233A);
    final mutedText = Colors.grey.shade600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: darkBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: darkBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: mutedText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color darkBlue, Color vibrantRed) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: darkBlue,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

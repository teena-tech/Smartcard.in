import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../../core/network/dio_client.dart';

class ProfileMenuBottomSheet extends ConsumerStatefulWidget {
  const ProfileMenuBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ProfileMenuBottomSheet(),
    );
  }

  @override
  ConsumerState<ProfileMenuBottomSheet> createState() => _ProfileMenuBottomSheetState();
}

class _ProfileMenuBottomSheetState extends ConsumerState<ProfileMenuBottomSheet> {
  int? _selectedMenuIndex;

  void _navigateToTab(BuildContext context, int tabIndex) {
    Navigator.pop(context); // Close bottom sheet
    try {
      ref.read(tabIndexProvider.notifier).setIndex(tabIndex);
      final dashboardVm = ref.read(dashboardViewModelProvider);
      dashboardVm.setIndex(tabIndex);
      // If we are currently pushed into a sub-page, pop back to home tabs
      if (Navigator.canPop(context)) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (_) {
      // Fallback if DashboardViewModel is not in context
    }
  }

  void _openProfileScreen(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  void _showFutureVersionDialog(BuildContext context) {
    final colors = ref.read(themeViewModelProvider).colors;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge Icon
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: AppColors.primaryRed,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),

            // In Development Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryRed.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                'âš¡ In Active Development',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              'Notification Center',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.text,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Professional Developer Description
            Text(
              'We are currently engineering a centralized notification system to bring you real-time alerts for card visits, new contact exchanges, and smart interactions.\n\nThis will be rolled out in an upcoming release!',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colors.muted,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Got It, Stay Tuned!',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeViewModelProvider).colors;
    final profileViewModel = ref.watch(profileViewModelProvider);
    final authViewModel = ref.watch(authViewModelProvider);
    final cardViewModel = ref.watch(cardViewModelProvider);
    final subscriptionViewModel = ref.watch(subscriptionViewModelProvider);

    final user = profileViewModel.user ?? authViewModel.currentUser;
    final isPremium = subscriptionViewModel.isPremium;

    // Resolve profile avatar image
    String? cardImage;
    final primaryCard = cardViewModel.primaryCard;
    if (primaryCard?.profileImageName != null && primaryCard!.profileImageName!.trim().isNotEmpty) {
      cardImage = primaryCard.profileImageName!.trim();
    } else {
      for (final card in cardViewModel.cards) {
        if (card.profileImageName != null && card.profileImageName!.trim().isNotEmpty) {
          cardImage = card.profileImageName!.trim();
          break;
        }
      }
    }
    if (cardImage == null || cardImage.isEmpty) {
      if (user?.profileImage != null && user!.profileImage!.trim().isNotEmpty) {
        cardImage = user.profileImage!.trim();
      }
    }

    final displayName = (user?.displayName.isNotEmpty == true) ? user!.displayName : 'User';
    final phoneOrEmail = (user?.phone?.isNotEmpty == true ? user!.phone! : null) ??
        (user?.email?.isNotEmpty == true ? user!.email! : null) ??
        '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // â”€â”€ Top Red Profile Header Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              _buildHeaderBanner(
                context: context,
                userId: user?.id,
                displayName: displayName,
                phoneOrEmail: phoneOrEmail,
                cardImage: cardImage,
                isPremium: isPremium,
                userInitials: displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                onProfileTap: () => _openProfileScreen(context),
              ),

              // â”€â”€ Theme-Aware Inner Menu Container BG â”€â”€
              Builder(
                builder: (context) {
                  final themeVm = ref.watch(themeViewModelProvider);
                  final isDark = themeVm.themeMode != AppThemeMode.light;
                  return Transform.translate(
                    offset: const Offset(0, -14),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        gradient: isDark
                            ? LinearGradient(
                                colors: [
                                  colors.panel,
                                  colors.card,
                                  colors.backgroundStart,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : const LinearGradient(
                                colors: [
                                  Color(0xFFFFFFFF), // Crisp White at top
                                  Color(0xFFFFF8F2), // Warm Cream
                                  Color(0xFFFFEDE6), // Creamy Blush
                                  Color(0xFFFFDCD4), // Soft Red Glow at bottom
                                ],
                                stops: [0.0, 0.32, 0.68, 1.0],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                            blurRadius: 18,
                            offset: const Offset(0, -6),
                          ),
                        ],
                        border: isDark
                            ? Border.all(color: colors.border.withValues(alpha: 0.15), width: 1)
                            : null,
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      child: Column(
                        children: [
                          // â”€â”€ 6 Menu Actions Grid (3 Columns x 2 Rows) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                          Row(
                            children: [
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.person_rounded,
                                  title: 'Edit Profile',
                                  subtitle: 'Update your details',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 0,
                                  onSelect: () => setState(() => _selectedMenuIndex = 0),
                                  onTap: () => _openProfileScreen(context),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.people_alt_rounded,
                                  title: 'Contacts',
                                  subtitle: 'View your contacts',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 1,
                                  onSelect: () => setState(() => _selectedMenuIndex = 1),
                                  onTap: () => _navigateToTab(context, 4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.notifications_rounded,
                                  title: 'Notifications',
                                  subtitle: 'See latest updates',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 2,
                                  badgeCount: 0,
                                  onSelect: () => setState(() => _selectedMenuIndex = 2),
                                  onTap: () => _showFutureVersionDialog(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Row 2: Settings | Support | About
                          Row(
                            children: [
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.settings_rounded,
                                  title: 'Settings',
                                  subtitle: 'App preferences',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 3,
                                  onSelect: () => setState(() => _selectedMenuIndex = 3),
                                  onTap: () => _navigateToTab(context, 7),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.headset_mic_rounded,
                                  title: 'Support',
                                  subtitle: 'Get help',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 4,
                                  onSelect: () => setState(() => _selectedMenuIndex = 4),
                                  onTap: () => _navigateToTab(context, 6),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MenuActionCard(
                                  icon: Icons.info_rounded,
                                  title: 'About',
                                  subtitle: 'App information',
                                  colors: colors,
                                  isSelected: _selectedMenuIndex == 5,
                                  onSelect: () => setState(() => _selectedMenuIndex = 5),
                                  onTap: () => _navigateToTab(context, 8),
                                ),
                              ),
                            ],
                          ),



                          const SizedBox(height: 16),

                          // â”€â”€ Logout Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                final navigator = Navigator.of(context, rootNavigator: true);
                                final messageVm = ref.read(messageViewModelProvider);
                                final authVm = ref.read(authViewModelProvider);
                                final profileVm = ref.read(profileViewModelProvider);
                                final cardVm = ref.read(cardViewModelProvider);

                                Navigator.of(context).pop();

                                try {
                                  messageVm.stopPolling();
                                } catch (_) {}

                                try {
                                  await authVm.logout();
                                } catch (_) {}

                                try {
                                  profileVm.clearUser();
                                } catch (_) {}

                                try {
                                  cardVm.clearMessages();
                                } catch (_) {}

                                try {
                                  navigator.pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                                    (route) => false,
                                  );
                                } catch (_) {
                                  DioClient.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                                    '/login',
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE50000),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(0xFFE50000).withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout_rounded, size: 24, color: Colors.white),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Logout',
                                    style: GoogleFonts.inter(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner({
    required BuildContext context,
    required String? userId,
    required String displayName,
    required String phoneOrEmail,
    required String? cardImage,
    required bool isPremium,
    required String userInitials,
    required VoidCallback onProfileTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFE50914), // Vivid Bloody Red
            Color(0xFFB80000), // Deep Crimson
            Color(0xFF8B0000), // Rich Dark Red
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Background decorative curves
          Positioned.fill(
            child: CustomPaint(
              painter: _BannerCurvePainter(),
            ),
          ),

          // Main Header Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Centered drag handle bar
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Main Profile Row: [ Profile Image ]   [ Name & Number ]   [ Stay Connected ]
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Circular Profile Avatar (small, perfectly circular, crystal clear)
                    GestureDetector(
                      onTap: onProfileTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2.5),
                            ),
                          ],
                        ),
                        child: Hero(
                          tag: 'profile_bottom_sheet_avatar_${userId ?? 'current'}',
                          child: ClipOval(
                            child: (cardImage != null && cardImage.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: UploadUrlResolver.resolve(cardImage, type: 'profile'),
                                    fit: BoxFit.cover,
                                    filterQuality: FilterQuality.high,
                                    placeholder: (ctx, url) => Container(
                                      color: Colors.white,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            color: AppColors.primaryRed,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: Colors.white,
                                      alignment: Alignment.center,
                                      child: Text(
                                        userInitials,
                                        style: GoogleFonts.outfit(
                                          color: AppColors.primaryRed,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.white,
                                    alignment: Alignment.center,
                                    child: Text(
                                      userInitials,
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primaryRed,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // User Details: Name & Number (straight across from profile image)
                    Expanded(
                      child: GestureDetector(
                        onTap: onProfileTap,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // User Name - Normal weight, not bold, dynamically scales down for big names
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.normal,
                                  letterSpacing: 0.2,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                              ),
                            ),

                            if (phoneOrEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  phoneOrEmail,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Golden cursive Stay Connected with typewriter + heartbeat animation
                    const _TypewriterHeartbeatStayConnected(),
                  ],
                ),

                const SizedBox(height: 6),

                // Membership Badge: left-aligned with Name & Phone (44 avatar + 12 gap = 56)
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: GestureDetector(
                    onTap: onProfileTap,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isPremium ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0),
                          width: 1.3,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isPremium)
                            const Text(
                              '👑 ',
                              style: TextStyle(fontSize: 10.5),
                            )
                          else
                            const Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: Color(0xFFE0E0E0),
                            ),
                          if (!isPremium) const SizedBox(width: 4),
                          Text(
                            isPremium ? 'Premium Member' : 'Free Member',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isPremium ? const Color(0xFFFFD700) : const Color(0xFFE0E0E0),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated cursive "Stay Connected" with write-in (typewriter) effect followed by heartbeat pulse
class _TypewriterHeartbeatStayConnected extends StatefulWidget {
  const _TypewriterHeartbeatStayConnected();

  @override
  State<_TypewriterHeartbeatStayConnected> createState() =>
      _TypewriterHeartbeatStayConnectedState();
}

class _TypewriterHeartbeatStayConnectedState
    extends State<_TypewriterHeartbeatStayConnected>
    with TickerProviderStateMixin {
  late final AnimationController _writeController;
  late final AnimationController _heartbeatController;
  late final Animation<double> _scaleAnimation;
  static const String _fullText = 'Stay\nConnected';

  @override
  void initState() {
    super.initState();
    // Typewriter effect controller (writing in)
    _writeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Heartbeat pulse controller
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 0.96)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.96, end: 1.04)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 20.0,
      ),
    ]).animate(_heartbeatController);

    // Start typewriter writing effect first, then start looping heartbeat
    _writeController.forward().then((_) {
      if (mounted) {
        _heartbeatController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _writeController.dispose();
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_writeController, _heartbeatController]),
      builder: (context, child) {
        final progress = _writeController.value;
        final currentLength =
            (progress * _fullText.length).round().clamp(0, _fullText.length);
        final visibleText = _fullText.substring(0, currentLength);

        return Transform.rotate(
          angle: -0.08,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Text(
              visibleText,
              textAlign: TextAlign.center,
              style: GoogleFonts.caveat(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFFD700),
                height: 0.95,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                  Shadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final AppColors colors;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onTap;
  final int? badgeCount;

  const _MenuActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.isSelected,
    required this.onSelect,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<_MenuActionCard> createState() => _MenuActionCardState();
}

class _MenuActionCardState extends State<_MenuActionCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _strokeController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    // Animated red stroke controller
    _strokeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    // Subtle heartbeat / pulse animation: 1.0 â†’ 1.05 â†’ 0.98 â†’ 1.02 â†’ 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 0.98)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.98, end: 1.02)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.02, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 25.0,
      ),
    ]).animate(_pulseController);
  }

  @override
  void didUpdateWidget(covariant _MenuActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _strokeController.forward(from: 0.0);
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _strokeController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _strokeController.dispose();
    super.dispose();
  }

  void _triggerTap() {
    widget.onSelect();
    _pulseController.forward(from: 0.0);
    _strokeController.forward(from: 0.0);
    // Allow user to visibly experience the animated red stroke and subtle heartbeat
    Future.delayed(const Duration(milliseconds: 240), () {
      if (mounted) {
        widget.onTap();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelected = widget.isSelected;
    final colors = widget.colors;

    // Selected state colors: Text is Red, Icon is Gold
    const Color activeRed = Color(0xFFE50914);
    const Color activeGold = Color(0xFFFFD700);

    // Unselected colors: Existing colors retained
    final Color unselectedIcon = const Color(0xFFE50000);
    final Color unselectedIconBg = colors.isDark
        ? const Color(0xFFE50000).withValues(alpha: 0.15)
        : const Color(0xFFFFECEC);

    Widget cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? (colors.isDark
                ? Color.lerp(colors.card, activeRed, 0.08)
                : Color.lerp(colors.card, const Color(0xFFFFECEC), 0.4))
            : colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? activeRed.withValues(alpha: 0.5)
              : colors.border,
          width: isSelected ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? activeRed.withValues(alpha: 0.22)
                : (colors.isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.04)),
            blurRadius: isSelected ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular icon container
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isSelected
                  ? activeGold.withValues(alpha: 0.16)
                  : unselectedIconBg,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: activeGold.withValues(alpha: 0.4),
                      width: 1.2,
                    )
                  : null,
            ),
            child: Icon(
              widget.icon,
              color: isSelected ? activeGold : unselectedIcon,
              size: 24,
            ),
          ),

          const SizedBox(height: 10),

          // Title - Red when selected, colors.text when unselected
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? activeRed : colors.text,
                ),
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 2),

          // Subtitle - Red when selected, colors.muted when unselected
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isSelected
                    ? activeRed.withValues(alpha: 0.85)
                    : colors.muted,
                  fontWeight: FontWeight.w400,
                ),
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.badgeCount != null && widget.badgeCount! > 0) {
      cardWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          cardWidget,
          Positioned(
            top: -2,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
              child: Center(
                child: Text(
                  '${widget.badgeCount}',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _strokeController]),
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTapDown: (_) => widget.onSelect(),
              onTap: _triggerTap,
              borderRadius: BorderRadius.circular(20),
              child: CustomPaint(
                foregroundPainter: _AnimatedRedStrokePainter(
                  progress: _strokeController.value,
                  isSelected: isSelected,
                  strokeColor: activeRed,
                ),
                child: cardWidget,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter to draw an animated glowing red stroke effect around the menu card box
class _AnimatedRedStrokePainter extends CustomPainter {
  final double progress;
  final bool isSelected;
  final Color strokeColor;

  _AnimatedRedStrokePainter({
    required this.progress,
    required this.isSelected,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isSelected && progress == 0.0) return;

    final strokeWidth = isSelected ? 2.2 : 1.4;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      const Radius.circular(20),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;

    final currentProgress = progress > 0.0 ? progress : (isSelected ? 1.0 : 0.0);
    if (currentProgress <= 0.0) return;

    final extractPath = metric.extractPath(0.0, metric.length * currentProgress);

    // Outer red glow aura
    final glowPaint = Paint()
      ..color = strokeColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    // Crisp vivid red stroke
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(extractPath, glowPaint);
    canvas.drawPath(extractPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedRedStrokePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class _BannerCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintWhite1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final paintWhite2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.2,
      size.width,
      size.height * 0.75,
    );
    canvas.drawPath(path1, paintWhite1);

    final path2 = Path();
    path2.moveTo(size.width * 0.15, size.height);
    path2.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.45,
      size.width,
      size.height * 0.9,
    );
    canvas.drawPath(path2, paintWhite2);

    final path3 = Path();
    path3.moveTo(size.width * 0.5, 0);
    path3.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.35,
      0,
      size.height * 0.65,
    );
    canvas.drawPath(path3, paintWhite2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


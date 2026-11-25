import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';
import 'package:smartcard_flutter/features/full_card_view_screen/presentation/view/widgets/rotating_profile_avatar_ring.dart';
import 'package:smartcard_flutter/core/widgets/smart_cards_logo.dart';
import 'package:smartcard_flutter/core/widgets/theme_toggle_switch.dart';
import 'package:smartcard_flutter/core/widgets/profile_menu_bottom_sheet.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';

enum MasterHeaderStyle {
  standard,
  gradient,
  transparent,
}

class MasterAppBarPainter extends CustomPainter {
  final double curveDepth;
  final Gradient gradient;

  const MasterAppBarPainter({
    this.curveDepth = 18.0,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + curveDepth,
      size.width,
      size.height,
    );
    path.lineTo(size.width, 0);
    path.close();

    // Soft drop shadow
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.28),
      4.0,
      false,
    );

    // Gradient fill
    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & Size(size.width, size.height + curveDepth))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MasterAppBarPainter oldDelegate) =>
      oldDelegate.curveDepth != curveDepth || oldDelegate.gradient != gradient;
}

class CurvedHeaderClipper extends CustomClipper<Path> {
  final double curveDepth;

  const CurvedHeaderClipper({this.curveDepth = 22.0});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - curveDepth);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - curveDepth,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CurvedHeaderClipper oldClipper) =>
      oldClipper.curveDepth != curveDepth;
}

class MasterAppBar extends ConsumerWidget implements PreferredSizeWidget {
  static const double curveHeight = 16.0;

  final Widget? title;
  final String? titleText;
  final MasterHeaderStyle style;
  final VoidCallback? onProfileTap;
  final bool showProfile;
  final bool isProfilePage;
  final bool? showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? extraActions;
  final Color? backgroundColor;
  final Widget? leading;
  final bool? showThemeToggle;
  final bool? showModeToggle;

  const MasterAppBar({
    super.key,
    this.title,
    this.titleText,
    this.style = MasterHeaderStyle.gradient,
    this.onProfileTap,
    this.showProfile = true,
    this.isProfilePage = false,
    this.showBackButton,
    this.onBackTap,
    this.extraActions,
    this.backgroundColor,
    this.leading,
    this.showThemeToggle,
    this.showModeToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeViewModelProvider);
    final profileViewModel = ref.watch(profileViewModelProvider);
    final authViewModel = ref.watch(authViewModelProvider);
    final cardViewModel = ref.watch(cardViewModelProvider);
    final user = profileViewModel.user ?? authViewModel.currentUser;
    
    // Mandatory Profile Image Waterfall Resolution:
    // 1. Primary Card Profile Image
    // 2. Secondary Card Profile Image (first available)
    // 3. User Profile Image
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

    final headerTextColor = Colors.white;
    final canPop = showBackButton ?? Navigator.canPop(context);
    final isTransparent = style == MasterHeaderStyle.transparent;

    final effectiveProfileTap = onProfileTap ?? () => ProfileMenuBottomSheet.show(context);
    final shouldShowThemeToggle = showThemeToggle ?? false;

    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      toolbarHeight: kToolbarHeight,
      flexibleSpace: isTransparent
          ? null
          : const CustomPaint(
              painter: MasterAppBarPainter(
                curveDepth: curveHeight,
                gradient: LinearGradient(
                  colors: [AppColors.primaryRed, AppColors.secondaryRed],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: SizedBox.expand(),
            ),
      leadingWidth: leading != null ? null : (shouldShowThemeToggle ? 86 : null),
      leading: leading ??
          (shouldShowThemeToggle
              ? const Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Center(child: ThemeToggleSwitch()),
                )
              : (canPop
                  ? IconButton(
                      icon: Icon(Icons.arrow_back, color: headerTextColor),
                      onPressed: onBackTap ?? () => Navigator.pop(context),
                    )
                  : null)),
      title: title ??
          (titleText != null
              ? Text(
                  titleText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: headerTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                )
              : const SmartCardsLogo()),
      actions: [
        ...?extraActions,
        if (showProfile)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: isProfilePage
                ? _buildProfileIconWithText(effectiveProfileTap, user, cardImage)
                : _buildSimpleProfileIcon(effectiveProfileTap, user, cardImage),
          ),
      ],
    );
  }

  Widget _buildSimpleProfileIcon(VoidCallback? onTap, UserModel? user, String? cardImage) {
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: RotatingProfileAvatarRing(
        size: 36,
        borderWidth: 2.5,
        child: CircularProfileAvatar(
          radius: 18,
          size: 36,
          animateRing: false,
          imageUrl: imagePath != null && imagePath.isNotEmpty
              ? UploadUrlResolver.resolve(imagePath, type: 'profile')
              : null,
          fallbackText: user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U',
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryRed,
        ),
      ),
    );
  }

  Widget _buildProfileIconWithText(VoidCallback? onTap, UserModel? user, String? cardImage) {
    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : 'User';
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotatingProfileAvatarRing(
            size: 32,
            borderWidth: 2.0,
            child: CircularProfileAvatar(
              radius: 16,
              size: 32,
              animateRing: false,
              imageUrl: imagePath != null && imagePath.isNotEmpty
                  ? UploadUrlResolver.resolve(imagePath, type: 'profile')
                  : null,
              fallbackText: user?.displayName.isNotEmpty == true ? user!.displayName[0].toUpperCase() : 'U',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryRed,
            ),
          ),
          Text(
            displayName,
            style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + curveHeight);
}

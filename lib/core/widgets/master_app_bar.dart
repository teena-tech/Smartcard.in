import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
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
  final double sideBottomOffset;
  final double centerBottomOffset;
  final Gradient gradient;

  const MasterAppBarPainter({
    this.sideBottomOffset = 10.0,
    this.centerBottomOffset = 54.0,
    required this.gradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sideY = sideBottomOffset.clamp(0.0, size.height);
    final midY = centerBottomOffset.clamp(sideY, size.height);
    final controlY = sideY + (midY - sideY) * 2.0;

    final path = Path()
      ..lineTo(0, sideY)
      ..quadraticBezierTo(size.width / 2, controlY, size.width, sideY)
      ..lineTo(size.width, 0)
      ..close();

    // Soft drop shadow below the curved header
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.22),
      5.0,
      false,
    );

    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & Size(size.width, midY))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MasterAppBarPainter oldDelegate) =>
      oldDelegate.sideBottomOffset != sideBottomOffset ||
      oldDelegate.centerBottomOffset != centerBottomOffset ||
      oldDelegate.gradient != gradient;
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

    const headerTextColor = Colors.white;
    final canPop = showBackButton ?? Navigator.canPop(context);
    final isTransparent = style == MasterHeaderStyle.transparent;

    final effectiveProfileTap =
        onProfileTap ?? () => ProfileMenuBottomSheet.show(context);
    final shouldShowThemeToggle = showThemeToggle ?? false;
    final hasExtraActions = extraActions != null && extraActions!.isNotEmpty;
    final hasControls =
        canPop || leading != null || shouldShowThemeToggle || hasExtraActions;

    final topPadding = MediaQuery.of(context).padding.top;
    final totalHeight = topPadding + preferredSize.height;
    final sideBottomY = hasControls ? topPadding + 44.0 : topPadding + 6.0;
    final centerBottomY =
        hasControls ? totalHeight - 2.0 : totalHeight - 8.0;

    final Widget? leftWidget = leading ??
        (shouldShowThemeToggle
            ? const Padding(
                padding: EdgeInsets.only(left: 12.0),
                child: Center(child: ThemeToggleSwitch()),
              )
            : (canPop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: headerTextColor),
                    onPressed: onBackTap ?? () => Navigator.pop(context),
                  )
                : null));

    final Widget titleWidget = title ??
        (titleText != null
            ? Text(
                titleText!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppFonts.poppins(
                  color: headerTextColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              )
            : const SmartCardsLogo());

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: SizedBox(
        height: totalHeight,
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!isTransparent)
              Positioned.fill(
                child: CustomPaint(
                  painter: MasterAppBarPainter(
                    sideBottomOffset: sideBottomY,
                    centerBottomOffset: centerBottomY,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFC00000),
                        AppColors.primaryRed,
                        Color(0xFF990000),
                      ],
                      stops: [0.0, 0.55, 1.0],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),

            // Title centered nicely inside the red arc
            Positioned(
              left: hasControls ? 56.0 : 72.0,
              right: hasControls && hasExtraActions ? 104.0 : 72.0,
              top: topPadding + (hasControls ? 4.0 : 6.0),
              height: hasControls ? 42.0 : 40.0,
              child: Center(child: titleWidget),
            ),

            // Left back button or toggle (when present)
            if (leftWidget != null)
              Positioned(
                left: 4.0,
                top: topPadding + 2.0,
                height: 44.0,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: leftWidget,
                ),
              ),

            // Right actions + curved-edge floating profile avatar
            Positioned(
              right: 14.0,
              top: topPadding + (hasControls ? 4.0 : 5.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasExtraActions) ...extraActions!,
                  if (showProfile)
                    isProfilePage
                        ? _buildProfileIconWithText(
                            effectiveProfileTap,
                            user,
                            cardImage,
                          )
                        : _buildSimpleProfileIcon(
                            effectiveProfileTap,
                            user,
                            cardImage,
                            size: hasControls ? 34.0 : 42.0,
                            borderWidth: hasControls ? 2.0 : 2.5,
                          ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleProfileIcon(
    VoidCallback? onTap,
    UserModel? user,
    String? cardImage, {
    double size = 42.0,
    double borderWidth = 2.5,
  }) {
    final imagePath =
        (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: RotatingProfileAvatarRing(
            size: size,
            borderWidth: borderWidth,
            child: CircularProfileAvatar(
              radius: size / 2,
              size: size,
              animateRing: false,
              imageUrl: imagePath != null && imagePath.isNotEmpty
                  ? UploadUrlResolver.resolve(imagePath, type: 'profile')
                  : null,
              fallbackText: user?.displayName.isNotEmpty == true
                  ? user!.displayName[0].toUpperCase()
                  : 'U',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primaryRed,
            ),
          ),
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
  Size get preferredSize => const Size.fromHeight(62.0);
}

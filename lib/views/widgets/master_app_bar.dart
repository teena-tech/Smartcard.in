import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../models/user_model.dart';
import 'circular_profile_avatar.dart';
import 'rotating_profile_avatar_ring.dart';
import 'smart_cards_logo.dart';
import '../../core/utils/upload_url_resolver.dart';

enum MasterHeaderStyle {
  standard,
  gradient,
  transparent,
}

class MasterAppBar extends StatelessWidget implements PreferredSizeWidget {
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

  const MasterAppBar({
    super.key,
    this.title,
    this.titleText,
    this.style = MasterHeaderStyle.standard,
    this.onProfileTap,
    this.showProfile = true,
    this.isProfilePage = false,
    this.showBackButton,
    this.onBackTap,
    this.extraActions,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final profileViewModel = context.watch<ProfileViewModel>();
    final authViewModel = context.watch<AuthViewModel>();
    final cardViewModel = context.watch<CardViewModel>();
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

    Decoration? flexibleDecoration;
    Color? resolvedBgColor = backgroundColor;

    if (style == MasterHeaderStyle.gradient) {
      flexibleDecoration = const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryRed, AppColors.secondaryRed],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      );
      resolvedBgColor = Colors.transparent;
    } else if (style == MasterHeaderStyle.transparent) {
      resolvedBgColor = Colors.transparent;
    } else {
      resolvedBgColor ??= colors.menuBg;
    }

    final appBarWidget = AppBar(
      backgroundColor: resolvedBgColor,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: flexibleDecoration != null
          ? Container(decoration: flexibleDecoration)
          : null,
      leading: canPop
          ? IconButton(
              icon: Icon(Icons.arrow_back, color: headerTextColor),
              onPressed: onBackTap ?? () => Navigator.pop(context),
            )
          : Builder(
              builder: (context) {
                if (isProfilePage) {
                  return IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.menu, color: AppColors.primaryRed, size: 20),
                    ),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                }
                return IconButton(
                  icon: Icon(Icons.menu, color: headerTextColor),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                );
              },
            ),
      title: title ??
          (titleText != null
              ? Text(
                  titleText!,
                  style: GoogleFonts.inter(
                    color: headerTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                )
              : const SmartCardsLogo()),
      actions: [
        ...?extraActions,
        if (showProfile)
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: isProfilePage
                ? _buildProfileIconWithText(onProfileTap, user, cardImage)
                : _buildSimpleProfileIcon(onProfileTap, user, cardImage),
          ),
      ],
    );

    if (flexibleDecoration != null) {
      return Container(
        decoration: flexibleDecoration,
        child: appBarWidget,
      );
    }

    return appBarWidget;
  }

  Widget _buildSimpleProfileIcon(VoidCallback? onTap, UserModel? user, String? cardImage) {
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: RotatingProfileAvatarRing(
        size: 34,
        borderWidth: 2.5,
        child: CircularProfileAvatar(
          radius: 17,
          size: 34,
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
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

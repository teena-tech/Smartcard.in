import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy;
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_riverpod_providers.dart';
import '../../models/user_model.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import 'circular_profile_avatar.dart';
import 'rotating_profile_avatar_ring.dart';
import 'smart_cards_logo.dart';
import 'theme_toggle_switch.dart';
import 'profile_menu_bottom_sheet.dart';
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
  final Widget? leading;
  final bool? showThemeToggle;
  final bool? showModeToggle;

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
    this.leading,
    this.showThemeToggle,
    this.showModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
        context.findAncestorWidgetOfExactType<ProviderScope>() != null;

    if (hasScope) {
      return Consumer(
        builder: (context, ref, _) {
          return _buildAppBarContent(
            context,
            colors: ref.watch(themeViewModelProvider).colors,
            profileViewModel: ref.watch(profileViewModelProvider),
            authViewModel: ref.watch(authViewModelProvider),
            cardViewModel: ref.watch(cardViewModelProvider),
          );
        },
      );
    }

    return _buildAppBarContent(
      context,
      colors: legacy.Provider.of<ThemeViewModel>(context).colors,
      profileViewModel: legacy.Provider.of<ProfileViewModel>(context),
      authViewModel: legacy.Provider.of<AuthViewModel>(context),
      cardViewModel: legacy.Provider.of<CardViewModel>(context),
    );
  }

  Widget _buildAppBarContent(
    BuildContext context, {
    required AppColors colors,
    required ProfileViewModel profileViewModel,
    required AuthViewModel authViewModel,
    required CardViewModel cardViewModel,
  }) {
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

    final effectiveProfileTap = onProfileTap ?? () => ProfileMenuBottomSheet.show(context);
    final shouldShowThemeToggle = showThemeToggle ?? (!canPop && !isProfilePage);

    final appBarWidget = AppBar(
      backgroundColor: resolvedBgColor,
      elevation: 0,
      centerTitle: true,
      flexibleSpace: flexibleDecoration != null
          ? Container(decoration: flexibleDecoration)
          : null,
      leadingWidth: leading != null ? null : (shouldShowThemeToggle ? 86 : null),
      leading: leading ??
          (canPop
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: headerTextColor),
                  onPressed: onBackTap ?? () => Navigator.pop(context),
                )
              : (shouldShowThemeToggle
                  ? const Padding(
                      padding: EdgeInsets.only(left: 12.0),
                      child: Center(child: ThemeToggleSwitch()),
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
                ? _buildProfileIconWithText(effectiveProfileTap, user, cardImage)
                : _buildSimpleProfileIcon(effectiveProfileTap, user, cardImage),
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

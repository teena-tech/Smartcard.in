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
import 'smart_cards_logo.dart';
import '../../core/utils/upload_url_resolver.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final VoidCallback? onProfileTap;
  final bool showProfile;
  final bool isProfilePage;
  final bool showBackButton;
  final VoidCallback? onBackTap;
  final List<Widget>? extraActions;

  const CommonAppBar({
    super.key,
    this.title,
    this.titleText,
    this.onProfileTap,
    this.showProfile = true,
    this.isProfilePage = false,
    this.showBackButton = false,
    this.onBackTap,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final profileViewModel = context.watch<ProfileViewModel>();
    final authViewModel = context.watch<AuthViewModel>();
    final cardViewModel = context.watch<CardViewModel>();
    final user = profileViewModel.user ?? authViewModel.currentUser;
    final cardImage = cardViewModel.currentCard?.profileImageName;

    final headerTextColor = colors.menuBg.computeLuminance() < 0.5 ? Colors.white : colors.text;

    return AppBar(
      backgroundColor: colors.menuBg,
      elevation: 0,
      centerTitle: true,
      leading: showBackButton
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
      title: title ?? (titleText != null 
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
  }

  Widget _buildSimpleProfileIcon(VoidCallback? onTap, UserModel? user, String? cardImage) {
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: CircularProfileAvatar(
          radius: 17,
          size: 34,
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
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: CircularProfileAvatar(
              radius: 17,
              size: 34,
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

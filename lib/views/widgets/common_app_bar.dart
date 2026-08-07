import 'package:flutter/material.dart';
import 'master_app_bar.dart';

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
    return MasterAppBar(
      title: title,
      titleText: titleText,
      style: MasterHeaderStyle.standard,
      onProfileTap: onProfileTap,
      showProfile: showProfile,
      isProfilePage: isProfilePage,
      showBackButton: showBackButton,
      onBackTap: onBackTap,
      extraActions: extraActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}


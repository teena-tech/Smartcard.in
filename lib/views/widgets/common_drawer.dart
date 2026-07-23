import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import 'circular_profile_avatar.dart';
import '../../core/utils/upload_url_resolver.dart';

class CommonDrawer extends StatelessWidget {
  final int? currentTabIndex;
  final String? currentRoute;
  final Function(int)? onTabChanged;
  final String? backTitle;
  final VoidCallback? onBackTap;

  const CommonDrawer({
    super.key,
    this.currentTabIndex,
    this.currentRoute,
    this.onTabChanged,
    this.backTitle,
    this.onBackTap,
  });

  void _navigateToTab(BuildContext context, int index) {
    Navigator.pop(context); // Close drawer
    if (onTabChanged != null) {
      onTabChanged!(index);
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(initialIndex: index),
        ),
        (route) => false,
      );
    }
  }

  void _navigateToScreen(BuildContext context, Widget screen) {
    Navigator.pop(context);
    if (context.widget.runtimeType == screen.runtimeType) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();
    final colors = themeViewModel.colors;
    final authViewModel = context.watch<AuthViewModel>();
    final profileViewModel = context.watch<ProfileViewModel>();

    // Ensure profile is loaded
    if (profileViewModel.user == null && !profileViewModel.isLoading && authViewModel.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<ProfileViewModel>().loadProfile(authViewModel.currentUser!.id!);
      });
    }
    final user = profileViewModel.user ?? authViewModel.currentUser;
    final cardViewModel = context.watch<CardViewModel>();
    final cardImage = cardViewModel.currentCard?.profileImageName;
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;

    return Drawer(
      backgroundColor: colors.backgroundStart,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      width: MediaQuery.of(context).size.width * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(color: AppColors.primaryRed),
            child: GestureDetector(
              onTap: () => _navigateToTab(context, 3), // Index 3 is Profile
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        profileViewModel.isLoading && user == null
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                (user?.displayName.isNotEmpty == true) ? user!.displayName : 'User',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        const SizedBox(height: 4),
                        if (!profileViewModel.isLoading || user != null)
                          Text(
                            (user?.phone?.isNotEmpty == true ? user!.phone : null) ?? 
                            (user?.email?.isNotEmpty == true ? user!.email : null) ?? 
                            'Update Profile',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  CircularProfileAvatar(
                    radius: 32,
                    size: 64,
                    imageUrl: imagePath != null && imagePath.isNotEmpty
                        ? UploadUrlResolver.resolve(imagePath, type: 'profile')
                        : null,
                    fallbackText: (user?.displayName.isNotEmpty == true)
                        ? user!.displayName[0].toUpperCase()
                        : 'U',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryRed,
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _DrawerItem(
Icons.home_outlined,
                  'Dashboard',
                  colors,
                  () => _navigateToTab(context, 0),
                  isSelected: currentRoute == 'Dashboard' || currentTabIndex == 0,
                ),
                _DrawerItem(
                  Icons.qr_code_scanner,
                  'Card Scan',
                  colors,
                  () => _navigateToTab(context, 1),
                  isSelected: currentRoute == 'Card Scan' || currentTabIndex == 1,
                ),
                _DrawerItem(
                  Icons.credit_card_outlined,
                  'Share Card',
                  colors,
                  () => _navigateToTab(context, 9),
                  isSelected: currentRoute == 'Share Card' || currentTabIndex == 9,
                ),
                _DrawerItem(
Icons.edit_document,
                  'Manage Card',
                  colors,
                  () {
                    _navigateToTab(context, 10);
                  },
                  isSelected: currentRoute == 'Manage Card' || currentTabIndex == 10,
                ),
                _DrawerItem(
Icons.contact_phone_outlined,
                  'Contacts',
                  colors,
                  () => _navigateToTab(context, 4),
                  isSelected: currentRoute == 'Contacts' || currentTabIndex == 4,
                ),
                _DrawerItem(
Icons.chat_bubble_outline,
                  'Messages',
                  colors,
                  () => _navigateToTab(context, 5),
                  isSelected: currentRoute == 'Messages' || currentTabIndex == 5,
                ),
                _DrawerItem(
Icons.headset_mic_outlined,
                  'Support',
                  colors,
                  () => _navigateToTab(context, 6),
                  isSelected: currentRoute == 'Support' || currentTabIndex == 6,
                ),
                _DrawerItem(
Icons.settings_outlined,
                  'Settings',
                  colors,
                  () => _navigateToTab(context, 7),
                  isSelected: currentRoute == 'Settings' || currentTabIndex == 7,
                ),
                _DrawerItem(
Icons.info_outline,
                  'About',
                  colors,
                  () => _navigateToTab(context, 8),
                  isSelected: currentRoute == 'About' || currentTabIndex == 8,
                ),
              ],
            ),
          ),

          Divider(color: colors.border, height: 1),

          SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QUICK THEME',
                        style: GoogleFonts.inter(
                          color: colors.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ThemeButton(
'Light',
                            themeViewModel.themeMode == AppThemeMode.light,
                            AppThemeMode.light,
                          ),
                          _ThemeButton(
'Dark',
                            themeViewModel.themeMode == AppThemeMode.dark,
                            AppThemeMode.dark,
                          ),
                          _ThemeButton(
'Black',
                            themeViewModel.themeMode == AppThemeMode.black,
                            AppThemeMode.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.read<AuthViewModel>().logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final AppColors colors;
  final VoidCallback onTap;
  final bool isSelected;

  const _DrawerItem(
    this.icon,
    this.title,
    this.colors,
    this.onTap, {
    super.key,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isSelected ? AppColors.primaryRed.withValues(alpha: 0.15) : Colors.transparent,
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primaryRed : colors.text, size: 20),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: isSelected ? AppColors.primaryRed : colors.text,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isSelected ? AppColors.primaryRed.withValues(alpha: 0.15) : colors.muted.withValues(alpha: 0.15),
          size: 12,
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}

class _ThemeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final AppThemeMode mode;

  const _ThemeButton(
    this.title,
    this.isSelected,
    this.mode, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.read<ThemeViewModel>();
    final colors = themeViewModel.colors;
    return Expanded(
      child: InkWell(
        onTap: () => themeViewModel.setTheme(mode),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryRed.withValues(alpha: 0.15)
                : colors.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primaryRed : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? AppColors.primaryRed : colors.text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

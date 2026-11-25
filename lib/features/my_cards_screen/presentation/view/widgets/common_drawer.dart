import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/messages_screen/presentation/viewmodel/message_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/view/home_screen.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/view/login_screen.dart';
import 'package:smartcard_flutter/core/widgets/circular_profile_avatar.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/services/dio_client.dart';

class CommonDrawer extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeViewModel = ref.watch(themeViewModelProvider);
    final colors = themeViewModel.colors;
    final authViewModel = ref.watch(authViewModelProvider);
    final profileViewModel = ref.watch(profileViewModelProvider);

    // Ensure profile & cards are loaded
    if (profileViewModel.user == null && !profileViewModel.isLoading && authViewModel.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(profileViewModelProvider.notifier).loadProfile(authViewModel.currentUser!.id!);
      });
    }

    final cardViewModel = ref.watch(cardViewModelProvider);
    if (cardViewModel.cards.isEmpty && authViewModel.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(cardViewModelProvider.notifier).fetchCards(authViewModel.currentUser!.id.toString());
      });
    }

    final user = profileViewModel.user ?? authViewModel.currentUser;

    // Mandatory Primary Card Profile Image Waterfall Resolution:
    // 1. Primary Card Profile Image
    // 2. Active/Selected Card Profile Image
    // 3. First Available Card Profile Image
    // 4. User Account Profile Image
    String? imagePath;
    final primaryCard = cardViewModel.primaryCard;
    if (primaryCard?.profileImageName != null && primaryCard!.profileImageName!.trim().isNotEmpty) {
      imagePath = primaryCard.profileImageName!.trim();
    } else if (cardViewModel.currentCard?.profileImageName != null && cardViewModel.currentCard!.profileImageName!.trim().isNotEmpty) {
      imagePath = cardViewModel.currentCard!.profileImageName!.trim();
    } else {
      for (final card in cardViewModel.cards) {
        if (card.profileImageName != null && card.profileImageName!.trim().isNotEmpty) {
          imagePath = card.profileImageName!.trim();
          break;
        }
      }
    }

    if (imagePath == null || imagePath.isEmpty) {
      if (user?.profileImage != null && user!.profileImage!.trim().isNotEmpty) {
        imagePath = user.profileImage!.trim();
      }
    }

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
                              color: Colors.white.withValues(alpha: 0.9),
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
                    _navigateToTab(context, 2);
                  },
                  isSelected: currentRoute == 'Manage Card' || currentTabIndex == 2,
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
                        onPressed: () async {
                          final navigator = Navigator.of(context, rootNavigator: true);
                          final messageVm = ref.read(messageViewModelProvider.notifier);
                          final authVm = ref.read(authViewModelProvider.notifier);
                          final profileVm = ref.read(profileViewModelProvider.notifier);
                          final cardVm = ref.read(cardViewModelProvider.notifier);

                          Navigator.of(context).pop(); // Close drawer

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
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                              (route) => false,
                            );
                          } catch (_) {
                            DioClient.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                              '/login',
                              (route) => false,
                            );
                          }
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

class _DrawerItem extends ConsumerWidget {
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
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          color: isSelected ? AppColors.primaryRed : AppColors.primaryRed.withValues(alpha: 0.5),
          size: 12,
        ),
        dense: true,
        onTap: onTap,
      ),
    );
  }
}

class _ThemeButton extends ConsumerWidget {
  final String title;
  final bool isSelected;
  final AppThemeMode mode;

  const _ThemeButton(
    this.title,
    this.isSelected,
    this.mode,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeViewModel = ref.read(themeViewModelProvider.notifier);
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

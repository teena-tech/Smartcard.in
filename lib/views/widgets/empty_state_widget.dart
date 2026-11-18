import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

enum EmptyStateType {
  noContacts,
  noSearchResults,
  noFavorites,
  permissionDenied,
}

class EmptyStateWidget extends StatelessWidget {
  final EmptyStateType type;
  final String? customTitle;
  final String? customSubtitle;
  final String? customMessage;
  final VoidCallback? onAction;
  final String? actionLabel;
  final String? actionText;

  const EmptyStateWidget({
    super.key,
    required this.type,
    this.customTitle,
    this.customSubtitle,
    this.customMessage,
    this.onAction,
    this.actionLabel,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    String defaultTitle;
    String defaultDescription;
    Color iconColor;

    switch (type) {
      case EmptyStateType.noSearchResults:
        icon = Icons.search_off_rounded;
        defaultTitle = 'No Contacts Found';
        defaultDescription = customMessage ?? 'Try searching with a different name, phone, or email.';
        iconColor = AppColors.smsBlue;
        break;
      case EmptyStateType.noFavorites:
        icon = Icons.star_border_rounded;
        defaultTitle = 'No Favorites Yet';
        defaultDescription = 'Star your favorite contacts to quickly access them here.';
        iconColor = AppColors.favoriteGold;
        break;
      case EmptyStateType.permissionDenied:
        icon = Icons.no_accounts_rounded;
        defaultTitle = 'Contacts Access Denied';
        defaultDescription = 'Please grant contacts permission to display and manage your phone contacts.';
        iconColor = AppColors.deleteRed;
        break;
      case EmptyStateType.noContacts:
        icon = Icons.contacts_rounded;
        defaultTitle = 'No Contacts Available';
        defaultDescription = 'Your contact list is currently empty. Tap the + button to create a new contact or sync with your device.';
        iconColor = AppColors.primary;
        break;
    }

    final displayTitle = customTitle ?? defaultTitle;
    final displayDescription = customSubtitle ?? customMessage ?? defaultDescription;
    final btnLabel = actionText ?? actionLabel ?? (type == EmptyStateType.noSearchResults ? 'Clear Search' : 'Add Contact');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayDescription,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            if (onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  btnLabel,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9)),
      ),
    );
  }
}

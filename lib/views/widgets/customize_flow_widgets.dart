import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/card_model.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../../../core/utils/upload_url_resolver.dart';
import 'circular_profile_avatar.dart';

class SmartCardsFlowAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;
  final String initials;
  final VoidCallback onProfileTap;

  const SmartCardsFlowAppBar({
    super.key,
    required this.onMenuTap,
    required this.initials,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final canPop = Navigator.canPop(context);
    final authVm = context.watch<AuthViewModel>();
    final profileVm = context.watch<ProfileViewModel>();
    final user = profileVm.user ?? authVm.currentUser;
    final imagePath = user?.profileImage;
    final imageUrl = (imagePath != null && imagePath.isNotEmpty)
        ? UploadUrlResolver.resolve(imagePath, type: 'profile')
        : null;

    return AppBar(
      backgroundColor: colors.card,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.menu,
          color: colors.text,
          size: 24,
        ),
        onPressed: onMenuTap,
      ),
      centerTitle: true,
      title: Text(
        'Customize',
        style: GoogleFonts.inter(
          color: colors.text,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            child: CircularProfileAvatar(
              radius: 20,
              size: 40,
              imageUrl: imageUrl,
              fallbackText: initials,
              backgroundColor: AppColors.primaryRed.withValues(alpha: 0.15),
              foregroundColor: AppColors.primaryRed,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CardProfileTabsStrip extends StatelessWidget {
  final List<CardModel> cards;
  final int? selectedCardId;
  final Function(int) onSelectCard;

  const CardProfileTabsStrip({
    super.key,
    required this.cards,
    required this.selectedCardId,
    required this.onSelectCard,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = card.userId == selectedCardId;
          
          return GestureDetector(
            onTap: () => onSelectCard(card.userId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryRed : colors.section,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppColors.primaryRed : colors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                card.tabLabel,
                style: GoogleFonts.inter(
                  color: isSelected ? Colors.white : colors.text,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

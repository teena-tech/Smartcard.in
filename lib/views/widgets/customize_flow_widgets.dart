import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/card_model.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../../../viewmodels/card_viewmodel.dart';
import '../../../core/utils/upload_url_resolver.dart';
import 'circular_profile_avatar.dart';

import '../screens/customize/customize_menu_screen.dart';

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
    final cardVm = context.watch<CardViewModel>();
    final user = profileVm.user ?? authVm.currentUser;
    final cardImage = cardVm.currentCard?.profileImageName;
    final imagePath = (cardImage != null && cardImage.isNotEmpty) ? cardImage : user?.profileImage;
    final imageUrl = (imagePath != null && imagePath.isNotEmpty)
        ? UploadUrlResolver.resolve(imagePath, type: 'profile')
        : null;

    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryRed, AppColors.secondaryRed],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      leading: canPop
          ? IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () {
                final modalRoute = ModalRoute.of(context);
                if (modalRoute != null && modalRoute.isFirst) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomizeMenuScreen()),
                  );
                } else if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomizeMenuScreen()),
                  );
                }
              },
            )
          : IconButton(

              icon: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 24,
              ),
              onPressed: onMenuTap,
            ),
      centerTitle: true,
      title: Text(
        'Customize',
        style: GoogleFonts.inter(
          color: Colors.white,
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
              radius: 18,
              size: 36,
              imageUrl: imageUrl,
              fallbackText: initials,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/card_model.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/theme_viewmodel.dart';
import '../screens/customize/customize_menu_screen.dart';
import 'master_app_bar.dart';

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
    return MasterAppBar(
      titleText: 'Customize',
      style: MasterHeaderStyle.gradient,
      onProfileTap: onProfileTap,
      onBackTap: () {
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

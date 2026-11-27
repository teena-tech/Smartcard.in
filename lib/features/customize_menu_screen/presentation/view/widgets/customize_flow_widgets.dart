import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/features/customize_theme_screen/presentation/viewmodel/theme_viewmodel.dart';
import 'package:smartcard_flutter/features/customize_menu_screen/presentation/view/customize_menu_screen.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';

class SmartCardsFlowAppBar extends ConsumerWidget implements PreferredSizeWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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


class CardProfileTabsStrip extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeViewModelProvider).colors;
    
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
                style: AppFonts.poppins(
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

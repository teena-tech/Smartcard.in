import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/card_viewmodel.dart';
import '../../viewmodels/customization_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'lottie_loader.dart';

class SmartCardCarousel extends StatefulWidget {
  const SmartCardCarousel({super.key});

  @override
  State<SmartCardCarousel> createState() => _SmartCardCarouselState();
}

class _SmartCardCarouselState extends State<SmartCardCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<List<Color>> _cardGradients = [
    [const Color(0xFFD32F2F), const Color(0xFFE57373)], // Red
    [const Color(0xFF1976D2), const Color(0xFF64B5F6)], // Blue
    [const Color(0xFF388E3C), const Color(0xFF81C784)], // Green
    [const Color(0xFFFFA000), const Color(0xFFFFD54F)], // Orange
  ];

  @override
  void initState() {
    super.initState();
    final cardViewModel = context.read<CardViewModel>();
    _currentPage = cardViewModel.currentIndex;
    _pageController = PageController(
      viewportFraction: 0.88,
      initialPage: _currentPage,
    );
    // Rebuild on page scroll for smooth scale effect
    _pageController.addListener(() {
      if (context.mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardViewModel = context.watch<CardViewModel>();
    final custController = context.watch<CustomizationController>();
    final cards = cardViewModel.cards;

    if (cards.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: LottieLoader(size: 60)),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) {
              final realIndex = index % cards.length;
              setState(() => _currentPage = index);
              cardViewModel.setCurrentIndex(realIndex);
            },
            itemBuilder: (context, index) {
              final cardIndex = index % cards.length;
              final card = cards[cardIndex];
              final gradient = _cardGradients[cardIndex % _cardGradients.length];

              // Smooth scale: calculate based on current scroll position
              double scale = 0.92;
              if (_pageController.position.hasContentDimensions) {
                final double diff = (_pageController.page! - index).abs();
                scale = (1.0 - diff * 0.08).clamp(0.92, 1.0);
              }

              return Transform.scale(
                scale: scale,
                child: GestureDetector(
                  onTap: () {
                    context.read<DashboardViewModel>().setIndex(2);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: (custController.bgColorEnabled && cardIndex == 0)
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: gradient,
                            ),
                      color: (custController.bgColorEnabled && cardIndex == 0)
                          ? custController.backgroundColor
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: (custController.bgColorEnabled && cardIndex == 0)
                              ? custController.backgroundColor.withValues(alpha: 0.15)
                              : gradient.last.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        children: [
                          // Background Image layer
                          if (custController.bgImageEnabled &&
                              custController.backgroundImagePath != null &&
                              cardIndex == 0)
                            Positioned.fill(
                              child: Image.file(
                                File(custController.backgroundImagePath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          // Overlay layer
                          if (custController.overlayEnabled && cardIndex == 0)
                            Positioned.fill(
                              child: Container(
                                color: custController.overlayColor
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                          // Content layer
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'SMART CARD',
                                      style: GoogleFonts.inter(
                                        color: (cardIndex == 0)
                                            ? custController.textColor.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.2),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Icon(
                                      Icons.contactless_outlined,
                                      color: (cardIndex == 0)
                                          ? custController.textColor
                                          : Colors.white,
                                    ),
                                  ],
                                ),
                                Text(
                                  '**** **** **** ${1234 + cardIndex}',
                                  style: GoogleFonts.inter(
                                    color: (cardIndex == 0)
                                        ? custController.textColor
                                        : Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CARD NAME',
                                          style: GoogleFonts.inter(
                                            color: (cardIndex == 0)
                                                ? custController.textColor
                                                    .withValues(alpha: 0.15)
                                                : Colors.white.withValues(alpha: 0.2),
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          card.name.toUpperCase(),
                                          style: GoogleFonts.inter(
                                            color: (cardIndex == 0)
                                                ? custController.textColor
                                                : Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'DESIGNATION',
                                          style: GoogleFonts.inter(
                                            color: (cardIndex == 0)
                                                ? custController.textColor
                                                    .withValues(alpha: 0.15)
                                                : Colors.white.withValues(alpha: 0.2),
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          (card.designation?.isNotEmpty == true
                                                  ? card.designation!
                                                  : 'Member')
                                              .toUpperCase(),
                                          style: GoogleFonts.inter(
                                            color: (cardIndex == 0)
                                                ? custController.textColor
                                                : Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Jumping active dot indicator (kept as requested)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            cards.length,
            (index) {
              final isActive = _currentPage % cards.length == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: isActive ? 24 : 8,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primaryRed : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/network/api_config.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/providers/app_riverpod_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import '../widgets/lottie_loader.dart';

class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(landingViewModelProvider).fetchSlides().then((_) {
        _startAutoPlay();
      });
    });
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !context.mounted) {
        timer.cancel();
        return;
      }
      if (!_pageController.hasClients) return;
      try {
        final viewModel = ref.read(landingViewModelProvider);
        final slides = viewModel.slides;
        if (slides.isEmpty) return;

        int nextPage = _currentPage + 1;
        if (nextPage >= slides.length) {
          nextPage = 0;
        }

        if (_pageController.hasClients && mounted && context.mounted) {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        }
      } catch (_) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildImage(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return Container(color: Colors.grey.shade300);
    }

    // Local bundled Flutter asset
    if (trimmed.startsWith('assets/')) {
      return Image.asset(
        trimmed,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(color: Colors.grey.shade300);
        },
      );
    }

    // Full or relative server URL (handles /uploads/..., shared-uploads/..., and relative filenames)
    final imageUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : (trimmed.startsWith('/')
            ? '${ApiConfig.baseUrl}$trimmed'
            : UploadUrlResolver.resolve(trimmed, type: 'background'));

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) =>
          const Center(child: LottieLoader(size: 40)),
      errorWidget: (context, url, error) =>
          Container(color: Colors.grey.shade300),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.watch(landingViewModelProvider);
    final authViewModel = ref.watch(authViewModelProvider);
    final bool isLoggedIn = authViewModel.isAuthenticated;

    if (viewModel.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: LottieLoader(size: 120)),
      );
    }

    final slides = viewModel.slides;
    final currentSlide = slides.isNotEmpty ? slides[_currentPage] : null;
    final String slideImagePath = (currentSlide?['image_path'] ?? '').toString();
    final bool isEmbeddedWelcomeImage = slideImagePath.toLowerCase().contains('welcome');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Full-screen Carousel Image (fit: BoxFit.cover, alignment: Alignment.center)
          if (slides.isNotEmpty)
            Positioned.fill(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                  _startAutoPlay();
                },
                itemCount: slides.length,
                itemBuilder: (context, index) {
                  return _buildImage(slides[index]['image_path'] ?? '');
                },
              ),
            ),

          // 2. Subtle Gradient Overlay for non-embedded images
          if (!isEmbeddedWelcomeImage)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),

          // 3. Custom text if slide is remote/custom (non-graphic banner)
          if (!isEmbeddedWelcomeImage && currentSlide != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 100.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((currentSlide['title'] ?? '').toString().isNotEmpty) ...[
                      Text(
                        currentSlide['title'] ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if ((currentSlide['subtitle'] ?? '').toString().isNotEmpty) ...[
                      Text(
                        currentSlide['subtitle'] ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // 4. Bottom Swiper Dots & Action Buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Page Indicator (dots for swiper loop)
                  if (slides.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? AppColors.primaryRed : Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Buttons Row
                  if (isLoggedIn)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomeScreen(initialIndex: 0),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "GET STARTED",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        // Register Button (Outlined)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.black.withValues(alpha: 0.2),
                              side: const BorderSide(color: Colors.white, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "REGISTER FREE",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Login Button (Filled)
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "LOGIN",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

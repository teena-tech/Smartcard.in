import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../../core/services/api_config.dart';
import '../../viewmodels/landing_viewmodel.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'login_screen.dart';
import 'register_screen.dart';
import '../widgets/lottie_loader.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LandingViewModel>().fetchSlides().then((_) {
        _startAutoPlay();
      });
    });
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final viewModel = context.read<LandingViewModel>();
      final slides = viewModel.slides;
      if (slides.isEmpty) return;

      int nextPage = _currentPage + 1;
      if (nextPage >= slides.length) {
        nextPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
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
if (path.isEmpty) {
return Container(color: Colors.grey.shade300);
}

// Full Image URL
if (path.startsWith('http')) {
return CachedNetworkImage(
imageUrl: path,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
placeholder: (context, url) =>
const Center(child: LottieLoader(size: 40)),
errorWidget: (context, url, error) =>
Container(color: Colors.grey.shade300),
);
}

// Relative URL Example: /uploads/slide1.jpg
if (path.startsWith('/')) {
final imageUrl =
'${ApiConfig.baseUrl}$path';

return CachedNetworkImage(
  imageUrl: imageUrl,
  fit: BoxFit.cover,
  width: double.infinity,
  height: double.infinity,
  placeholder: (context, url) =>
      const Center(child: LottieLoader(size: 40)),
  errorWidget: (context, url, error) =>
      Container(color: Colors.grey.shade300),
);

}

// Asset Image
return Image.asset(
path,
fit: BoxFit.cover,
width: double.infinity,
height: double.infinity,
errorBuilder: (context, error, stackTrace) {
return Container(color: Colors.grey.shade300);
},
);
}

 
  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LandingViewModel>();

    if (viewModel.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: LottieLoader(size: 120)),
      );
    }

    final slides = viewModel.slides;

    final currentSlide = slides.isNotEmpty ? slides[_currentPage] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Image Carousel Background
          if (slides.isNotEmpty)
            PageView.builder(
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
          
          // Dark Gradient Overlay for text readability
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1), // Top subtle darkening
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1), // Bottom dark for text
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          // Top Bar (Logo and Menu)
          const SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Smart Cards',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Digital Connections',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      currentSlide?['title'] ?? 'Welcome',
                      key: ValueKey<String>(currentSlide?['title'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: Text(
                      currentSlide?['subtitle'] ?? '',
                      key: ValueKey<String>(currentSlide?['subtitle'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Page Indicator (3 dots for swiper)
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
                            color: _currentPage == index ? AppColors.primaryRed : Colors.white54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  
                  // Buttons Row (Swapped: Register on Left, Login on Right)
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
                            side: const BorderSide(color: Colors.white, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "REGISTER FREE",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
                            backgroundColor: AppColors.primaryRed, // Theme primary color
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            "LOGIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

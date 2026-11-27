import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:smartcard_flutter/core/di/app_loading_notifier.dart';
import 'package:smartcard_flutter/main.dart';

/// Full-screen branded loading overlay.
/// Shows Loading Loop Lottie animation centered on white background.
class GlobalLoadingOverlay extends ConsumerWidget {
  final Widget child;
  const GlobalLoadingOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading =
        ref.watch(appLoadingProvider.select((s) => s.isLoading));
    return Stack(
      children: [
        child,
        if (isLoading)
          const Positioned.fill(
            child: _LoadingOverlayContent(),
          ),
      ],
    );
  }
}

class _LoadingOverlayContent extends StatefulWidget {
  const _LoadingOverlayContent();
  @override
  State<_LoadingOverlayContent> createState() => _LoadingOverlayContentState();
}

class _LoadingOverlayContentState extends State<_LoadingOverlayContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: Theme.of(context).brightness == Brightness.light 
            ? const Color(0xFFFFF0F0) 
            : Colors.black87,
        child: Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Theme.of(context).brightness == Brightness.light 
                    ? Colors.red 
                    : Colors.white,
                BlendMode.srcATop,
              ),
              child: globalLottieComposition != null
                  ? Lottie(
                      composition: globalLottieComposition,
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                    )
                  : Lottie.asset(
                      'assets/lottie/loading_loop.json',
                      fit: BoxFit.contain,
                      repeat: true,
                      animate: true,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('Global Overlay Lottie error: $error');
                        return const CircularProgressIndicator(
                            color: Colors.redAccent);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

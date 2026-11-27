import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CaptureAnimationWidget extends StatelessWidget {
  final bool isCapturing;
  final VoidCallback? onAnimationComplete;

  const CaptureAnimationWidget({
    super.key,
    required this.isCapturing,
    this.onAnimationComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCapturing) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        color: Colors.white,
      )
          .animate(onComplete: (c) => onAnimationComplete?.call())
          .fade(begin: 0.8, end: 0.0, duration: 350.ms, curve: Curves.easeOut),
    );
  }
}

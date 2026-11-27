import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';

/// Wraps any profile image widget with a continuous, smooth rotating/spinning gradient ring ("karanganam").
class RotatingProfileAvatarRing extends StatefulWidget {
  final Widget child;
  final double size;
  final double borderWidth;
  final List<Color>? ringColors;
  final Duration duration;

  const RotatingProfileAvatarRing({
    super.key,
    required this.child,
    required this.size,
    this.borderWidth = 3.5,
    this.ringColors,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<RotatingProfileAvatarRing> createState() => _RotatingProfileAvatarRingState();
}

class _RotatingProfileAvatarRingState extends State<RotatingProfileAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.ringColors ??
        const [
          AppColors.primaryRed,
          Color(0xFFFF7E4B),
          Color(0xFFFFD700),
          Color(0xFF00E5FF),
          Color(0xFF3B82F6),
          AppColors.primaryRed,
        ];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;
        final pulseScale = 1.0 + 0.04 * math.sin(angle * 2);

        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Outer Spinning Gradient Ring
            Transform.rotate(
              angle: angle,
              child: Container(
                width: (widget.size + (widget.borderWidth * 2)) * pulseScale,
                height: (widget.size + (widget.borderWidth * 2)) * pulseScale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: colors,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.35 * pulseScale),
                      blurRadius: 8 * pulseScale,
                      spreadRadius: 1.5 * pulseScale,
                    ),
                  ],
                ),
              ),
            ),

            // 2. White Clean Gap
            Container(
              width: widget.size + 1.5,
              height: widget.size + 1.5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),

            // 3. Profile Avatar Content (Stays upright, ring rotates around it)
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: ClipOval(child: widget.child),
            ),
          ],
        );
      },
    );
  }
}

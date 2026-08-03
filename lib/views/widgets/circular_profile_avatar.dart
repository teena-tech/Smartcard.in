import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'lottie_loader.dart';

class CircularProfileAvatar extends StatefulWidget {
  final double radius;
  final String? imageUrl;
  final String? imagePath;
  final String fallbackText;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double? size;
  final EdgeInsetsGeometry? padding;
  final BoxShadow? shadow;
  final String? cacheKey;
  final bool animateRing;

  const CircularProfileAvatar({
    super.key,
    required this.radius,
    this.imageUrl,
    this.imagePath,
    this.fallbackText = 'U',
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.size,
    this.padding,
    this.shadow,
    this.cacheKey,
    this.animateRing = true,
  });

  @override
  State<CircularProfileAvatar> createState() => _CircularProfileAvatarState();
}

class _CircularProfileAvatarState extends State<CircularProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarSize = widget.size ?? widget.radius * 2;
    final effectiveBackgroundColor = widget.backgroundColor ?? Colors.white;

    if (!widget.animateRing) {
      return _buildStaticAvatar(avatarSize, effectiveBackgroundColor);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;
        final pulseScale = 1.0 + 0.05 * math.sin(angle * 2);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Rotating & Pulsing Gradient Ring
            Transform.rotate(
              angle: angle,
              child: Container(
                width: avatarSize + 6,
                height: avatarSize + 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      AppColors.primaryRed,
                      const Color(0xFFFF6B6B),
                      const Color(0xFF3B82F6),
                      const Color(0xFF10B981),
                      AppColors.primaryRed,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withValues(alpha: 0.35 * pulseScale),
                      blurRadius: 6 * pulseScale,
                      spreadRadius: 1 * pulseScale,
                    ),
                  ],
                ),
              ),
            ),

            // Inner White Gap
            Container(
              width: avatarSize + 2,
              height: avatarSize + 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),

            // Avatar Main Body
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: effectiveBackgroundColor,
                border: widget.borderColor != null
                    ? Border.all(color: widget.borderColor!, width: widget.borderWidth)
                    : null,
                boxShadow: widget.shadow != null ? [widget.shadow!] : null,
              ),
              padding: widget.padding ?? EdgeInsets.all(widget.borderWidth > 0 ? 0 : 0),
              child: ClipOval(
                child: _buildImageContent(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaticAvatar(double avatarSize, Color effectiveBackgroundColor) {
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
        border: widget.borderColor != null
            ? Border.all(color: widget.borderColor!, width: widget.borderWidth)
            : null,
        boxShadow: widget.shadow != null ? [widget.shadow!] : null,
      ),
      padding: widget.padding ?? EdgeInsets.all(widget.borderWidth > 0 ? 0 : 0),
      child: ClipOval(
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    final hasImage = (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ||
        (widget.imagePath != null && widget.imagePath!.isNotEmpty);

    if (!hasImage) {
      return Center(
        child: Text(
          widget.fallbackText.isEmpty ? 'U' : widget.fallbackText,
          style: TextStyle(
            color: widget.foregroundColor ?? Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Handle network images
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      final normalizedUrl = widget.imageUrl!.trim();
      if (normalizedUrl.startsWith('http://') || normalizedUrl.startsWith('https://')) {
        return Image.network(
          normalizedUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackContent(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: LottieLoader(size: 24),
            );
          },
        );
      }
    }

    // Handle local file images
    if (widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      final file = File(widget.imagePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallbackContent(),
        );
      }
    }

    return _fallbackContent();
  }

  Widget _fallbackContent() {
    return Container(
      color: widget.backgroundColor ?? Colors.grey.shade200,
      child: Center(
        child: Text(
          widget.fallbackText.isEmpty ? 'U' : widget.fallbackText,
          style: TextStyle(
            color: widget.foregroundColor ?? Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

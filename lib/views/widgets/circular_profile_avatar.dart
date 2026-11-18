import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/upload_url_resolver.dart';
import '../../../core/utils/safe_base64.dart';

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

    final avatarBody = Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBackgroundColor,
      ),
      padding: widget.padding ?? EdgeInsets.all(widget.borderWidth > 0 ? 0 : 0),
      child: ClipOval(
        child: _buildImageContent(),
      ),
    );

    if (!widget.animateRing) {
      return avatarBody;
    }

    return AnimatedBuilder(
      animation: _controller,
      child: avatarBody,
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
                  gradient: const SweepGradient(
                    colors: [
                      AppColors.primaryRed,
                      Color(0xFFFF6B6B),
                      Color(0xFF3B82F6),
                      Color(0xFF10B981),
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

            // Avatar Main Body (Static Child, No Blinking!)
            child!,
          ],
        );
      },
    );
  }



  Widget _buildImageContent() {
    final hasImage = (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty && widget.imageUrl!.trim().toLowerCase() != 'null') ||
        (widget.imagePath != null && widget.imagePath!.trim().isNotEmpty && widget.imagePath!.trim().toLowerCase() != 'null');

    if (!hasImage) {
      return _fallbackContent();
    }

    // Handle image URLs (network, data URI, or server upload path)
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty && widget.imageUrl!.trim().toLowerCase() != 'null') {
      final raw = widget.imageUrl!.trim();
      final resolvedUrl = UploadUrlResolver.resolve(raw, type: 'profile');

      if (resolvedUrl.startsWith('data:image') || resolvedUrl.startsWith('data:')) {
        try {
          final base64Bytes = safeBase64Decode(resolvedUrl);
          if (base64Bytes == null) return _fallbackContent();
          return Image.memory(
            base64Bytes,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallbackContent(),
          );
        } catch (_) {
          return _fallbackContent();
        }
      }

      if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
        return CachedNetworkImage(
          imageUrl: resolvedUrl,
          cacheKey: widget.cacheKey ?? resolvedUrl.split('?').first,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          useOldImageOnUrlChange: true,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          placeholder: (_, _) => _fallbackContent(),
          errorWidget: (_, _, _) => _fallbackContent(),
        );
      }
    }

    // Handle local file images
    if (!kIsWeb && widget.imagePath != null && widget.imagePath!.isNotEmpty) {
      try {
        final file = File(widget.imagePath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _fallbackContent(),
          );
        }
      } catch (_) {}
    }

    return _fallbackContent();
  }

  Widget _fallbackContent() {
    final avatarSize = widget.size ?? widget.radius * 2;
    return Container(
      color: widget.backgroundColor ?? Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: widget.foregroundColor ?? AppColors.primaryRed,
          size: avatarSize * 0.65,
        ),
      ),
    );
  }
}

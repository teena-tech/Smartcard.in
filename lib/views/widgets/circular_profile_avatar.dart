import 'dart:io';
import 'package:flutter/material.dart';
import 'lottie_loader.dart';

class CircularProfileAvatar extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? radius * 2;
    final effectiveBackgroundColor = backgroundColor ?? Colors.white;
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: effectiveBackgroundColor,
      border: borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
      boxShadow: shadow != null ? [shadow!] : null,
    );

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: decoration,
      padding: padding ?? EdgeInsets.all(borderWidth > 0 ? 0 : 0),
      child: ClipOval(
        child: _buildImageContent(),
      ),
    );
  }

  Widget _buildImageContent() {
    final hasImage = (imageUrl != null && imageUrl!.isNotEmpty) ||
        (imagePath != null && imagePath!.isNotEmpty);

    if (!hasImage) {
      return Center(
        child: Text(
          fallbackText.isEmpty ? 'U' : fallbackText,
          style: TextStyle(
            color: foregroundColor ?? Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // Handle network images
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final normalizedUrl = imageUrl!.trim();
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
    if (imagePath != null && imagePath!.isNotEmpty) {
      final file = File(imagePath!);
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
      color: backgroundColor ?? Colors.grey.shade200,
      child: Center(
        child: Text(
          fallbackText.isEmpty ? 'U' : fallbackText,
          style: TextStyle(
            color: foregroundColor ?? Colors.black54,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

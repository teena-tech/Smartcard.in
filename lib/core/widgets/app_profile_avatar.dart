import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/core/utils/avatar_helper.dart';
import 'package:smartcard_flutter/core/utils/safe_base64.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/widgets/genie_hero_route.dart';

/// Ultra-high performance, crystal-clear profile avatar widget with Truecaller-style Bloody-Red Ring & Micro Business Badge.
class AppProfileAvatar extends StatelessWidget {
  final String id;
  final String name;
  final String? avatarUrl;
  final Uint8List? avatarBytes;
  final double size;
  final String? heroTag;
  final String? customKey;
  final bool enableHero;
  final VoidCallback? onTap;
  final List<Color>? gradientColors;
  final bool isBusiness;
  final bool isSmartCardUser;
  final IconData? badgeIcon;
  final Color? badgeColor;
  final BoxFit fit;

  const AppProfileAvatar({
    super.key,
    required this.id,
    required this.name,
    this.avatarUrl,
    this.avatarBytes,
    this.size = 50.0,
    this.heroTag,
    this.customKey,
    this.enableHero = true,
    this.onTap,
    this.gradientColors,
    this.isBusiness = false,
    this.isSmartCardUser = false,
    this.badgeIcon,
    this.badgeColor,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = name.trim();
    final initial = AvatarHelper.getFirstLetter(trimmedName);
    final effectiveHeroTag = heroTag ?? contactHeroTag(id: id, name: trimmedName);
    final avatarKey = customKey ?? 'profile_img_$id';
    final cacheKeyString = 'profile_img_$id';

    final effectiveGradient = gradientColors ?? AvatarHelper.getGradient(trimmedName);

    const double ringThickness = 2.8;
    const double gapThickness = 1.5;
    final double innerSize = size - (ringThickness * 2) - (gapThickness * 2);
    final bool showBadge = isBusiness || isSmartCardUser;
    final double badgeSize = (size * 0.38).clamp(14.0, 22.0);

    // Truecaller-inspired Bloody Red Ring avatar
    Widget mainAvatar = Container(
      key: ValueKey(avatarKey),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF8B0000), // Bloody red ring
          width: ringThickness,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withValues(alpha: 0.25),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(gapThickness),
      alignment: Alignment.center,
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: effectiveGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: ClipOval(
          child: SizedBox(
            width: innerSize,
            height: innerSize,
            child: _buildImageOrFallback(initial, cacheKeyString, innerSize, effectiveGradient),
          ),
        ),
      ),
    );

    // Micro Business Badge Overlay (Positioned elegantly at bottom-right)
    Widget content = showBadge
        ? SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                mainAvatar,
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor ?? (isBusiness ? AppColors.primaryRed : const Color(0xFF1E88E5)),
                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        badgeIcon ?? (isBusiness ? Icons.business_center_rounded : Icons.verified_rounded),
                        size: badgeSize * 0.58,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : mainAvatar;

    if (onTap != null) {
      content = GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    content = RepaintBoundary(child: content);

    if (enableHero && effectiveHeroTag.isNotEmpty) {
      return Hero(
        tag: effectiveHeroTag,
        createRectTween: (begin, end) => GenieRectTween(begin: begin, end: end),
        flightShuttleBuilder: genieFlightShuttleBuilder,
        child: Material(
          color: Colors.transparent,
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildImageOrFallback(String initial, String cacheKeyString, double renderSize, List<Color> gradientColors) {
    if (avatarBytes != null && avatarBytes!.isNotEmpty) {
      return Image.memory(
        avatarBytes!,
        key: ValueKey('mem_img_$id'),
        width: renderSize,
        height: renderSize,
        fit: fit,
        filterQuality: FilterQuality.high,
        isAntiAlias: true,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _buildInitialFallback(initial, renderSize, gradientColors),
      );
    }

    final rawUrl = avatarUrl?.trim();
    if (rawUrl == null ||
        rawUrl.isEmpty ||
        rawUrl.toLowerCase() == 'null' ||
        rawUrl.toLowerCase() == 'undefined') {
      return _buildInitialFallback(initial, renderSize, gradientColors);
    }

    final url = UploadUrlResolver.resolve(rawUrl, type: 'profile');
    if (url.isEmpty) {
      return _buildInitialFallback(initial, renderSize, gradientColors);
    }

    if (url.startsWith('data:image') || url.startsWith('data:')) {
      try {
        final bytes = safeBase64Decode(url);
        if (bytes != null) {
          return Image.memory(
            bytes,
            key: ValueKey('b64_img_$id'),
            width: renderSize,
            height: renderSize,
            fit: fit,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _buildInitialFallback(initial, renderSize, gradientColors),
          );
        }
      } catch (_) {
        return _buildInitialFallback(initial, renderSize, gradientColors);
      }
    }

    if (!kIsWeb && (url.startsWith('/') || url.startsWith('file://'))) {
      final cleanPath = url.replaceFirst('file://', '');
      final file = File(cleanPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          key: ValueKey('file_img_$id'),
          width: renderSize,
          height: renderSize,
          fit: fit,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildInitialFallback(initial, renderSize, gradientColors),
        );
      }
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return CachedNetworkImage(
        key: ValueKey('net_img_${id}_${url.split('?').first}'),
        imageUrl: url,
        cacheKey: '${cacheKeyString}_${url.split('?').first}',
        width: renderSize,
        fit: fit,
        filterQuality: FilterQuality.high,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        useOldImageOnUrlChange: true,
        placeholder: (_, _) => _buildInitialFallback(initial, renderSize, gradientColors),
        errorWidget: (_, _, _) => _buildInitialFallback(initial, renderSize, gradientColors),
      );
    }

    return _buildInitialFallback(initial, renderSize, gradientColors);
  }

  Widget _buildInitialFallback(String initial, double renderSize, List<Color> gradientColors) {
    return Container(
      width: renderSize,
      height: renderSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: renderSize * 0.52,
        ),
      ),
    );
  }
}

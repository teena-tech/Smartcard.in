import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/constants/app_colors.dart';
import 'package:smartcard_flutter/features/contact_detail_screen/presentation/view/contact_detail_screen.dart';


class PulsingBadge extends StatefulWidget {
  final bool isActive;
  const PulsingBadge({super.key, this.isActive = true});

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _animation = Tween(begin: 0.2, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive ? const Color(0xFF4ADE80) : Colors.redAccent;
    final text = widget.isActive ? 'Active' : 'Suspended';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _animation,
            child: ScaleTransition(
              scale: _animation,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1)
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: AppFonts.poppins(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PremiumCardWidget extends StatelessWidget {
  final CardModel card;
  final EdgeInsetsGeometry? margin;
  final Widget? bottomActions;
  final VoidCallback? onTap;

  const PremiumCardWidget({
    super.key,
    required this.card,
    this.margin,
    this.bottomActions,
    this.onTap,
  });

  Color? _parseHexColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return null;
    final cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      return Color(int.parse('0xFF$cleanHex'));
    } else if (cleanHex.length == 8) {
      return Color(int.parse('0x$cleanHex'));
    }
    return null;
  }

  double _parseOpacity(String? opacityStr) {
    if (opacityStr == null || opacityStr.isEmpty) return 0.5;
    return double.tryParse(opacityStr) ?? 0.5;
  }

  @override
  Widget build(BuildContext context) {
    String displayName = card.companyName.isNotEmpty ? card.companyName : card.name;
    if (displayName.length > 24) {
      displayName = '${displayName.substring(0, 24)}...';
    }

    final rawBgImage = (card.backgroundImage != null && card.backgroundImage!.trim().isNotEmpty)
        ? card.backgroundImage!.trim()
        : '';
    final hasBgImage = rawBgImage.isNotEmpty;
    final bgUrl = hasBgImage
        ? (rawBgImage.startsWith('assets/') ? rawBgImage : UploadUrlResolver.resolve(rawBgImage, type: 'card-bg'))
        : '';


    final customBgColor = _parseHexColor(card.backgroundColor);
    final customTextColor = _parseHexColor(card.textColor) ?? Colors.white;
    final overlayColor = _parseHexColor(card.bgImageColor);
    final overlayOpacity = _parseOpacity(card.opacity);

    LinearGradient? templateGradient;
    final keyStr = (card.templateKey ?? card.templateId ?? '').toLowerCase();
    if (keyStr.contains('02') || keyStr.contains('navy') || keyStr == '2') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('03') || keyStr.contains('minimalist') || keyStr == '3') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF18181B), Color(0xFF27272A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('04') || keyStr.contains('crimson') || keyStr == '4') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF881337), Color(0xFFE11D48)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('05') || keyStr.contains('executive') || keyStr == '5') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF09090B), Color(0xFF18181B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('06') || keyStr.contains('cyber') || keyStr.contains('obsidian') || keyStr == '6') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF020617), Color(0xFF0F172A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('07') || keyStr.contains('emerald') || keyStr == '7') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF064E3B), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (keyStr.contains('08') || keyStr.contains('sapphire') || keyStr.contains('luxe') || keyStr == '8') {
      templateGradient = const LinearGradient(
        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    final hasBgColor = customBgColor != null;
    final hasActions = bottomActions != null;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 680),
      child: AspectRatio(
        aspectRatio: hasActions ? 1.45 : 1.62,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: ColorFiltered(
                colorFilter: card.isSuspended 
                    ? const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ])
                    : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: hasBgImage ? Colors.grey.shade900 : (hasBgColor ? customBgColor : null),
                    borderRadius: BorderRadius.circular(20),
                    gradient: (!hasBgImage && !hasBgColor)
                        ? (templateGradient ?? const LinearGradient(
                            colors: [Color(0xFF6B41A5), Color(0xFFC781DD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ))
                        : null,
                    image: hasBgImage && bgUrl.isNotEmpty
                        ? DecorationImage(
                            image: bgUrl.startsWith('assets/')
                                ? AssetImage(bgUrl) as ImageProvider
                                : NetworkImage(bgUrl),
                            fit: BoxFit.cover,
                            colorFilter: overlayColor != null
                                ? ColorFilter.mode(
                                    overlayColor.withValues(alpha: overlayOpacity),
                                    BlendMode.srcATop,
                                  )
                                : null,
                          )
                        : null,

                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B41A5).withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = constraints.maxHeight;
                      final verticalPadding = cardHeight * 0.04;
                      final bottomPadding = hasActions ? cardHeight * 0.22 : verticalPadding;
                      final logoSize = (cardHeight * 0.38).clamp(36.0, 75.0);

                      // ── Smart Card Logo / Image Resolution ──
                      // Profile image is strictly blocked from card carousel per user request
                      String companyLogoUrl = '';
                      if (card.companyLogo != null &&
                          card.companyLogo!.trim().isNotEmpty &&
                          card.companyLogo!.trim().toLowerCase() != 'null') {
                        companyLogoUrl = card.companyLogo!.trim();
                      }

                      return Padding(
                        padding: EdgeInsets.fromLTRB(16, verticalPadding, 16, bottomPadding),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SmartCardAvatarImage(
                                companyLogoUrl: companyLogoUrl,
                                logoSize: logoSize,
                                customTextColor: customTextColor,
                                displayName: displayName,
                                onTap: onTap,
                              ),
                              SizedBox(height: cardHeight * 0.02),

                              // Display Name (Responsive FittedBox scaling)
                              if (displayName.isNotEmpty)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    displayName,
                                    textAlign: TextAlign.center,
                                    style: AppFonts.poppins(
                                      fontSize: (cardHeight * 0.075).clamp(13.0, 22.0),
                                      fontWeight: FontWeight.bold,
                                      color: customTextColor,
                                      letterSpacing: 0.3,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),

                              if (card.designation?.isNotEmpty == true) ...[
                                SizedBox(height: cardHeight * 0.008),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    card.designation!,
                                    textAlign: TextAlign.center,
                                    style: AppFonts.poppins(
                                      fontSize: (cardHeight * 0.055).clamp(11.0, 16.0),
                                      fontWeight: FontWeight.w600,
                                      color: customTextColor.withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (card.isPrimary)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 4),
                          Text(
                            'Primary',
                            style: AppFonts.poppins(
                              color: const Color(0xFFFBBF24),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PulsingBadge(isActive: !card.isSuspended),
                ],
              ),
            ),
            if (hasActions)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 58,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 8),
                  child: bottomActions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmartCardAvatarImage extends StatelessWidget {
  final String companyLogoUrl;
  final double logoSize;
  final Color customTextColor;
  final String displayName;
  final VoidCallback? onTap;

  const SmartCardAvatarImage({
    super.key,
    required this.companyLogoUrl,
    required this.logoSize,
    required this.customTextColor,
    required this.displayName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    String? fullImageSrc;
    if (companyLogoUrl.isNotEmpty) {
      fullImageSrc = UploadUrlResolver.resolve(companyLogoUrl, type: 'logo');
    }

    Widget imageWidget;
    if (fullImageSrc != null && fullImageSrc.isNotEmpty) {
      imageWidget = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: logoSize,
          maxWidth: MediaQuery.of(context).size.width * 0.70,
        ),
        child: Image.network(
          fullImageSrc,
          height: logoSize,
          fit: BoxFit.fitHeight,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.business_rounded,
            color: customTextColor,
            size: logoSize * 0.9,
          ),
        ),
      );
    } else {
      imageWidget = Icon(
        Icons.business_rounded,
        color: customTextColor,
        size: logoSize * 0.9,
      );
    }

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!();
        } else if (fullImageSrc != null && fullImageSrc.isNotEmpty) {
          ContactDetailScreen.showFullImageDialog(
            context,
            fullImageSrc,
            displayName,
            displayName.isNotEmpty ? displayName[0] : 'C',
          );
        }
      },
      child: imageWidget,
    );
  }
}


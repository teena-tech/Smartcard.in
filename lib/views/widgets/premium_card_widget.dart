import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/card_model.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../../core/constants/app_colors.dart';


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
          Text(text, style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class PremiumCardWidget extends StatelessWidget {
  final CardModel card;
  final EdgeInsetsGeometry? margin;
  final Widget? bottomActions;

  const PremiumCardWidget({
    super.key,
    required this.card,
    this.margin,
    this.bottomActions,
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
                        color: Colors.white.withValues(alpha: 0.75),
                        blurRadius: 20,
                        spreadRadius: 3,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cardHeight = constraints.maxHeight;
                      final verticalPadding = cardHeight * 0.04;
                      final bottomPadding = hasActions ? cardHeight * 0.22 : verticalPadding;
                      final logoSize = cardHeight * 0.44;

                      return Padding(
                        padding: EdgeInsets.fromLTRB(20, verticalPadding, 20, bottomPadding),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Center-aligned Logo (🏢)
                              if (card.companyLogo != null && card.companyLogo!.isNotEmpty) ...[
                                Image.network(
                                  UploadUrlResolver.resolve(card.companyLogo!, type: 'logo'),
                                  height: logoSize,
                                  width: logoSize,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.business_rounded, 
                                    color: customTextColor, 
                                    size: logoSize * 0.9,
                                  ),
                                ),
                              ] else ...[
                                Icon(
                                  Icons.business_rounded, 
                                  color: customTextColor, 
                                  size: logoSize * 0.9,
                                ),
                              ],
                               SizedBox(height: cardHeight * 0.015),

                               // Display Name (Company Name or Personal Name fallback)
                               if (displayName.isNotEmpty)
                                 Text(
                                   displayName,
                                   textAlign: TextAlign.center,
                                   style: GoogleFonts.inter(
                                     fontSize: cardHeight * 0.080,
                                     fontWeight: FontWeight.bold,
                                     color: customTextColor,
                                     letterSpacing: 0.3,
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),

                               SizedBox(height: cardHeight * 0.008),

                               // Designation
                               if (card.designation?.isNotEmpty == true)
                                 Text(
                                   card.designation!,
                                   textAlign: TextAlign.center,
                                   style: GoogleFonts.inter(
                                     fontSize: cardHeight * 0.060,
                                     fontWeight: FontWeight.w500,
                                     color: customTextColor.withValues(alpha: 0.75),
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
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
                            style: GoogleFonts.inter(
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
    );
  }
}

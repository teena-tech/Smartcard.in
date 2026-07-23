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
    String displayCompanyName = card.companyName;
    if (displayCompanyName.length > 24) {
      displayCompanyName = '${displayCompanyName.substring(0, 24)}...';
    }

    final hasBgImage = card.backgroundImage != null && card.backgroundImage!.trim().isNotEmpty;
    final bgUrl = hasBgImage ? UploadUrlResolver.resolve(card.backgroundImage!.trim(), type: 'card-bg') : '';

    final customBgColor = _parseHexColor(card.backgroundColor);
    final customTextColor = _parseHexColor(card.textColor) ?? Colors.white;
    final overlayColor = _parseHexColor(card.bgImageColor);
    final overlayOpacity = _parseOpacity(card.opacity);

    final hasBgColor = customBgColor != null;
    final hasActions = bottomActions != null;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // Card dimensions
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 680),
      height: hasActions ? 245 : 230,
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
                      ? const LinearGradient(
                          colors: [Color(0xFF6B41A5), Color(0xFFC781DD)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: hasBgImage && bgUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(bgUrl),
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
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, hasActions ? 56 : 16),
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
                      height: hasActions ? 90 : 105,
                      width: hasActions ? 90 : 105,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.business_rounded, 
                        color: customTextColor, 
                        size: hasActions ? 80 : 96,
                      ),
                    ),
                  ] else ...[
                    Icon(
                      Icons.business_rounded, 
                      color: customTextColor, 
                      size: hasActions ? 80 : 96,
                    ),
                  ],
                  const SizedBox(height: 8),

                  // Company Name
                  if (card.companyName != null && card.companyName!.isNotEmpty)
                    Text(
                      card.companyName!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: customTextColor,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 4),

                  // Designation
                  if (card.designation?.isNotEmpty == true)
                    Text(
                      card.designation!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: customTextColor.withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
                    ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: PulsingBadge(isActive: !card.isSuspended),
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
    );
  }
}


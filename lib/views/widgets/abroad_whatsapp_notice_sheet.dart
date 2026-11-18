import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

/// A widget that applies a rhythmic dual-pulse "heartbeat" animation (lub-dub)
/// to draw high attention to critical notices.
class HeartbeatNotice extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Widget? leadingIcon;
  final Color backgroundColor;
  final Color borderColor;

  const HeartbeatNotice({
    super.key,
    required this.text,
    this.style,
    this.leadingIcon,
    this.backgroundColor = const Color(0xFFFFF0F2),
    this.borderColor = const Color(0xFFFFB3BA),
  });

  @override
  State<HeartbeatNotice> createState() => _HeartbeatNoticeState();
}

class _HeartbeatNoticeState extends State<HeartbeatNotice>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Rhythmic dual-pulse "lub-dub" heartbeat sequence
    _scaleAnimation = TweenSequence<double>([
      // First beat (lub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.06)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.06, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 12,
      ),
      // Second beat (dub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.04)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.04, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 12,
      ),
      // Pause between cycles
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 54,
      ),
    ]).animate(_controller);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 8.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 24,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 8.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 54,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.15),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _glowAnimation.value > 0 ? 1 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.leadingIcon != null) ...[
                  widget.leadingIcon!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    widget.text,
                    style: widget.style ??
                        GoogleFonts.inter(
                          color: const Color(0xFFDC2626),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Bottom Sheet displayed when the user taps/opens the Country Code selector.
class AbroadWhatsAppNoticeSheet extends StatelessWidget {
  final VoidCallback? onWhatsAppLogin;

  const AbroadWhatsAppNoticeSheet({
    super.key,
    this.onWhatsAppLogin,
  });

  /// Static helper to display this bottom sheet from anywhere
  static Future<void> show(
    BuildContext context, {
    VoidCallback? onWhatsAppLogin,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AbroadWhatsAppNoticeSheet(
        onWhatsAppLogin: onWhatsAppLogin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.public_rounded,
                  color: AppColors.primaryRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Country Code & Access',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Active Country Code info box (India +91)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Text(
                  '🇮🇳',
                  style: TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'India (+91)',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'Direct SMS OTP enabled',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Active',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Heartbeat Effect Warning Notice
          HeartbeatNotice(
            text: 'Users outside India are requested to log in via WhatsApp to continue.',
            leadingIcon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // WhatsApp Login Action Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              if (onWhatsAppLogin != null) {
                onWhatsAppLogin!();
              }
            },
            icon: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              'Log in via WhatsApp',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366), // Official WhatsApp Green
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              shadowColor: const Color(0xFF25D366).withValues(alpha: 0.4),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary Dismiss Option
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue with +91 (India)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

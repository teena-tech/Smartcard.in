import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Professional non-blocking banner displayed for 5 seconds when a duplicate phone number is detected.
class DuplicatePhoneBanner extends StatefulWidget {
  final VoidCallback? onDismissed;
  final Duration autoDismissDuration;
  final String? existingName;
  final String? existingCompany;

  const DuplicatePhoneBanner({
    super.key,
    this.onDismissed,
    this.autoDismissDuration = const Duration(seconds: 5),
    this.existingName,
    this.existingCompany,
  });

  @override
  State<DuplicatePhoneBanner> createState() => _DuplicatePhoneBannerState();
}

class _DuplicatePhoneBannerState extends State<DuplicatePhoneBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    // Auto-dismiss after 5 seconds
    _dismissTimer = Timer(widget.autoDismissDuration, () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (_isDismissed || !mounted) return;
    _isDismissed = true;
    _animController.reverse().then((_) {
      if (mounted) {
        widget.onDismissed?.call();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed && _animController.isDismissed) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 50),
          child: Opacity(
            opacity: _fadeAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.existingName != null && widget.existingName!.trim().isNotEmpty
                        ? 'Phone exists for ${widget.existingName}${widget.existingCompany != null && widget.existingCompany!.trim().isNotEmpty ? " (${widget.existingCompany})" : ""}'
                        : 'This phone number already exists in your contacts',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Swipe left/right below to replace or keep fields (Company, Email, etc.). Phone number is locked.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white70 : const Color(0xFF1E40AF),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

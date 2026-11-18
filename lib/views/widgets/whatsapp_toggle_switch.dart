import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom toggle switch matching the WhatsApp icon thumb design from the sketch
class WhatsAppToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;

  const WhatsAppToggleSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isInteractive = enabled && onChanged != null;

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !isInteractive,
          child: GestureDetector(
            onTap: isInteractive ? () => onChanged!(!value) : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: value ? const Color(0xFF25D366) : const Color(0xFFE2E8F0),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: value
                              ? const Color(0xFF25D366).withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1.5),
                        ),
                      ]
                    : [],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.whatsapp,
                      size: 14,
                      color: Color(0xFF25D366),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rhythmic dual-pulse heartbeat animated text notice for abroad login
class HeartbeatTextNotice extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;

  const HeartbeatTextNotice({
    super.key,
    required this.text,
    this.onTap,
  });

  @override
  State<HeartbeatTextNotice> createState() => _HeartbeatTextNoticeState();
}

class _HeartbeatTextNoticeState extends State<HeartbeatTextNotice>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.025)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.025, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 43,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88),
        weight: 27,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.88),
        weight: 43,
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
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.centerLeft,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Text(
                  widget.text,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFDC2626),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';

class QrOverlay extends StatelessWidget {
  final bool isDetected;
  final VoidCallback? onTap;

  const QrOverlay({
    super.key,
    this.isDetected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.65;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Top-Left Corner
                Positioned(
                  top: 0,
                  left: 0,
                  child: _CornerBracket(isTop: true, isLeft: true, isDetected: isDetected),
                ),
                // Top-Right Corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: _CornerBracket(isTop: true, isLeft: false, isDetected: isDetected),
                ),
                // Bottom-Left Corner
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: _CornerBracket(isTop: false, isLeft: true, isDetected: isDetected),
                ),
                // Bottom-Right Corner
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: _CornerBracket(isTop: false, isLeft: false, isDetected: isDetected),
                ),

                if (isDetected)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.black, size: 36),
                    )
                        .animate()
                        .scale(duration: 250.ms, curve: Curves.easeOutBack),
                  ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(end: 1.03, duration: 1500.ms, curve: Curves.easeInOut),
          const SizedBox(height: 28),
          Text(
            isDetected ? 'QR Code Detected ✓' : 'Point at QR code',
            style: AppFonts.poppins(
              color: isDetected ? const Color(0xFF00E676) : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Auto scanning',
            style: AppFonts.poppins(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool isTop;
  final bool isLeft;
  final bool isDetected;

  const _CornerBracket({
    required this.isTop,
    required this.isLeft,
    required this.isDetected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDetected ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    const length = 28.0;
    const thickness = 4.0;

    return Container(
      width: length,
      height: length,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          bottom: !isTop ? BorderSide(color: color, width: thickness) : BorderSide.none,
          left: isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
          right: !isLeft ? BorderSide(color: color, width: thickness) : BorderSide.none,
        ),
      ),
    );
  }
}

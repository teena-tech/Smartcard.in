import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';

class ScannerStatusWidget extends StatelessWidget {
  final String message;
  final double stabilityProgress;
  final VoidCallback? onManualCaptureTap;
  final bool showManualFallback;

  const ScannerStatusWidget({
    super.key,
    required this.message,
    this.stabilityProgress = 0.0,
    this.onManualCaptureTap,
    this.showManualFallback = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E).withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stabilityProgress >= 1.0
                      ? const Color(0xFF00E676)
                      : (stabilityProgress > 0 ? Colors.amber : const Color(0xFFFF5252)),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                message,
                style: AppFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Stability Progress Bar (shown when detecting/aligning/holding steady)
        if (stabilityProgress > 0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stabilityProgress,
                minHeight: 6,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(
                  stabilityProgress >= 1.0 ? const Color(0xFF00E676) : Colors.amber,
                ),
              ),
            ),
          ),
        ],

        // Manual Capture Fallback Button
        if (showManualFallback) ...[
          const SizedBox(height: 20),
          TextButton(
            onPressed: onManualCaptureTap,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  'Capture Manually',
                  style: AppFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

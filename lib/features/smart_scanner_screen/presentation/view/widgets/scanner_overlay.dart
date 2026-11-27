import 'package:flutter/material.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scan_type.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scanner_state.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/detected_card.dart';

/// Full scanner overlay widget with viewfinder frame, top controls, guidance and action buttons
class ScannerOverlay extends StatelessWidget {
  final ScanType scanType;
  final ScannerStateEnum state;
  final DetectedCard? detectedCard;
  final double stabilityProgress;
  final bool isTorchOn;
  final VoidCallback? onTorchToggle;
  final VoidCallback? onCameraSwitch;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onCaptureTap;
  final VoidCallback? onBackPressed;

  const ScannerOverlay({
    super.key,
    required this.scanType,
    required this.state,
    this.detectedCard,
    this.stabilityProgress = 0.0,
    required this.isTorchOn,
    this.onTorchToggle,
    this.onCameraSwitch,
    this.onGalleryTap,
    this.onCaptureTap,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isCard = scanType == ScanType.businessCard;
    final double frameWidth = isCard ? size.width * 0.88 : size.width * 0.72;
    final double frameHeight = isCard ? (frameWidth / 1.586) : frameWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cutout Frame Painter
        CustomPaint(
          size: Size.infinite,
          painter: ScannerOverlayPainter(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            cornerColor: const Color(0xFFFF5252),
          ),
        ),

        // Top Controls Bar (Back, Flash, Switch Camera)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GlassScannerButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBackPressed ?? () => Navigator.maybePop(context),
                    ),
                    Text(
                      isCard ? 'Scan Business Card' : 'Scan QR Code',
                      style: AppFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        if (onTorchToggle != null)
                          GlassScannerButton(
                            icon: isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                            active: isTorchOn,
                            onTap: onTorchToggle,
                          ),
                        if (onCameraSwitch != null) ...[
                          const SizedBox(width: 8),
                          GlassScannerButton(
                            icon: Icons.flip_camera_ios_rounded,
                            onTap: onCameraSwitch,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Guidance Message
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isCard ? state.userFeedbackMessage : 'Align QR code in frame',
                      textAlign: TextAlign.center,
                      style: AppFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (stabilityProgress > 0) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stabilityProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5252)),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Actions
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (onGalleryTap != null)
                GlassScannerButton(
                  icon: Icons.photo_library_outlined,
                  size: 52,
                  onTap: onGalleryTap,
                )
              else
                const SizedBox(width: 52),

              if (onCaptureTap != null)
                GestureDetector(
                  onTap: onCaptureTap,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: const Color(0xFFFF5252),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 32),
                  ),
                )
              else
                const SizedBox(width: 72),

              const SizedBox(width: 52),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dark overlay with rounded cutout and corner brackets for scanner UI.
class ScannerOverlayPainter extends CustomPainter {
  final double frameWidth;
  final double frameHeight;
  final Color borderColor;
  final Color cornerColor;
  final double radius;
  final double overlayOpacity;

  ScannerOverlayPainter({
    required this.frameWidth,
    required this.frameHeight,
    this.borderColor = Colors.white24,
    this.cornerColor = const Color(0xFFFF5252),
    this.radius = 28,
    this.overlayOpacity = 0.72,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: frameWidth,
      height: frameHeight,
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black.withValues(alpha: 0.1),
    );
    canvas.drawPath(
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
      Paint()
        ..blendMode = BlendMode.dstOut
        ..style = PaintingStyle.fill,
    );
    canvas.restore();

    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final corner = 32.0;
    final paint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;

    canvas.drawPath(
      Path()
        ..moveTo(tl.dx, tl.dy + corner)
        ..lineTo(tl.dx, tl.dy + radius)
        ..quadraticBezierTo(tl.dx, tl.dy, tl.dx + radius, tl.dy)
        ..lineTo(tl.dx + corner, tl.dy)
        ..moveTo(tr.dx - corner, tr.dy)
        ..lineTo(tr.dx - radius, tr.dy)
        ..quadraticBezierTo(tr.dx, tr.dy, tr.dx, tr.dy + radius)
        ..lineTo(tr.dx, tr.dy + corner)
        ..moveTo(bl.dx, bl.dy - corner)
        ..lineTo(bl.dx, bl.dy - radius)
        ..quadraticBezierTo(bl.dx, bl.dy, bl.dx + radius, bl.dy)
        ..lineTo(bl.dx + corner, bl.dy)
        ..moveTo(br.dx - corner, br.dy)
        ..lineTo(br.dx - radius, br.dy)
        ..quadraticBezierTo(br.dx, br.dy, br.dx, br.dy - radius)
        ..lineTo(br.dx, br.dy - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter oldDelegate) =>
      oldDelegate.frameWidth != frameWidth ||
      oldDelegate.frameHeight != frameHeight ||
      oldDelegate.borderColor != borderColor;
}

/// Glassmorphism circular control button.
class GlassScannerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final double size;

  const GlassScannerButton({
    super.key,
    required this.icon,
    this.onTap,
    this.active = false,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? const Color(0xFFFF5252).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.2),
          border: Border.all(
            color: active
                ? const Color(0xFFFF5252).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: active ? const Color(0xFFFF5252) : Colors.white,
          size: size * 0.42,
        ),
      ),
    );
  }
}

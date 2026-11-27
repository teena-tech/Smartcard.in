import 'package:flutter/material.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/detected_card.dart';

class CardOverlay extends StatelessWidget {
  final DetectedCard? detectedCard;
  final bool isCapturing;

  const CardOverlay({
    super.key,
    this.detectedCard,
    this.isCapturing = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CardOverlayPainter(
        detectedCard: detectedCard,
        isCapturing: isCapturing,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CardOverlayPainter extends CustomPainter {
  final DetectedCard? detectedCard;
  final bool isCapturing;

  _CardOverlayPainter({
    required this.detectedCard,
    required this.isCapturing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final card = detectedCard;

    if (card == null) {
      // Draw fallback guide card outline when searching
      final guideWidth = size.width * 0.82;
      final guideHeight = guideWidth / 1.6; // Business card standard ratio (~1.6:1)
      final guideRect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height * 0.42),
        width: guideWidth,
        height: guideHeight,
      );

      final guidePaint = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final RRect rrect = RRect.fromRectAndRadius(guideRect, const Radius.circular(16));
      canvas.drawRRect(rrect, guidePaint);
      return;
    }

    final color = isCapturing || card.isStable
        ? const Color(0xFF00E676)
        : const Color(0xFFFFD54F);

    final corners = card.corners;
    final path = Path()
      ..moveTo(corners.topLeft.dx, corners.topLeft.dy)
      ..lineTo(corners.topRight.dx, corners.topRight.dy)
      ..lineTo(corners.bottomRight.dx, corners.bottomRight.dy)
      ..lineTo(corners.bottomLeft.dx, corners.bottomLeft.dy)
      ..close();

    // Fill polygon background subtly
    final fillPaint = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border line
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isCapturing ? 4.5 : 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // Corner dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const dotRadius = 7.0;
    canvas.drawCircle(corners.topLeft, dotRadius, dotPaint);
    canvas.drawCircle(corners.topRight, dotRadius, dotPaint);
    canvas.drawCircle(corners.bottomRight, dotRadius, dotPaint);
    canvas.drawCircle(corners.bottomLeft, dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _CardOverlayPainter oldDelegate) {
    return oldDelegate.detectedCard != detectedCard || oldDelegate.isCapturing != isCapturing;
  }
}

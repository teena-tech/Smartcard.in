import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Scanner states for the Adobe Scan-style visual workflow
enum CardScanState {
  searching,
  detecting,
  aligning,
  moving,
  stable,
  capturing,
  processing,
  completed,
}

/// Dynamic card 4-corner quadrilateral model
class CardCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const CardCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  List<Offset> get points => [
        topLeft,
        topRight,
        bottomRight,
        bottomLeft,
      ];
}

/// Adobe Scan-style Live Camera Card Tracking & Scanner Overlay
class CardTrackerOverlay extends StatefulWidget {
  final Rect? detectedRect;
  final CardCorners? customCorners;
  final VoidCallback? onLocked;
  final bool locked;
  final CardScanState scanState;

  const CardTrackerOverlay({
    super.key,
    this.detectedRect,
    this.customCorners,
    this.onLocked,
    this.locked = false,
    this.scanState = CardScanState.searching,
  });

  @override
  State<CardTrackerOverlay> createState() => _CardTrackerOverlayState();
}

class _CardTrackerOverlayState extends State<CardTrackerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _laserCtrl;
  late Animation<double> _laserAnim;
  late AnimationController _pulseCtrl;

  int _countdown = 3;
  Timer? _countdownTimer;
  bool _isHolding = false;
  bool _lockFired = false;

  @override
  void initState() {
    super.initState();

    _laserCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _laserAnim = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CardTrackerOverlay old) {
    super.didUpdateWidget(old);

    if (widget.detectedRect != null && old.detectedRect == null) {
      _startCountdown();
    } else if (widget.detectedRect == null && old.detectedRect != null) {
      _resetCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _countdown = 3;
      _isHolding = true;
      _lockFired = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (widget.detectedRect == null && widget.customCorners == null) {
        _resetCountdown();
        return;
      }
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        if (!_lockFired && mounted) {
          setState(() {
            _countdown = 0;
            _lockFired = true;
          });
          widget.onLocked?.call();
        }
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _countdown = 3;
        _isHolding = false;
        _lockFired = false;
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _laserCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  CardScanState get _computedState {
    if (widget.scanState == CardScanState.capturing ||
        widget.scanState == CardScanState.processing ||
        widget.scanState == CardScanState.completed) {
      return widget.scanState;
    }
    if (_lockFired || widget.locked) {
      return CardScanState.capturing;
    }
    if (widget.detectedRect != null || widget.customCorners != null) {
      return _isHolding ? CardScanState.stable : CardScanState.aligning;
    }
    return CardScanState.searching;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final currentState = _computedState;
    final isDetected = widget.detectedRect != null || widget.customCorners != null;

    return AnimatedBuilder(
      animation: Listenable.merge([_laserAnim, _pulseCtrl]),
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Darkened background frame with transparent card cutout
            CustomPaint(
              size: size,
              painter: ScannerBackgroundPainter(),
            ),

            // Live 4-Corner Polygon & Laser Line Sweep Painter
            CustomPaint(
              size: size,
              painter: AdobeCardDetectionPainter(
                detectedRect: widget.detectedRect,
                customCorners: widget.customCorners,
                state: currentState,
                laserProgress: _laserAnim.value,
                pulseValue: _pulseCtrl.value,
              ),
            ),

            // Processing Laser Sweep overlay
            if (currentState == CardScanState.processing)
              const ProcessingScanLine(),

            // Screen Center Countdown Badge when steady hold is active
            if (isDetected && _isHolding && _countdown > 0 && currentState == CardScanState.stable)
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.8),
                    border: Border.all(color: const Color(0xFF00E676), width: 3.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.4),
                        blurRadius: 22,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$_countdown',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00E676),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            // Top Status Chip
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 24,
              right: 24,
              child: ScannerStatus(state: currentState),
            ),

            // Bottom Instruction Message
            Positioned(
              bottom: 165,
              left: 30,
              right: 30,
              child: ScannerInstruction(state: currentState),
            ),
          ],
        );
      },
    );
  }
}

/// Adobe Scan style background overlay with rounded camera viewfinder
class ScannerBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.25);
    canvas.drawRect(Offset.zero & size, bgPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Adobe Scan Style 4-Corner Line & Animated Corner Painter
class AdobeCardDetectionPainter extends CustomPainter {
  final Rect? detectedRect;
  final CardCorners? customCorners;
  final CardScanState state;
  final double laserProgress;
  final double pulseValue;

  AdobeCardDetectionPainter({
    required this.detectedRect,
    required this.customCorners,
    required this.state,
    required this.laserProgress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detectedRect == null && customCorners == null) {
      _drawSearchingViewfinder(canvas, size);
      return;
    }

    // Determine 4 corner points (custom quadrilateral or rect corners)
    final List<Offset> points = customCorners?.points ??
        [
          detectedRect!.topLeft,
          detectedRect!.topRight,
          detectedRect!.bottomRight,
          detectedRect!.bottomLeft,
        ];

    final isStable = state == CardScanState.stable || state == CardScanState.capturing;
    final strokeColor = isStable ? const Color(0xFF00E676) : const Color(0xFF29B6F6);

    // Build bounding path
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    // Semi-transparent card fill
    final fillPaint = Paint()
      ..color = strokeColor.withValues(alpha: isStable ? 0.15 : 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border line stroke
    final borderPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isStable ? 4.5 : 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, borderPaint);

    // Draw the 4 individual animated corner dots (Adobe Scan style)
    for (int i = 0; i < points.length; i++) {
      _drawAdobeCornerDot(canvas, points[i], isStable);
    }

    // Draw Laser Scan Sweep line across card bounding box
    final topY = points[0].dy;
    final bottomY = points[2].dy;
    final cardHeight = (bottomY - topY).abs();
    if (cardHeight > 20) {
      final laserY = topY + (cardHeight * laserProgress);
      final leftX = points[0].dx < points[3].dx ? points[0].dx : points[3].dx;
      final rightX = points[1].dx > points[2].dx ? points[1].dx : points[2].dx;

      final laserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            strokeColor.withValues(alpha: 0.0),
            strokeColor.withValues(alpha: 0.95),
            strokeColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(leftX, laserY, rightX, laserY + 3.5))
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(leftX + 8, laserY),
        Offset(rightX - 8, laserY),
        laserPaint,
      );
    }
  }

  void _drawAdobeCornerDot(Canvas canvas, Offset point, bool isStable) {
    final outerColor = isStable ? const Color(0xFF00E676) : const Color(0xFF29B6F6);
    final outerRadius = isStable ? 16.0 : (16.0 + (pulseValue * 3.5));

    // Outer glowing aura
    final auraPaint = Paint()
      ..color = outerColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, outerRadius + 6, auraPaint);

    // Outer solid dot ring
    final outerPaint = Paint()
      ..color = outerColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, outerRadius, outerPaint);

    // Inner white core
    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(point, outerRadius * 0.55, innerPaint);
  }

  void _drawSearchingViewfinder(Canvas canvas, Size size) {
    final width = size.width * .84;
    final height = width / 1.586;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: width,
      height: height,
    );

    final framePaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Viewfinder card boundary outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      framePaint,
    );

    // 4 Corner Target Brackets
    const cornerLength = 26.0;
    final bracketPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final tl = rect.topLeft;
    final tr = rect.topRight;
    final bl = rect.bottomLeft;
    final br = rect.bottomRight;

    final bracketPath = Path()
      ..moveTo(tl.dx, tl.dy + cornerLength)..lineTo(tl.dx, tl.dy)..lineTo(tl.dx + cornerLength, tl.dy)
      ..moveTo(tr.dx - cornerLength, tr.dy)..lineTo(tr.dx, tr.dy)..lineTo(tr.dx, tr.dy + cornerLength)
      ..moveTo(bl.dx, bl.dy - cornerLength)..lineTo(bl.dx, bl.dy)..lineTo(bl.dx + cornerLength, bl.dy)
      ..moveTo(br.dx - cornerLength, br.dy)..lineTo(br.dx, br.dy)..lineTo(br.dx, br.dy - cornerLength);

    canvas.drawPath(bracketPath, bracketPaint);

    // Searching laser sweep
    final laserY = rect.top + (rect.height * laserProgress);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFF5252).withValues(alpha: 0.0),
          const Color(0xFFFF5252).withValues(alpha: 0.95),
          const Color(0xFFFF5252).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTRB(rect.left, laserY, rect.right, laserY + 3))
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(rect.left + 10, laserY),
      Offset(rect.right - 10, laserY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant AdobeCardDetectionPainter oldDelegate) {
    return oldDelegate.detectedRect != detectedRect ||
        oldDelegate.customCorners != customCorners ||
        oldDelegate.state != state ||
        oldDelegate.laserProgress != laserProgress ||
        oldDelegate.pulseValue != pulseValue;
  }
}

/// Scanner Top Status Pill
class ScannerStatus extends StatelessWidget {
  final CardScanState state;

  const ScannerStatus({super.key, required this.state});

  String get message {
    switch (state) {
      case CardScanState.searching:
        return 'Looking for a card...';
      case CardScanState.detecting:
        return 'Card detected';
      case CardScanState.aligning:
        return 'Align all four corners';
      case CardScanState.moving:
        return 'Move card into frame';
      case CardScanState.stable:
        return 'Perfect — hold steady';
      case CardScanState.capturing:
        return 'Capturing card...';
      case CardScanState.processing:
        return 'Enhancing & reading card...';
      case CardScanState.completed:
        return 'Card scanned successfully!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: state == CardScanState.stable || state == CardScanState.completed
                ? const Color(0xFF00E676).withValues(alpha: 0.5)
                : Colors.white12,
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusIndicator(state: state),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                message,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      )
          .animate(key: ValueKey(state))
          .fadeIn(duration: 250.ms)
          .slideY(begin: -0.15, end: 0),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final CardScanState state;

  const _StatusIndicator({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == CardScanState.stable || state == CardScanState.completed) {
      return const Icon(
        Icons.check_circle_rounded,
        color: Color(0xFF00E676),
        size: 20,
      );
    }

    if (state == CardScanState.processing || state == CardScanState.capturing) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: Colors.white,
        ),
      );
    }

    return const Icon(
      Icons.document_scanner_rounded,
      color: Color(0xFF29B6F6),
      size: 20,
    );
  }
}

/// Scanner Bottom Guidance Instruction
class ScannerInstruction extends StatelessWidget {
  final CardScanState state;

  const ScannerInstruction({super.key, required this.state});

  String get text {
    switch (state) {
      case CardScanState.searching:
        return 'Place business card inside frame';
      case CardScanState.detecting:
        return 'Keep camera still';
      case CardScanState.aligning:
        return 'Adjust card position to fit all 4 corners';
      case CardScanState.moving:
        return 'Move card slowly toward frame center';
      case CardScanState.stable:
        return 'Hold steady — capturing automatically';
      case CardScanState.capturing:
        return 'Capturing image...';
      case CardScanState.processing:
        return 'Cropping & extracting card details...';
      case CardScanState.completed:
        return 'Card captured!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Processing Scan Line Sweep Widget
class ProcessingScanLine extends StatefulWidget {
  const ProcessingScanLine({super.key});

  @override
  State<ProcessingScanLine> createState() => _ProcessingScanLineState();
}

class _ProcessingScanLineState extends State<ProcessingScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return FractionallySizedBox(
          heightFactor: 1,
          child: Align(
            alignment: Alignment(0, -1 + (controller.value * 2)),
            child: Container(
              height: 3.5,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF29B6F6).withValues(alpha: 0.6),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

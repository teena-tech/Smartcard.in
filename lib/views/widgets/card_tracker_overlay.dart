import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen card-tracking overlay.
///
/// **Searching**: 4 corner darts drift independently across the full screen
/// in a slow, organic search pattern — no fixed box shown.
///
/// **Detected**: corners smoothly animate to snap onto [detectedRect].
/// Border turns green, [onLocked] fires after confirmation animation.
class CardTrackerOverlay extends StatefulWidget {
  final Rect? detectedRect;
  final VoidCallback? onLocked;
  final bool locked;

  const CardTrackerOverlay({
    super.key,
    this.detectedRect,
    this.onLocked,
    this.locked = false,
  });

  @override
  State<CardTrackerOverlay> createState() => _CardTrackerOverlayState();
}

class _CardTrackerOverlayState extends State<CardTrackerOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _lockCtrl;
  late AnimationController _searchCtrl;

  late Animation<double> _pulse;
  late Animation<double> _lock;

  // Independent search positions for each corner (TL, TR, BL, BR)
  // Each corner has its own phase offset to look organic
  final List<double> _phases = [0.0, 1.57, 3.14, 4.71];
  final List<double> _phasesSlow = [0.0, 2.1, 1.05, 3.3];

  // Animated corner positions (lerped from search → detected)
  Offset _tlAnim = Offset.zero;
  Offset _trAnim = Offset.zero;
  Offset _blAnim = Offset.zero;
  Offset _brAnim = Offset.zero;
  bool _positionsInitialized = false;

  // Lock state
  bool _lockFired = false;

  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _lockCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _searchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );

    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _lock = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lockCtrl, curve: Curves.easeOut),
    );

    // Drive the free-roaming search animation at ~60fps
    _searchTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!context.mounted) return;
      for (int i = 0; i < 4; i++) {
        _phases[i] += 0.012 + i * 0.003;
        _phasesSlow[i] += 0.007 + i * 0.002;
      }
      if (widget.detectedRect == null && context.mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(CardTrackerOverlay old) {
    super.didUpdateWidget(old);

    if (widget.detectedRect != null && old.detectedRect == null) {
      // Card just detected — animate lock
      _lockCtrl.forward(from: 0);
      
      // Delay auto-capture by 2 seconds so corners have snap-stabilized onto card
      Future.delayed(const Duration(seconds: 2), () {
        if (widget.detectedRect != null && !_lockFired && context.mounted) {
          _lockFired = true;
          widget.onLocked?.call();
        }
      });
    }
    if (widget.detectedRect == null && old.detectedRect != null) {
      _lockFired = false;
      _lockCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _pulseCtrl.dispose();
    _lockCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Returns the 4 free-roaming corner positions during search mode.
  /// Each corner orbits independently using a Lissajous-like path.
  List<Offset> _searchCorners(Size screen) {
    final cx = screen.width / 2;
    final cy = screen.height * 0.44;

    // Base offsets define where each corner "naturally" orbits from center
    // TL, TR, BL, BR quadrant offsets
    const quadrantOffsets = [
      Offset(-1, -1), // TL
      Offset(1, -1),  // TR
      Offset(-1, 1),  // BL
      Offset(1, 1),   // BR
    ];

    final baseRadius = math.min(screen.width, screen.height) * 0.30;

    return List.generate(4, (i) {
      final qx = quadrantOffsets[i].dx;
      final qy = quadrantOffsets[i].dy;

      // Each corner wanders in its quadrant with sine/cosine drift
      final wanderX = math.sin(_phases[i]) * 28 + math.cos(_phasesSlow[i]) * 14;
      final wanderY = math.cos(_phases[i] * 0.8) * 22 + math.sin(_phasesSlow[i] * 1.1) * 10;

      return Offset(
        cx + qx * (baseRadius + wanderX),
        cy + qy * (baseRadius * 0.65 + wanderY),
      );
    });
  }

  /// Returns the 4 fixed corner positions for a detected [rect].
  List<Offset> _detectedCorners(Rect rect) => [
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Initialize corner positions on first build
    if (!_positionsInitialized) {
      final sc = _searchCorners(size);
      _tlAnim = sc[0];
      _trAnim = sc[1];
      _blAnim = sc[2];
      _brAnim = sc[3];
      _positionsInitialized = true;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _lock]),
      builder: (ctx, _) {
        final isDetected = widget.detectedRect != null;
        final lockP = _lock.value;

        final List<Offset> targetCorners = isDetected
            ? _detectedCorners(widget.detectedRect!)
            : _searchCorners(size);

        // Smoothly lerp corners toward target
        _tlAnim = Offset.lerp(_tlAnim, targetCorners[0], isDetected ? 0.15 : 0.06)!;
        _trAnim = Offset.lerp(_trAnim, targetCorners[1], isDetected ? 0.15 : 0.06)!;
        _blAnim = Offset.lerp(_blAnim, targetCorners[2], isDetected ? 0.15 : 0.06)!;
        _brAnim = Offset.lerp(_brAnim, targetCorners[3], isDetected ? 0.15 : 0.06)!;

        final cornerColor = isDetected
            ? Color.lerp(
                const Color(0xFFFF5252),
                Colors.greenAccent,
                lockP,
              )!.withValues(alpha: _pulse.value)
            : const Color(0xFFFF5252).withValues(alpha: _pulse.value);

        return Stack(
          children: [
            // Corner darts painter — no box, no vignette
            CustomPaint(
              size: size,
              painter: _FreeCornerPainter(
                tl: _tlAnim,
                tr: _trAnim,
                bl: _blAnim,
                br: _brAnim,
                color: cornerColor,
                locked: isDetected,
                lockProgress: lockP,
              ),
            ),

            // Subtle green glow overlay when card is locked
            if (isDetected && lockP > 0)
              Positioned.fromRect(
                rect: Rect.fromPoints(_tlAnim, _brAnim),
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.greenAccent.withValues(alpha: 0.6 * lockP),
                        width: 2,
                      ),
                      color: Colors.greenAccent.withValues(alpha: 0.07 * lockP),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Status label at bottom
            Positioned(
              bottom: 165,
              left: 0,
              right: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isDetected
                    ? Row(
                        key: const ValueKey('locked'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Colors.greenAccent.withValues(alpha: _pulse.value),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Card detected — capturing...',
                            style: GoogleFonts.inter(
                              color: Colors.greenAccent.withValues(alpha: _pulse.value),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        key: const ValueKey('searching'),
                        'Move camera to find a business card',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Free Corner Painter ───────────────────────────────────────────────────────

class _FreeCornerPainter extends CustomPainter {
  final Offset tl, tr, bl, br;
  final Color color;
  final bool locked;
  final double lockProgress;

  const _FreeCornerPainter({
    required this.tl,
    required this.tr,
    required this.bl,
    required this.br,
    required this.color,
    required this.locked,
    required this.lockProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const armLen = 28.0;
    const radius = 8.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Glow paint
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Draw all 4 corners
    _drawCorner(canvas, tl, CornerType.topLeft, armLen, radius, paint, glowPaint);
    _drawCorner(canvas, tr, CornerType.topRight, armLen, radius, paint, glowPaint);
    _drawCorner(canvas, bl, CornerType.bottomLeft, armLen, radius, paint, glowPaint);
    _drawCorner(canvas, br, CornerType.bottomRight, armLen, radius, paint, glowPaint);
  }

  void _drawCorner(
    Canvas canvas,
    Offset pos,
    CornerType type,
    double len,
    double r,
    Paint paint,
    Paint glowPaint,
  ) {
    final path = Path();

    switch (type) {
      case CornerType.topLeft:
        path
          ..moveTo(pos.dx, pos.dy + len)
          ..lineTo(pos.dx, pos.dy + r)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + r, pos.dy)
          ..lineTo(pos.dx + len, pos.dy);
        break;
      case CornerType.topRight:
        path
          ..moveTo(pos.dx - len, pos.dy)
          ..lineTo(pos.dx - r, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + r)
          ..lineTo(pos.dx, pos.dy + len);
        break;
      case CornerType.bottomLeft:
        path
          ..moveTo(pos.dx + len, pos.dy)
          ..lineTo(pos.dx + r, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - r)
          ..lineTo(pos.dx, pos.dy - len);
        break;
      case CornerType.bottomRight:
        path
          ..moveTo(pos.dx - len, pos.dy)
          ..lineTo(pos.dx - r, pos.dy)
          ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - r)
          ..lineTo(pos.dx, pos.dy - len);
        break;
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FreeCornerPainter old) => true;
}

enum CornerType { topLeft, topRight, bottomLeft, bottomRight }

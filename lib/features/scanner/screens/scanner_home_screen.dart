import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scan_type.dart';
import 'qr_scanner_screen.dart';
import 'business_card_scanner_screen.dart';

class ScannerHomeScreen extends StatelessWidget {
  final VoidCallback? onBackPressed;

  const ScannerHomeScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBackPressed ?? () => Navigator.maybePop(context),
        ),
        title: Text(
          'Scan',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'What would you like to scan?',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),

              const SizedBox(height: 32),

              // QR CODE CARD
              _ScanOptionCard(
                title: 'QR CODE',
                description: 'Scan QR codes instantly',
                icon: Icons.qr_code_2_rounded,
                accentColor: const Color(0xFFFF5252),
                delayMs: 150,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QrScannerScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // BUSINESS CARD SCANNER CARD
              _ScanOptionCard(
                title: 'BUSINESS CARD',
                description: 'Save contact info with OCR',
                icon: Icons.badge_outlined,
                accentColor: const Color(0xFF40C4FF),
                delayMs: 300,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BusinessCardScannerScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanOptionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final int delayMs;
  final VoidCallback onTap;

  const _ScanOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.delayMs,
    required this.onTap,
  });

  @override
  State<_ScanOptionCard> createState() => _ScanOptionCardState();
}

class _ScanOptionCardState extends State<_ScanOptionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isPressed ? widget.accentColor : Colors.white.withOpacity(0.08),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withOpacity(_isPressed ? 0.25 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 48,
                  color: widget.accentColor,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 2.seconds, curve: Curves.easeInOut),

              const SizedBox(height: 20),

              Text(
                widget.title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                widget.description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white60,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.delayMs.ms, duration: 450.ms)
        .slideY(begin: 0.2, end: 0, delay: widget.delayMs.ms, duration: 450.ms, curve: Curves.easeOut);
  }
}

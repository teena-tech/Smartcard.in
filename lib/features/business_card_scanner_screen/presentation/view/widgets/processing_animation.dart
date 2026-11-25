import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class ProcessingAnimationWidget extends StatefulWidget {
  final String? imagePath;
  final VoidCallback? onComplete;

  const ProcessingAnimationWidget({
    super.key,
    this.imagePath,
    this.onComplete,
  });

  @override
  State<ProcessingAnimationWidget> createState() => _ProcessingAnimationWidgetState();
}

class _ProcessingAnimationWidgetState extends State<ProcessingAnimationWidget> {
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _startStepSequence();
  }

  void _startStepSequence() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _step = 1);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) setState(() => _step = 2);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F1A),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Image Container with Laser Sweep Animation
              Container(
                width: 280,
                height: 175,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFF5252), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FF5252),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    children: [
                      if (widget.imagePath != null && File(widget.imagePath!).existsSync())
                        Image.file(
                          File(widget.imagePath!),
                          width: 280,
                          height: 175,
                          fit: BoxFit.cover,
                        )
                      else
                        Container(
                          color: const Color(0xFF1E1E2E),
                          child: const Center(
                            child: Icon(Icons.credit_card, size: 50, color: Colors.white24),
                          ),
                        ),

                      // Laser Scan Line Sweep
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Color(0xFFFF5252), Colors.transparent],
                            ),
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat())
                          .slideY(begin: 0, end: 55, duration: 1400.ms, curve: Curves.easeInOut),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 36),

              Text(
                'Reading contact details...',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // Checklist Steps
              _ChecklistStep(
                label: 'Image cleaned & enhanced',
                isCompleted: _step >= 0,
                isCurrent: _step == 0,
              ),
              const SizedBox(height: 12),
              _ChecklistStep(
                label: 'Text recognized',
                isCompleted: _step >= 1,
                isCurrent: _step == 1,
              ),
              const SizedBox(height: 12),
              _ChecklistStep(
                label: 'Extracting contact information',
                isCompleted: _step >= 2,
                isCurrent: _step == 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistStep extends StatelessWidget {
  final String label;
  final bool isCompleted;
  final bool isCurrent;

  const _ChecklistStep({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Row(
        children: [
          if (isCompleted)
            const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20)
          else if (isCurrent)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFFF5252),
              ),
            )
          else
            const Icon(Icons.circle_outlined, color: Colors.white24, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: isCompleted || isCurrent ? Colors.white : Colors.white38,
                fontSize: 14,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

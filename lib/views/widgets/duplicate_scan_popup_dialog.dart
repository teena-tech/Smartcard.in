import 'dart:async';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../core/services/contact_photo_resolver.dart';
import '../../models/scanned_contact_model.dart';
import 'circular_profile_avatar.dart';

enum DuplicateScanAction {
  continueScan,
  exit,
  update,
}

/// Professional 10-second transparent rectangular popup with a big swipe button,
/// heartbeat animation effect, and audio warning when an existing contact is detected.
class DuplicateScanPopupDialog extends StatefulWidget {
  final ScannedContactModel incoming;
  final ScannedContactModel existing;
  final VoidCallback onUpdate;
  final VoidCallback onContinueScan;
  final VoidCallback onExit;
  final Duration autoDismissDuration;

  const DuplicateScanPopupDialog({
    super.key,
    required this.incoming,
    required this.existing,
    required this.onUpdate,
    required this.onContinueScan,
    required this.onExit,
    this.autoDismissDuration = const Duration(seconds: 10),
  });

  /// Static helper to display the 10-second transparent popup in the center ("between")
  static Future<DuplicateScanAction> show({
    required BuildContext context,
    required ScannedContactModel incoming,
    required ScannedContactModel existing,
  }) async {
    final result = await showGeneralDialog<DuplicateScanAction>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'DuplicateScanPopup',
      barrierColor: Colors.black.withValues(alpha: 0.65),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: Material(
                color: Colors.transparent,
                child: DuplicateScanPopupDialog(
                  incoming: incoming,
                  existing: existing,
                  onUpdate: () => Navigator.of(ctx).pop(DuplicateScanAction.update),
                  onContinueScan: () => Navigator.of(ctx).pop(DuplicateScanAction.continueScan),
                  onExit: () => Navigator.of(ctx).pop(DuplicateScanAction.exit),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
    return result ?? DuplicateScanAction.continueScan;
  }

  @override
  State<DuplicateScanPopupDialog> createState() => _DuplicateScanPopupDialogState();
}

class _DuplicateScanPopupDialogState extends State<DuplicateScanPopupDialog>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _heartbeatController;
  late Animation<double> _scaleAnimation;
  AudioPlayer? _audioPlayer;
  bool _audioPlayed = false;

  Timer? _timer;
  int _secondsRemaining = 10;
  double _swipeProgress = 0.0;
  bool _isActionTriggered = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.autoDismissDuration.inSeconds;

    // Top progress countdown
    _progressController = AnimationController(
      vsync: this,
      duration: widget.autoDismissDuration,
    )..forward();

    // Heartbeat pulse animation (lub-dub cycle with diastolic rest)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _scaleAnimation = TweenSequence<double>([
      // 1st Beat (small pulse - lub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 14,
      ),
      // 2nd Beat (stronger pulse - dub)
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.065)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.065, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 16,
      ),
      // Diastolic resting pause before next cycle
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    _heartbeatController.repeat();

    // Play heartbeat warning sound on popup appearance
    _playWarningSoundOnce();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _triggerReviewAndEdit();
        }
      });
    });
  }

  Future<void> _playWarningSoundOnce() async {
    if (_audioPlayed) return;
    _audioPlayed = true;

    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.play(AssetSource('audio/heartbeat_warning.wav'));
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  void _triggerReviewAndEdit() {
    if (_isActionTriggered || !mounted) return;
    _isActionTriggered = true;
    _timer?.cancel();
    _progressController.stop();
    _heartbeatController.stop();
    HapticFeedback.heavyImpact();
    widget.onUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    _heartbeatController.dispose();
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.incoming.name.trim().isNotEmpty
        ? widget.incoming.name.trim()
        : (widget.existing.name.trim().isNotEmpty ? widget.existing.name.trim() : 'Unknown Name');
    final displayPhone = widget.incoming.phone.trim().isNotEmpty
        ? widget.incoming.phone.trim()
        : (widget.existing.phone.trim().isNotEmpty ? widget.existing.phone.trim() : 'No Phone');
    final displayCompany = widget.incoming.company.trim().isNotEmpty
        ? widget.incoming.company.trim()
        : (widget.existing.company.trim().isNotEmpty ? widget.existing.company.trim() : '');
    final previewAvatar = ContactPhotoResolver.firstValidSource([
      ContactPhotoResolver.resolveScannedPhotoSource(widget.incoming),
      ContactPhotoResolver.resolveScannedPhotoSource(widget.existing),
    ]);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Countdown Progress Bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              value: 1.0 - _progressController.value,
                              backgroundColor: Colors.white12,
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                              minHeight: 5,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${_secondsRemaining}s',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Icon + Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Lottie.asset(
                          'assets/lottie/warning.json',
                          width: 44,
                          height: 44,
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Existing Contact Found',
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Contact already exists with this phone number',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contact Match Details Card (ONLY Name and Phone Number)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (previewAvatar != null)
                            CircularProfileAvatar(
                              radius: 18,
                              size: 36,
                              animateRing: false,
                              imageUrl: previewAvatar,
                              fallbackText: displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              backgroundColor:
                                  const Color(0xFF38BDF8).withValues(alpha: 0.18),
                              foregroundColor: const Color(0xFF38BDF8),
                            )
                          else
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.person_rounded, size: 20, color: Color(0xFF38BDF8)),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ADE80).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.phone_rounded, size: 20, color: Color(0xFF4ADE80)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone Number',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white54,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayPhone,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF38BDF8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (displayCompany.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFA855F7).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.business_rounded, size: 20, color: Color(0xFFA855F7)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Company',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    displayCompany,
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // BIG SWIPE BUTTON (Update)
                _buildBigSwipeButton(),

                const SizedBox(height: 14),

                // Action Buttons: Continue Scan & Exit
                Row(
                  children: [
                    // Continue Scan Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _timer?.cancel();
                          _progressController.stop();
                          _heartbeatController.stop();
                          widget.onContinueScan();
                        },
                        icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Color(0xFF38BDF8)),
                        label: Text(
                          'Continue Scan',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Exit Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _timer?.cancel();
                          _progressController.stop();
                          _heartbeatController.stop();
                          widget.onExit();
                        },
                        icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                        label: Text(
                          'Exit',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive Big Swipe Button ("Slide to Review & Edit")
  Widget _buildBigSwipeButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double trackWidth = constraints.maxWidth;
        const double trackHeight = 56.0;
        const double thumbWidth = 56.0;
        final double maxDrag = trackWidth - thumbWidth;

        return GestureDetector(
          onTap: () {
            // Allow direct tap as well for convenience
            _triggerReviewAndEdit();
          },
          onHorizontalDragUpdate: (details) {
            setState(() {
              _swipeProgress = (_swipeProgress + (details.delta.dx / maxDrag)).clamp(0.0, 1.0);
              if (_swipeProgress >= 0.88 && !_isActionTriggered) {
                _triggerReviewAndEdit();
              }
            });
          },
          onHorizontalDragEnd: (details) {
            if (_swipeProgress < 0.88) {
              setState(() {
                _swipeProgress = 0.0;
              });
            }
          },
          child: Container(
            height: trackHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Animated fill behind drag thumb
                Container(
                  width: thumbWidth + (_swipeProgress * maxDrag),
                  height: trackHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),

                // Center Prompt Text
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 56.0),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'SWIPE TO UPDATE / EDIT',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.double_arrow_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),

                // Sliding Thumb Handle
                Positioned(
                  left: _swipeProgress * maxDrag,
                  child: Container(
                    width: thumbWidth,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(2, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

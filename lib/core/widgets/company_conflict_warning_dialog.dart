import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

/// User action returned by [CompanyConflictWarningDialog].
enum CompanyConflictAction {
  /// Opens the existing contact details screen.
  viewContact,

  /// Preserves the existing record and saves the new company as an additional record.
  addNewCompany,

  /// Closes the alert and does not save the new company.
  cancel,
}

/// A high-attention, modern professional security/warning dialog displayed
/// when a scanned card has the same phone number as an existing contact,
/// but contains different company/business details.
///
/// Features:
/// - Dark background modal overlay.
/// - Prominent rectangular warning box with rounded corners and strong red glow.
/// - Authentic two-step heartbeat pulse animation (normal -> small pulse -> stronger pulse -> normal -> pause).
/// - Synchronized red glow pulse.
/// - Short warning/heartbeat audio played once on first appearance (with safe cleanup & silent-mode tolerance).
/// - Clear distinction between existing company and newly detected company.
/// - Neutral, objective duplicate detection phrasing ("Contact Already Exists").
/// - Actions: "View Contact", "Add New Company", and "Cancel".
class CompanyConflictWarningDialog extends StatefulWidget {
  final ScannedContactModel incoming;
  final ScannedContactModel existing;

  const CompanyConflictWarningDialog({
    super.key,
    required this.incoming,
    required this.existing,
  });

  /// Displays the dialog and returns the chosen [CompanyConflictAction].
  static Future<CompanyConflictAction> show({
    required BuildContext context,
    required ScannedContactModel incoming,
    required ScannedContactModel existing,
  }) async {
    final result = await showDialog<CompanyConflictAction>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (ctx) => CompanyConflictWarningDialog(
        incoming: incoming,
        existing: existing,
      ),
    );
    return result ?? CompanyConflictAction.cancel;
  }

  @override
  State<CompanyConflictWarningDialog> createState() =>
      _CompanyConflictWarningDialogState();
}

class _CompanyConflictWarningDialogState
    extends State<CompanyConflictWarningDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeatController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  AudioPlayer? _audioPlayer;
  bool _audioPlayed = false;

  @override
  void initState() {
    super.initState();

    // 1. Tactile haptic pulse
    HapticFeedback.heavyImpact();

    // 2. Heartbeat Animation Controller (1400ms cycle)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Two-step cardiac heartbeat pattern:
    // Normal -> small pulse (lub) -> normal -> stronger pulse (dub) -> normal -> pause -> repeat
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

    // Synchronized red glow pulse
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.25, end: 0.65)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.65, end: 0.35)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.35, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 0.25)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.25),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    _heartbeatController.repeat();

    // 3. Play warning sound ONCE on first display
    _playWarningSoundOnce();
  }

  Future<void> _playWarningSoundOnce() async {
    if (_audioPlayed) return;
    _audioPlayed = true;

    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setVolume(1.0);
      await _audioPlayer!.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer!.play(AssetSource('audio/heartbeat_warning.wav'));
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _onViewContact() {
    Navigator.of(context).pop(CompanyConflictAction.viewContact);
  }

  void _onAddNewCompany() {
    Navigator.of(context).pop(CompanyConflictAction.addNewCompany);
  }

  void _onCancel() {
    Navigator.of(context).pop(CompanyConflictAction.cancel);
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFDC2626); // Strong security red
    const brightRed = Color(0xFFEF4444);
    const darkBoxBg = Color(0xFF141419); // Rich dark rectangular container
    const cardSectionBg = Color(0xFF1C1C24); // Elevated inner card background

    final existingCompany = widget.existing.company.trim().isNotEmpty
        ? widget.existing.company.trim()
        : 'Unknown Company';
    final newCompany = widget.incoming.company.trim().isNotEmpty
        ? widget.incoming.company.trim()
        : 'Unknown Company';
    final phone = widget.incoming.phone.trim().isNotEmpty
        ? widget.incoming.phone.trim()
        : widget.existing.phone.trim();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: AnimatedBuilder(
        animation: _heartbeatController,
        builder: (context, child) {
          final scale = _scaleAnimation.value;
          final glow = _glowAnimation.value;

          return Transform.scale(
            scale: scale,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: darkBoxBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: primaryRed.withValues(alpha: 0.70 + (0.30 * glow)),
                  width: 2.2,
                ),
                boxShadow: [
                  // Outer pulsating red glow halo
                  BoxShadow(
                    color: primaryRed.withValues(alpha: 0.15 + (0.30 * glow)),
                    blurRadius: 24 + (16 * glow),
                    spreadRadius: 2 + (4 * glow),
                    offset: const Offset(0, 4),
                  ),
                  // Deep background drop shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.85),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==========================================
                      // 1. WARNING ICON (Pulsing Shield / Warning)
                      // ==========================================
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: primaryRed.withValues(alpha: 0.15),
                          border: Border.all(
                            color: primaryRed.withValues(alpha: 0.40 + (0.40 * glow)),
                            width: 2.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withValues(alpha: 0.20 + (0.30 * glow)),
                              blurRadius: 16 + (8 * glow),
                              spreadRadius: 1 + (2 * glow),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            size: 38,
                            color: brightRed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // ==========================================
                      // 2. TITLE: "CONTACT ALREADY EXISTS"
                      // ==========================================
                      Text(
                        'Contact Already Exists',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ==========================================
                      // 3. SUPPORTING TEXT
                      // ==========================================
                      Text(
                        'An existing contact with this phone number was found.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // 4. PHONE NUMBER HIGHLIGHT CHIP
                      // ==========================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(
                          color: cardSectionBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              phone.isNotEmpty ? phone : 'Same phone detected',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ==========================================
                      // 5. COMPANY DETAILS COMPARISON
                      // ==========================================
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardSectionBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryRed.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Existing Record
                            _buildCompanyRow(
                              badge: 'EXISTING COMPANY',
                              badgeColor: primaryRed,
                              company: existingCompany,
                              contactName: widget.existing.name.trim(),
                              icon: Icons.domain_rounded,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(
                                height: 1,
                                thickness: 1,
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            // New Detected Record
                            _buildCompanyRow(
                              badge: 'NEW SCANNED COMPANY',
                              badgeColor: const Color(0xFF3B82F6),
                              company: newCompany,
                              contactName: widget.incoming.name.trim(),
                              icon: Icons.add_business_rounded,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Security prompt note
                      Text(
                        'Both company records can be kept independently.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==========================================
                      // 6. ACTION BUTTONS: View Contact | Add New Company | Cancel
                      // ==========================================
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Primary: View Existing Contact
                          SizedBox(
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _onViewContact,
                              icon: const Icon(Icons.person_outline_rounded, size: 18),
                              label: Text(
                                'View Contact',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Add New Company
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _onAddNewCompany,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Add New Company',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Secondary Action: Cancel
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              onPressed: _onCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.20),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
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
        },
      ),
    );
  }

  Widget _buildCompanyRow({
    required String badge,
    required Color badgeColor,
    required String company,
    required String contactName,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.45),
                  width: 1,
                ),
              ),
              child: Text(
                badge,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: badgeColor,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: Colors.white70),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (contactName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Contact: $contactName',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

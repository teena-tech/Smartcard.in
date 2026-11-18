import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../models/card_duplicate_check.dart';
import '../../models/scanned_contact_model.dart';
import '../../models/scam_alert_action.dart';

export '../../models/scam_alert_action.dart';
export 'company_conflict_warning_dialog.dart';

/// Reusable production-ready dialog for duplicate card detection & scam alerts.
///
/// Features:
/// - Case A: Exact duplicate / same company -> "SCAM ALERT" with View Existing Contact & Cancel.
/// - Case B: Same phone number but different company -> "EXISTING NUMBER FOUND" with Save as Another Card, Merge Contact, & Cancel.
/// - Authentic cardiac heartbeat animation (1.0 -> 1.08 -> 1.0 -> 1.05 -> 1.0).
/// - Pulsing red glow halo on warning icon and subtle dialog shadow.
/// - Fully responsive across dark/light themes.
class ScamAlertDialog extends StatefulWidget {
  final CardDuplicateCheck check;
  final ScannedContactModel incoming;

  const ScamAlertDialog({
    super.key,
    required this.check,
    required this.incoming,
  });

  /// Displays the [ScamAlertDialog] and returns the chosen [ScamAlertAction].
  static Future<ScamAlertAction> show({
    required BuildContext context,
    required CardDuplicateCheck check,
    required ScannedContactModel incoming,
  }) async {

    final result = await showDialog<ScamAlertAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ScamAlertDialog(
        check: check,
        incoming: incoming,
      ),
    );
    return result ?? ScamAlertAction.cancel;
  }

  @override
  State<ScamAlertDialog> createState() => _ScamAlertDialogState();
}

class _ScamAlertDialogState extends State<ScamAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartbeatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Tactile warning feedback on alert appearance
    HapticFeedback.heavyImpact();

    // 1300ms heartbeat cycle (within 1200ms - 1500ms specification)
    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Heartbeat scale: 1.0 -> 1.08 -> 1.0 -> 1.05 -> 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.08, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 12,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40, // Resting diastole interval
      ),
    ]).animate(_heartbeatController);

    // Subtle red glow pulsation: normal -> stronger -> normal
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 0.8)
            .chain(CurveTween(curve: Curves.easeOutQuad)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 0.2)
            .chain(CurveTween(curve: Curves.easeInQuad)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.2),
        weight: 40,
      ),
    ]).animate(_heartbeatController);

    _heartbeatController.repeat();
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCaseA = widget.check.isExact;
    final existing = widget.check.existingContact;

    // Theme adaptive colors while maintaining strict red warning aesthetic
    final dialogBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final cardBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB);
    final cardBorder = isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB);

    const primaryRed = Color(0xFFDC2626); // Strong vibrant warning red
    const darkRed = Color(0xFFB91C1C);

    return AnimatedBuilder(
      animation: _heartbeatController,
      builder: (context, child) {
        final glow = _glowAnimation.value;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: primaryRed,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withValues(alpha: 0.08 + (0.12 * glow)),
                  blurRadius: 20 + (8 * glow),
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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
                    // 1. ANIMATED HEARTBEAT WARNING ICON
                    // ==========================================
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryRed.withValues(alpha: 0.20 + (0.30 * glow)),
                              blurRadius: 16 + (10 * glow),
                              spreadRadius: 2 + (2 * glow),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Lottie.asset(
                            'assets/lottie/warning.json',
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                            repeat: true,
                            animate: true,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 2. ALERT TITLE
                    // ==========================================
                    if (isCaseA) ...[
                      Text(
                        'Contact Exist',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: primaryRed,
                        ),
                      ),
                    ] else ...[
                      Text(
                        'EXISTING NUMBER FOUND',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.redAccent.shade100 : darkRed,
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // ==========================================
                    // 3. ALERT MESSAGE
                    // ==========================================
                    Text(
                      isCaseA
                          ? 'This card has already been scanned and appears to match an existing contact. Please verify the details before saving it again.'
                          : 'This phone number already exists with another contact, but this card contains different company details.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                        color: secondaryTextColor,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ==========================================
                    // 4. CONTACT VERIFICATION PREVIEW CARD
                    // ==========================================
                    if (existing != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.account_box_outlined,
                                  size: 16,
                                  color: primaryRed.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isCaseA ? 'EXISTING SAVED CARD' : 'EXISTING RECORD',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: primaryRed,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              label: 'Name:',
                              value: existing.name.trim().isNotEmpty
                                  ? existing.name
                                  : 'No name recorded',
                              bold: true,
                              textColor: primaryTextColor,
                            ),
                            const SizedBox(height: 4),
                            _buildDetailRow(
                              label: 'Phone:',
                              value: existing.phone.trim().isNotEmpty
                                  ? existing.phone
                                  : 'Not specified',
                              bold: true,
                              textColor: primaryTextColor,
                            ),
                            if (existing.company.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _buildDetailRow(
                                label: 'Company:',
                                value: existing.company,
                                bold: true,
                                textColor: primaryTextColor,
                              ),
                            ],
                            if (!isCaseA && widget.incoming.company.trim().isNotEmpty) ...[
                              const Divider(height: 16, thickness: 1),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.fiber_new_rounded,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'SCANNED CARD COMPANY',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              _buildDetailRow(
                                label: 'New Card:',
                                value: widget.incoming.company,
                                bold: true,
                                textColor: primaryTextColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // ==========================================
                    // 5. ACTION BUTTONS
                    // ==========================================
                    if (isCaseA) ...[
                      // CASE A: SAME CARD / SAME CONTACT
                      // Primary Button: "View Existing Contact"
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(ScamAlertAction.viewExisting);
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text(
                            'View Existing Contact',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Secondary Button: "Cancel"
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop(ScamAlertAction.cancel);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: secondaryTextColor,
                            side: BorderSide(color: cardBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // CASE B: SAME PHONE NUMBER BUT DIFFERENT COMPANY
                      // Primary Button: "Save as Another Card"
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(ScamAlertAction.saveAsAnotherCard);
                          },
                          icon: const Icon(Icons.credit_card_rounded, size: 18),
                          label: Text(
                            'Save as Another Card',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Secondary Button: "Merge Contact"
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop(ScamAlertAction.mergeContact);
                          },
                          icon: const Icon(Icons.merge_type_rounded, size: 18),
                          label: Text(
                            'Merge Contact',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1F2937),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark ? Colors.white38 : const Color(0xFFD1D5DB),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Text Button: "Cancel"
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(ScamAlertAction.cancel);
                          },
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    required bool bold,
    required Color textColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}

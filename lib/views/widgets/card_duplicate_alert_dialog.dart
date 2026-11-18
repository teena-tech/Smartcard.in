import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../models/card_duplicate_check.dart';
import '../../models/scanned_contact_model.dart';
import 'scam_alert_dialog.dart';

enum CardDuplicateAction {
  viewExisting,
  merge,
  keepSeparate,
  cancel,
}

class CardDuplicateAlertDialog extends StatefulWidget {
  final CardDuplicateCheck check;
  final ScannedContactModel incoming;

  const CardDuplicateAlertDialog({
    super.key,
    required this.check,
    required this.incoming,
  });

  /// Show the dialog directly and return the selected user action
  static Future<CardDuplicateAction> show({
    required BuildContext context,
    required CardDuplicateCheck check,
    required ScannedContactModel incoming,
  }) async {
    final scamAction = await ScamAlertDialog.show(
      context: context,
      check: check,
      incoming: incoming,
    );
    switch (scamAction) {
      case ScamAlertAction.viewExisting:
        return CardDuplicateAction.viewExisting;
      case ScamAlertAction.mergeContact:
        return CardDuplicateAction.merge;
      case ScamAlertAction.saveAsAnotherCard:
        return CardDuplicateAction.keepSeparate;
      case ScamAlertAction.cancel:
        return CardDuplicateAction.cancel;
    }
  }

  @override
  State<CardDuplicateAlertDialog> createState() => _CardDuplicateAlertDialogState();
}

class _CardDuplicateAlertDialogState extends State<CardDuplicateAlertDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartbeatController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    // Haptic warning feedback when alert opens
    HapticFeedback.heavyImpact();

    _heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();

    // Heartbeat double-contraction rhythm
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.22)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.22, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.14)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.14, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40, // Rest between beats
      ),
    ]).animate(_heartbeatController);

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 0.7), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.7, end: 0.2), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.2, end: 0.5), weight: 15),
      TweenSequenceItem(tween: Tween<double>(begin: 0.5, end: 0.1), weight: 15),
      TweenSequenceItem(tween: ConstantTween<double>(0.1), weight: 40),
    ]).animate(_heartbeatController);
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.check.existingContact;
    final isExact = widget.check.isExact;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: isExact
                ? _buildExactDuplicateContent(existing)
                : _buildSameNumberDifferentCardContent(existing),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. EXACT DUPLICATE CONTENT (Heartbeat Warning Scam-Alert UI)
  // -------------------------------------------------------------
  Widget _buildExactDuplicateContent(ScannedContactModel? existing) {
    const crimsonColor = Color(0xFFDC2626);
    final cardName = (existing?.name.trim().isNotEmpty ?? false)
        ? existing!.name.trim()
        : widget.incoming.name.trim().isNotEmpty
            ? widget.incoming.name.trim()
            : 'Registered Card';
    final cardPhone = existing?.phone.trim().isNotEmpty == true
        ? existing!.phone.trim()
        : widget.incoming.phone.trim();
    final cardCompany = existing?.company.trim().isNotEmpty == true
        ? existing!.company.trim()
        : widget.incoming.company.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Pulsing Heartbeat Warning Shield
        AnimatedBuilder(
          animation: _heartbeatController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glowing heartbeat pulse halo
                Container(
                  width: 82 * _scaleAnimation.value,
                  height: 82 * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: crimsonColor.withValues(alpha: _glowAnimation.value * 0.35),
                  ),
                ),
                // Inner badge
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: crimsonColor.withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),

        // Bold "Already Exists" Alert Title
        Text(
          'Already Exists',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: crimsonColor,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),

        Text(
          'This exact card is already registered in your database.',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),

        // Card Details with BOLD Highlighted Fields
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crimsonColor.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EXISTING CARD',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: crimsonColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // BOLD Card Name
                        Text(
                          cardName,
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // BOLD Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: crimsonColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ALREADY SAVED',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: crimsonColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (cardCompany.isNotEmpty) ...[
                const SizedBox(height: 8),
                _boldInfoRow(Icons.business_rounded, 'Company:', cardCompany),
              ],
              if (cardPhone.isNotEmpty) ...[
                const SizedBox(height: 6),
                _boldInfoRow(Icons.phone_rounded, 'Card Number / Phone:', cardPhone),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Bold Safety Guarantee
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Duplicate entry prevented. No redundant card will be created.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, CardDuplicateAction.cancel),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Text(
                  'Dismiss',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, CardDuplicateAction.viewExisting),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crimsonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'View Card',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 2. SAME NUMBER, DIFFERENT CARD CONTENT (Merge UI)
  // -------------------------------------------------------------
  Widget _buildSameNumberDifferentCardContent(ScannedContactModel? existing) {
    final matchedNumber = widget.incoming.phone.isNotEmpty
        ? widget.incoming.phone
        : (existing?.phone ?? '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Warning Icon
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFFBEB),
            border: Border.all(color: const Color(0xFFF59E0B), width: 2),
          ),
          child: const Icon(
            Icons.call_split_rounded,
            color: Color(0xFFD97706),
            size: 32,
          ),
        ),
        const SizedBox(height: 16),

        // Warning Title
        Text(
          'Another card is using this number',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFB45309),
            letterSpacing: -0.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),

        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
            children: [
              const TextSpan(text: 'The number '),
              TextSpan(
                text: matchedNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const TextSpan(text: ' is already registered, but this scanned card belongs to a different record.'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card Comparison Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Existing Card (Master)
              _comparisonRow(
                badgeText: 'MASTER RECORD',
                badgeColor: const Color(0xFF0284C7),
                name: existing?.name ?? 'Existing Contact',
                company: existing?.company,
                phone: existing?.phone,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Divider(height: 1),
              ),
              // Newly Scanned Card
              _comparisonRow(
                badgeText: 'NEW SCAN',
                badgeColor: const Color(0xFF10B981),
                name: widget.incoming.name.isNotEmpty ? widget.incoming.name : 'Newly Scanned Card',
                company: widget.incoming.company,
                phone: widget.incoming.phone,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Merge explanation
        Text(
          'Select Merge to safely combine all contact details into one master card without losing data.',
          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Actions: Merge / Keep Separate / Cancel
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmAndMerge(context, existing),
                icon: const Icon(Icons.merge_type_rounded, size: 18),
                label: Text(
                  'Merge with Existing Card',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, CardDuplicateAction.cancel),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    ),
                  ),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, CardDuplicateAction.keepSeparate),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Keep Separate',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Explicit Confirmation Dialog before Merging
  Future<void> _confirmAndMerge(BuildContext context, ScannedContactModel? existing) async {
    final masterName = existing?.name.trim().isNotEmpty == true ? existing!.name : 'Master Card';
    final incomingName = widget.incoming.name.trim().isNotEmpty ? widget.incoming.name : 'Scanned Card';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Card Merge',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to merge "$incomingName" into "$masterName"?\n\nAll phone numbers, emails, company info, and notes will be preserved in the master card.',
          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Merge Cards'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, CardDuplicateAction.merge);
    }
  }

  Widget _boldInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFDC2626)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _comparisonRow({
    required String badgeText,
    required Color badgeColor,
    required String name,
    String? company,
    String? phone,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: badgeColor,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              if (company != null && company.trim().isNotEmpty)
                Text(
                  company,
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                ),
              if (phone != null && phone.trim().isNotEmpty)
                Text(
                  phone,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

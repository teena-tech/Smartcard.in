import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/workspace_notifier.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smartcard_flutter/core/utils/app_haptics.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/features/profile_screen/data/models/user_model.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/data/models/card_model.dart';
import 'package:smartcard_flutter/core/di/workspace_notifier.dart';
import 'package:smartcard_flutter/features/login_screen/presentation/viewmodel/auth_viewmodel.dart';
import 'package:smartcard_flutter/features/smart_card_list_screen/presentation/viewmodel/card_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';

/// Digital Corporate Card presentation widget with QR code and locked brand elements enforcement
class DigitalCorporateCardWidget extends ConsumerStatefulWidget {
  final CardModel? card;
  final UserModel? user;
  final bool showLockDetails;

  const DigitalCorporateCardWidget({
    super.key,
    this.card,
    this.user,
    this.showLockDetails = true,
  });

  @override
  ConsumerState<DigitalCorporateCardWidget> createState() => _DigitalCorporateCardWidgetState();
}

class _DigitalCorporateCardWidgetState extends ConsumerState<DigitalCorporateCardWidget> {
  bool _isBackFlipped = false;

  void _showLockedBrandDialog(BuildContext context, WorkspaceState ws) {
    AppHaptics.selection();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.lock_rounded, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Organization Brand Guard',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The following organization assets are locked as Read-Only by your Organization Admin to preserve brand consistency:',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 14),
            _buildLockRow(Icons.image_outlined, 'Organization Logo', 'Locked & Verified'),
            _buildLockRow(Icons.apartment_rounded, 'Organization', ws.companyName),
            _buildLockRow(Icons.palette_outlined, 'Brand Palette', '#0284C7 (Organization Ocean)'),
            _buildLockRow(Icons.gavel_rounded, 'Legal Disclaimer', 'Centrally Enforced'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_rounded, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Employees cannot modify organization brand assets. Contact your Organization Administrator for changes.',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFBAE6FD)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }

  Widget _buildLockRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.lock_outline, size: 13, color: Colors.amberAccent),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workspaceProvider);
    final authVm = ref.watch(authViewModelProvider);
    final profileVm = ref.watch(profileViewModelProvider);
    final cardVm = ref.watch(cardViewModelProvider);

    final user = widget.user ?? profileVm.user ?? authVm.currentUser;
    final card = widget.card ?? cardVm.primaryCard ?? (cardVm.cards.isNotEmpty ? cardVm.cards.first : null);

    final displayName = user?.displayName.isNotEmpty == true
        ? user!.displayName
        : (card?.name.isNotEmpty == true ? card!.name : 'Employee Profile');
    final role = user?.profession?.isNotEmpty == true
        ? user!.profession!
        : (card?.designation?.isNotEmpty == true ? card!.designation! : 'Solutions Specialist');
    final phone = user?.phone?.isNotEmpty == true ? user!.phone! : (card?.phone ?? '');
    final email = user?.email?.isNotEmpty == true ? user!.email! : (card?.email ?? '');
    final memberId = user?.memberId?.isNotEmpty == true ? user!.memberId! : 'SC-1092';
    final qrUrl = card?.qrData.isNotEmpty == true
        ? card!.qrData
        : 'https://thesmartcards.in/profile/${user?.id ?? "employee"}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Card Presentation Container ─────────────────────────
        GestureDetector(
          onTap: () {
            AppHaptics.light();
            setState(() => _isBackFlipped = !_isBackFlipped);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isBackFlipped
                    ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                    : const [Color(0xFF091426), Color(0xFF0C2444), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _isBackFlipped
                ? _buildBackFace(displayName, role, phone, email, ws, qrUrl)
                : _buildFrontFace(displayName, role, phone, email, memberId, ws, qrUrl),
          ),
        ),

        // ── Locked Brand Elements Notice ────────────────────────
        if (widget.showLockDetails) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showLockedBrandDialog(context, ws),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1729),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Organization Brand Elements',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF7DD3FC),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, color: Colors.amberAccent, size: 12),
                          ],
                        ),
                        Text(
                          'Organization Name, Logo, & Theme Color enforced by Admin',
                          style: GoogleFonts.inter(
                            fontSize: 9.5,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFrontFace(
    String name,
    String role,
    String phone,
    String email,
    String memberId,
    WorkspaceState ws,
    String qrUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Company Header with Locked Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ws.companyName.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          'OFFICIAL ORGANIZATION IDENTITY',
                          style: GoogleFonts.inter(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF7DD3FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 10, color: Colors.amberAccent),
                  const SizedBox(width: 3),
                  Text(
                    'BRAND LOCKED',
                    style: GoogleFonts.inter(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Middle Row: Employee Details + Dynamic QR Code
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFBAE6FD),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ID: $memberId',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Dynamic QR Code Container
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6),
                ],
              ),
              child: QrImageView(
                data: qrUrl,
                version: QrVersions.auto,
                size: 58,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 10),

        // Bottom Contact Strip & Flip Hint
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (phone.isNotEmpty) ...[
                  const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                  ),
                  const SizedBox(width: 10),
                ],
                if (email.isNotEmpty) ...[
                  const Icon(Icons.email_rounded, size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 4),
                  Text(
                    email,
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white70),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                const Icon(Icons.sync_rounded, size: 12, color: Color(0xFF7DD3FC)),
                const SizedBox(width: 3),
                Text(
                  'Tap to Flip',
                  style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF7DD3FC), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackFace(
    String name,
    String role,
    String phone,
    String email,
    WorkspaceState ws,
    String qrUrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHANNELS & CONNECT',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: const Color(0xFF38BDF8),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.sync_rounded, size: 12, color: Colors.white60),
                const SizedBox(width: 3),
                Text(
                  'Flip Front',
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          ws.corporateDisclaimer,
          style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white70, height: 1.3),
        ),
        const SizedBox(height: 14),

        // Quick Action Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            if (phone.isNotEmpty)
              _buildBackAction(Icons.phone, 'Call', () => IntentLauncher.makePhoneCall(context, phone)),
            if (email.isNotEmpty)
              _buildBackAction(Icons.email, 'Email', () => IntentLauncher.sendEmail(context, email)),
            _buildBackAction(Icons.qr_code, 'QR View', () {}),
            _buildBackAction(Icons.public, 'Website', () => IntentLauncher.openWebsite(context, 'https://abctech.com')),
          ],
        ),
      ],
    );
  }

  Widget _buildBackAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

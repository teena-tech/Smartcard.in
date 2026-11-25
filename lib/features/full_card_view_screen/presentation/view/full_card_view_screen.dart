import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/services/contact_saver_service.dart';
import 'package:smartcard_flutter/core/utils/contact_action_helper.dart';
import 'package:smartcard_flutter/core/utils/intent_launcher.dart';
import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/widgets/global_bottom_nav.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';
import 'package:smartcard_flutter/features/full_card_view_screen/presentation/view/widgets/rotating_profile_avatar_ring.dart';

class FullCardViewScreen extends StatefulWidget {
  final ContactModel contact;
  final ScannedContactModel scannedContact;

  const FullCardViewScreen({
    super.key,
    required this.contact,
    required this.scannedContact,
  });

  @override
  State<FullCardViewScreen> createState() => _FullCardViewScreenState();
}

class _FullCardViewScreenState extends State<FullCardViewScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _saveContactToDevice() async {
    setState(() {
      _saving = true;
    });
    try {
      final hasPermission = await ContactSaverService.requestContactsPermission();
      if (hasPermission) {
        final saved = await ContactSaverService.saveToDevice(widget.scannedContact);
        if (saved != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact saved to your phone successfully!'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pop(true);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save contact. Please try again.'), backgroundColor: Colors.redAccent),
          );
        }
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission denied to save contacts.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameInitials = widget.contact.name.isNotEmpty 
        ? widget.contact.name.substring(0, 1).toUpperCase() 
        : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: const MasterAppBar(
        titleText: 'Business Profile',
        style: MasterHeaderStyle.transparent,
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Stack(
        children: [
          // Premium Gradient background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F0F1A), Color(0xFF1E1E3F)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                image: (widget.contact.backgroundImage != null && widget.contact.backgroundImage!.trim().isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(
                          UploadUrlResolver.resolve(widget.contact.backgroundImage!.trim(), type: 'card-bg'),
                        ),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.1),
                          BlendMode.darken,
                        ),
                      )
                    : null,
              ),
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Photo Block with Rotating Ring
                  Center(
                    child: RotatingProfileAvatarRing(
                      size: 100,
                      borderWidth: 4.0,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF1F1F35),
                        backgroundImage: (widget.scannedContact.imagePath != null && widget.scannedContact.imagePath!.trim().isNotEmpty)
                            ? NetworkImage(
                                UploadUrlResolver.resolve(widget.scannedContact.imagePath!.trim(), type: 'profile'),
                              )
                            : (widget.contact.profileImageName != null && widget.contact.profileImageName!.trim().isNotEmpty)
                                ? NetworkImage(
                                    UploadUrlResolver.resolve(widget.contact.profileImageName!.trim(), type: 'profile'),
                                  )
                                : null,
                        child: ((widget.scannedContact.imagePath != null && widget.scannedContact.imagePath!.trim().isNotEmpty) ||
                                (widget.contact.profileImageName != null && widget.contact.profileImageName!.trim().isNotEmpty))
                            ? null
                            : Text(
                                nameInitials,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Name and job designation details
                  Center(
                    child: Text(
                      widget.contact.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.contact.designation.isNotEmpty)
                    Center(
                      child: Text(
                        widget.contact.designation.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (widget.contact.companyLogo != null && widget.contact.companyLogo!.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Center(
                        child: Image.network(
                          UploadUrlResolver.resolve(widget.contact.companyLogo!.trim(), type: 'logo'),
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (widget.contact.companyName.isNotEmpty)
                    Center(
                      child: Text(
                        widget.contact.companyName,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Action Button - Contact Save Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveContactToDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.05),
                      ),
                      icon: _saving 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(
                        _saving ? 'SAVING...' : 'SAVE CONTACT TO PHONE',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Contact Details Card
                  _buildSectionHeader('Contact Information'),
                  _buildDetailRow(
                    Icons.phone_outlined,
                    'Phone',
                    widget.contact.phone?.isNotEmpty == true ? widget.contact.phone! : 'Not provided',
                    onTap: widget.contact.phone?.isNotEmpty == true
                        ? () => ContactActionHelper.handleCall(context, contact: widget.scannedContact, contactName: widget.contact.name)
                        : null,
                  ),
                  _buildDetailRow(
                    Icons.email_outlined,
                    'Email',
                    widget.contact.email?.isNotEmpty == true ? widget.contact.email! : 'Not provided',
                    onTap: widget.contact.email?.isNotEmpty == true
                        ? () => ContactActionHelper.handleEmail(context, contact: widget.scannedContact, contactName: widget.contact.name)
                        : null,
                  ),
                  _buildDetailRow(
                    Icons.language_outlined,
                    'Website',
                    widget.contact.website?.isNotEmpty == true ? widget.contact.website! : 'Not provided',
                    onTap: widget.contact.website?.isNotEmpty == true
                        ? () => ContactActionHelper.handleWebsite(context, contact: widget.scannedContact, contactName: widget.contact.name)
                        : null,
                  ),
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Office Location',
                    widget.contact.address?.isNotEmpty == true ? widget.contact.address! : 'Not provided',
                    onTap: widget.contact.address?.isNotEmpty == true
                        ? () => IntentLauncher.openMap(context, widget.contact.address!)
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // Social Media section
                  _buildSectionHeader('Social Networks'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSocialIconButton(Icons.facebook, 'Facebook'),
                      _buildSocialIconButton(Icons.camera_alt, 'Instagram'),
                      _buildSocialIconButton(Icons.work_outline, 'LinkedIn'),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.redAccent, size: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              if (onTap != null && value != 'Not provided')
                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIconButton(IconData icon, String label) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening $label...')),
          );
        },
      ),
    );
  }
}

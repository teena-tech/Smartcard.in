import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/scanned_contact_model.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/contact_viewmodel.dart';
import 'home_screen.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/common_drawer.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../../core/utils/responsive.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactDetailScreen extends StatelessWidget {
  final ScannedContactModel contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final profileInitial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final locationText = [contact.district, contact.stateName, contact.pinCode]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      drawer: const CommonDrawer(
        backTitle: 'Back to Contacts',
      ),
      appBar: CommonAppBar(
        titleText: 'CONTACT DETAILS',
        showBackButton: true,
        onBackTap: () => Navigator.pop(context),
        onProfileTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
            (route) => false,
          );
        },
      ),
      bottomNavigationBar: const GlobalBottomNav(),

      body: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Circular Avatar Container
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: contact.profileImage != null && contact.profileImage!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(52),
                        child: Image.network(contact.profileImage!, width: 104, height: 104, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildAvatarInitial(profileInitial)),
                      )
                    : _buildAvatarInitial(profileInitial),
              ),

              const SizedBox(height: 20),

              // Name, Designation, Company
              Text(
                contact.name.isNotEmpty ? contact.name : '-',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (contact.designation.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contact.designation,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                contact.company.isNotEmpty ? contact.company : 'Unknown Company',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: colors.text.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 28),

              // Action Buttons (Call, WhatsApp, Text, Email)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icon(Icons.phone, color: Colors.red, size: 24),
                    label: 'Call',
                    color: const Color(0xFFFFE5E5),
                    iconColor: Colors.red,
                    onTap: () async {
                      if (contact.phone.isNotEmpty) {
                        final uri = Uri.parse('tel:${contact.phone}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      }
                    },
                  ),
                  _ActionButton(
                    icon: FaIcon(FontAwesomeIcons.whatsapp, color: const Color(0xFF25D366), size: 24),
                    label: 'WhatsApp',
                    color: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF25D366),
                    onTap: () async {
                      if (contact.phone.isNotEmpty) {
                        final cleanPhone = contact.phone.replaceAll(RegExp(r'[^\d]'), '');
                        final waUrl = Uri.parse('https://wa.me/$cleanPhone');
                        if (await canLaunchUrl(waUrl)) {
                          await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  ),
                  _ActionButton(
                    icon: Icon(Icons.message, color: const Color(0xFF0284C7), size: 24),
                    label: 'Text',
                    color: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    onTap: () async {
                      if (contact.phone.isNotEmpty) {
                        final uri = Uri.parse('sms:${contact.phone}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      }
                    },
                  ),
                  _ActionButton(
                    icon: Icon(Icons.email, color: const Color(0xFFD97706), size: 24),
                    label: 'Email',
                    color: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: () async {
                      if (contact.email.isNotEmpty) {
                        final uri = Uri.parse('mailto:${contact.email}');
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Phone Field Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colors.panel.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.phone, color: colors.text, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone',
                            style: GoogleFonts.inter(
                              color: colors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact.phone.isNotEmpty ? contact.phone : '-',
                            style: GoogleFonts.inter(
                              color: colors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.muted, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Address Field Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: colors.panel.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.location_on, color: colors.text, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Address',
                            style: GoogleFonts.inter(
                              color: colors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact.address.isNotEmpty
                                ? contact.address
                                : (locationText.isNotEmpty ? locationText : '-'),
                            style: GoogleFonts.inter(
                              color: colors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Prominent Red Delete Contact Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _confirmDelete(context),
                  child: Text(
                    'Delete Contact',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),

    );
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: 'Delete Contact',
      message: 'Are you sure you want to delete this contact? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
    );
    
    if (confirmed == true && context.mounted) {
      context.read<ContactViewModel>().deleteContact(contact.id);
      Navigator.pop(context);
    }
  }

  Widget _buildAvatarInitial(String initial) {
    return Text(
      initial,
      style: GoogleFonts.inter(
        color: Colors.red,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.inter(
            color: iconColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


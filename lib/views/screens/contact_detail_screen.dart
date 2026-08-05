import 'dart:io';
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
import '../../core/utils/upload_url_resolver.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactDetailScreen extends StatelessWidget {
  final ScannedContactModel contact;

  const ContactDetailScreen({super.key, required this.contact});

  List<String> _extractItems(List<String?> rawInputs) {
    final Set<String> result = {};
    for (final raw in rawInputs) {
      if (raw == null || raw.trim().isEmpty) continue;
      final lines = raw.split(RegExp(r'[\n/,;]'));
      for (final line in lines) {
        final cleaned = line.trim();
        if (cleaned.isNotEmpty) {
          result.add(cleaned);
        }
      }
    }
    return result.toList();
  }

  void _showOptionsPopup(
    BuildContext context, {
    required String title,
    required dynamic icon,
    required Color iconColor,
    required List<String> options,
    required Function(String selected) onSelect,
  }) {
    Widget buildIconWidget(double size) {
      if (icon is IconData) {
        return Icon(icon, color: iconColor, size: size);
      }
      return FaIcon(icon, color: iconColor, size: size);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1E3F),
        title: Row(
          children: [
            buildIconWidget(24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: ListTile(
                  leading: buildIconWidget(20),
                  title: Text(
                    opt,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 14),
                  onTap: () {
                    Navigator.pop(ctx);
                    onSelect(opt);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _handleCall(BuildContext context) async {
    final phones = _extractItems([contact.phone, contact.alternativePhone, contact.landline, contact.whatsApp]);
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
      return;
    }
    if (phones.length == 1) {
      final uri = Uri.parse('tel:${phones.first}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      _showOptionsPopup(
        context,
        title: 'Select Phone Number to Call',
        icon: Icons.phone,
        iconColor: Colors.red,
        options: phones,
        onSelect: (number) async {
          final uri = Uri.parse('tel:$number');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      );
    }
  }

  void _handleWhatsApp(BuildContext context) async {
    final waNumbers = _extractItems([contact.whatsApp, contact.phone, contact.alternativePhone]);
    if (waNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No WhatsApp number available')));
      return;
    }
    if (waNumbers.length == 1) {
      final clean = waNumbers.first.replaceAll(RegExp(r'[^\d]'), '');
      final waUrl = Uri.parse('https://wa.me/$clean');
      if (await canLaunchUrl(waUrl)) await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } else {
      _showOptionsPopup(
        context,
        title: 'Select WhatsApp Number',
        icon: FontAwesomeIcons.whatsapp,
        iconColor: const Color(0xFF25D366),
        options: waNumbers,
        onSelect: (number) async {
          final clean = number.replaceAll(RegExp(r'[^\d]'), '');
          final waUrl = Uri.parse('https://wa.me/$clean');
          if (await canLaunchUrl(waUrl)) await launchUrl(waUrl, mode: LaunchMode.externalApplication);
        },
      );
    }
  }

  void _handleSms(BuildContext context) async {
    final phones = _extractItems([contact.phone, contact.alternativePhone, contact.landline, contact.whatsApp]);
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
      return;
    }
    if (phones.length == 1) {
      final uri = Uri.parse('sms:${phones.first}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      _showOptionsPopup(
        context,
        title: 'Select Phone Number for SMS',
        icon: Icons.message,
        iconColor: const Color(0xFF0284C7),
        options: phones,
        onSelect: (number) async {
          final uri = Uri.parse('sms:$number');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      );
    }
  }

  void _handleEmail(BuildContext context) async {
    final emails = _extractItems([contact.email]);
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No email address available')));
      return;
    }
    if (emails.length == 1) {
      final uri = Uri.parse('mailto:${emails.first}');
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    } else {
      _showOptionsPopup(
        context,
        title: 'Select Email Address',
        icon: Icons.email,
        iconColor: const Color(0xFFD97706),
        options: emails,
        onSelect: (email) async {
          final uri = Uri.parse('mailto:$email');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final profileInitial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';
    final locationText = [contact.district, contact.stateName, contact.pinCode]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    final String? rawImage = (contact.profileImage != null && contact.profileImage!.isNotEmpty)
        ? contact.profileImage!
        : ((contact.imagePath != null && contact.imagePath!.isNotEmpty) ? contact.imagePath! : null);

    final String? avatarSource = rawImage != null ? UploadUrlResolver.resolve(rawImage, type: 'profile') : null;

    Widget avatarWidget;
    if (avatarSource == null || avatarSource.trim().isEmpty) {
      avatarWidget = _buildAvatarInitial(profileInitial);
    } else if (avatarSource.startsWith('http://') || avatarSource.startsWith('https://')) {
      avatarWidget = ClipRRect(
        borderRadius: BorderRadius.circular(52),
        child: Image.network(
          avatarSource,
          width: 104,
          height: 104,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildAvatarInitial(profileInitial),
        ),
      );
    } else {
      final file = File(avatarSource);
      if (file.existsSync()) {
        avatarWidget = ClipRRect(
          borderRadius: BorderRadius.circular(52),
          child: Image.file(
            file,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildAvatarInitial(profileInitial),
          ),
        );
      } else {
        avatarWidget = _buildAvatarInitial(profileInitial);
      }
    }

    return Scaffold(
      backgroundColor: colors.backgroundStart,
      drawer: const CommonDrawer(
        backTitle: 'Back to Contacts',
      ),
      appBar: CommonAppBar(
        titleText: 'Contact Details',
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
                child: avatarWidget,
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
              if (contact.designation.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contact.designation.trim(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (contact.company.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  contact.company.trim(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: colors.text.withValues(alpha: 0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Action Buttons (Call, WhatsApp, Text, Email)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: const Icon(Icons.phone, color: Colors.red, size: 24),
                    label: 'Call',
                    color: const Color(0xFFFFE5E5),
                    iconColor: Colors.red,
                    onTap: () => _handleCall(context),
                  ),
                  _ActionButton(
                    icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 24),
                    label: 'WhatsApp',
                    color: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF25D366),
                    onTap: () => _handleWhatsApp(context),
                  ),
                  _ActionButton(
                    icon: const Icon(Icons.message, color: Color(0xFF0284C7), size: 24),
                    label: 'Text',
                    color: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    onTap: () => _handleSms(context),
                  ),
                  _ActionButton(
                    icon: const Icon(Icons.email, color: Color(0xFFD97706), size: 24),
                    label: 'Email',
                    color: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: () => _handleEmail(context),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Phone Field Card (Only shown if phone exists)
              if (contact.phone.trim().isNotEmpty) ...[
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
                              contact.phone.trim(),
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
              ],

              // Address Field Card (Only shown if address/location exists)
              if (contact.address.trim().isNotEmpty || locationText.trim().isNotEmpty) ...[
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
                              contact.address.trim().isNotEmpty
                                  ? contact.address.trim()
                                  : locationText.trim(),
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
                const SizedBox(height: 16),
              ],

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


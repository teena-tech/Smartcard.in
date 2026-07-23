import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/contact_saver_service.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/contact_viewmodel.dart';

import '../../viewmodels/profile_viewmodel.dart';
import '../widgets/delete_confirm_dialog.dart';

class ContactDetailsScreen extends StatefulWidget {
  final ScannedContactModel contact;

  const ContactDetailsScreen({super.key, required this.contact});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.contact.source != 'phone') {
        context.read<ProfileViewModel>().incrementCardViews(widget.contact.id);
      }
    });
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final vibrantRed = const Color(0xFFE30613);
    final darkBlue = const Color(0xFF1E233A);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: darkBlue),
        title: Text(
          'Contact Details',
          style: GoogleFonts.inter(color: darkBlue, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/trash.png',
              width: 24,
              height: 24,
              color: vibrantRed,
            ),
            onPressed: () async {
              final confirm = await showDeleteConfirmDialog(
                context: context,
                title: 'Delete Contact',
                message: 'Are you sure you want to delete this contact?',
              );
              
              if (confirm == true && context.mounted) {
                await context.read<ContactViewModel>().deleteContact(contact.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact deleted successfully')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: vibrantRed.withValues(alpha: 0.15),
                child: Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: GoogleFonts.inter(color: vibrantRed, fontSize: 36, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                contact.name,
                style: GoogleFonts.inter(color: darkBlue, fontSize: 24, fontWeight: FontWeight.w800),
              ),
              if (contact.designation.isNotEmpty)
                Text(
                  contact.designation,
                  style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 16),
                ),
              if (contact.company.isNotEmpty)
                Text(
                  contact.company,
                  style: GoogleFonts.inter(color: Colors.grey[800], fontSize: 16, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(Icons.call, 'Call', () => _launchUrl('tel:${contact.phone}'), vibrantRed),
                  _buildActionButton(Icons.message, 'Text', () => _launchUrl('sms:${contact.phone}'), Colors.blue),
                  _buildActionButton(Icons.email, 'Email', () => _launchUrl('mailto:${contact.email}'), Colors.orange),
                  if (contact.source != 'phone')
                    _buildActionButton(Icons.save_alt, 'Save', () async {
                      final success = await ContactSaverService.saveToDevice(contact);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Saved to Phone!' : 'Failed to save'),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ));
                    }, Colors.green),
                ],
              ),
              const SizedBox(height: 32),
              _buildInfoSection('Phone', contact.phone, Icons.phone, darkBlue, onTap: () => _launchUrl('tel:${contact.phone}')),
              if (contact.alternativePhone != null && contact.alternativePhone!.isNotEmpty)
                _buildInfoSection('Alternate', contact.alternativePhone!, Icons.phone_android, darkBlue, onTap: () => _launchUrl('tel:${contact.alternativePhone!}')),
              if (contact.email.isNotEmpty)
                _buildInfoSection('Email', contact.email, Icons.email, darkBlue, onTap: () => _launchUrl('mailto:${contact.email}')),
              if (contact.website.isNotEmpty)
                _buildInfoSection('Website', contact.website, Icons.language, darkBlue, onTap: () => _launchUrl(contact.website)),
              if (contact.address.isNotEmpty)
                _buildInfoSection('Address', contact.address, Icons.location_on, darkBlue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: onTap != null ? color.withValues(alpha: 0.15) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: onTap != null ? color.withValues(alpha: 0.15) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(value, style: GoogleFonts.inter(fontSize: 15, color: color, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.15), size: 20),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }
}

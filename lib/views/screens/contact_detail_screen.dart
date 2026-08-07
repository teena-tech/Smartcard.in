import 'dart:io';
import 'dart:convert';
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

class ContactDetailScreen extends StatefulWidget {
  final ScannedContactModel contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late ScannedContactModel _contact;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
  }

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
    final phones = _extractItems([_contact.phone, _contact.alternativePhone, _contact.landline, _contact.whatsApp]);
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
    final waNumbers = _extractItems([_contact.whatsApp, _contact.phone, _contact.alternativePhone]);
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
    final phones = _extractItems([_contact.phone, _contact.alternativePhone, _contact.landline, _contact.whatsApp]);
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
    final emails = _extractItems([_contact.email]);
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
    final allContacts = context.watch<ContactViewModel>().contacts;
    final updatedFromVm = allContacts.firstWhere(
      (c) => c.id == _contact.id || (c.phone.isNotEmpty && _contact.phone.isNotEmpty && c.phone == _contact.phone),
      orElse: () => _contact,
    );
    final currentContact = (updatedFromVm.profileImage?.isNotEmpty == true || updatedFromVm.imagePath?.isNotEmpty == true)
        ? updatedFromVm
        : _contact;
    final displayContact = currentContact;

    final profileInitial = currentContact.name.isNotEmpty ? currentContact.name[0].toUpperCase() : '?';
    final locationText = [currentContact.district, currentContact.stateName, currentContact.pinCode]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    final String? rawImage = (currentContact.profileImage != null && currentContact.profileImage!.isNotEmpty)
        ? currentContact.profileImage!
        : ((currentContact.imagePath != null && currentContact.imagePath!.isNotEmpty) ? currentContact.imagePath! : null);

    final String? avatarSource = rawImage != null ? UploadUrlResolver.resolve(rawImage, type: 'profile') : null;

    Widget avatarWidget;
    if (avatarSource == null || avatarSource.trim().isEmpty) {
      avatarWidget = _buildAvatarInitial(profileInitial);
    } else if (avatarSource.startsWith('data:image')) {
      try {
        final base64Bytes = base64Decode(avatarSource.split(',').last);
        avatarWidget = ClipRRect(
          borderRadius: BorderRadius.circular(52),
          child: Image.memory(
            base64Bytes,
            width: 104,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (c, e, s) => _buildAvatarInitial(profileInitial),
          ),
        );
      } catch (_) {
        avatarWidget = _buildAvatarInitial(profileInitial);
      }
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
                displayContact.name.isNotEmpty ? displayContact.name : '-',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (displayContact.designation.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  displayContact.designation.trim(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (displayContact.company.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  displayContact.company.trim(),
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

              // Phone Field Card
              if (displayContact.phone.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.phone,
                  label: 'Phone',
                  value: displayContact.phone.trim(),
                  onTap: () => _handleCall(context),
                ),

              // Alternative Phone
              if (displayContact.alternativePhone != null && displayContact.alternativePhone!.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.phone_android,
                  label: 'Alternative Phone',
                  value: displayContact.alternativePhone!.trim(),
                  onTap: () => _handleCall(context),
                ),

              // WhatsApp Number
              if (displayContact.whatsApp != null && displayContact.whatsApp!.trim().isNotEmpty && displayContact.whatsApp!.trim() != displayContact.phone.trim())
                _buildDetailCard(
                  colors: colors,
                  icon: FontAwesomeIcons.whatsapp,
                  label: 'WhatsApp',
                  value: displayContact.whatsApp!.trim(),
                  onTap: () => _handleWhatsApp(context),
                ),

              // Landline
              if (displayContact.landline != null && displayContact.landline!.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.phone_in_talk,
                  label: 'Landline',
                  value: displayContact.landline!.trim(),
                  onTap: () => _handleCall(context),
                ),

              // Email Field Card
              if (displayContact.email.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.email,
                  label: 'Email',
                  value: displayContact.email.trim(),
                  onTap: () => _handleEmail(context),
                ),

              // Website Field Card
              if (displayContact.website.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.language,
                  label: 'Website',
                  value: displayContact.website.trim(),
                  onTap: () async {
                    String url = displayContact.website.trim();
                    if (!url.startsWith('http://') && !url.startsWith('https://')) {
                      url = 'https://$url';
                    }
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),

              // Address & Location Field Card
              if (displayContact.address.trim().isNotEmpty || locationText.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.location_on,
                  label: 'Address',
                  value: displayContact.address.trim().isNotEmpty
                      ? displayContact.address.trim()
                      : locationText.trim(),
                ),

              // District / State / Pincode Card
              if (locationText.trim().isNotEmpty && locationText.trim() != displayContact.address.trim())
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.map,
                  label: 'Location (District / State / Pincode)',
                  value: locationText.trim(),
                ),

              // Gender Card
              if (displayContact.gender != null && displayContact.gender!.trim().isNotEmpty)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.person_outline,
                  label: 'Gender',
                  value: displayContact.gender!.trim(),
                ),

              // Contact Source / Type Card
              if (displayContact.contactType?.trim().isNotEmpty == true || displayContact.source?.trim().isNotEmpty == true)
                _buildDetailCard(
                  colors: colors,
                  icon: Icons.qr_code_scanner,
                  label: 'Contact Source',
                  value: (displayContact.contactType?.toUpperCase() == 'QR' || displayContact.source?.toLowerCase() == 'scan')
                      ? 'SmartCard QR Scan'
                      : (displayContact.source?.toLowerCase() == 'phone' ? 'Phone Contacts' : 'Manual Entry'),
                ),

              // Social Links Section
              if (displayContact.socialLinks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Social Profiles',
                    style: GoogleFonts.inter(
                      color: colors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...displayContact.socialLinks.where((link) => link.trim().isNotEmpty).map(
                  (link) => _buildDetailCard(
                    colors: colors,
                    icon: Icons.link,
                    label: 'Social Profile',
                    value: link.trim(),
                    onTap: () async {
                      String url = link.trim();
                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                        url = 'https://$url';
                      }
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Delete Action Button (Full Width)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: Text(
                    'Delete Contact',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _confirmDelete(context),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final nameController = TextEditingController(text: _contact.name);
    final phoneController = TextEditingController(text: _contact.phone);
    final altPhoneController = TextEditingController(text: _contact.alternativePhone ?? '');
    final whatsAppController = TextEditingController(text: _contact.whatsApp ?? '');
    final landlineController = TextEditingController(text: _contact.landline ?? '');
    final emailController = TextEditingController(text: _contact.email);
    final companyController = TextEditingController(text: _contact.company);
    final designationController = TextEditingController(text: _contact.designation);
    final websiteController = TextEditingController(text: _contact.website);
    final addressController = TextEditingController(text: _contact.address);
    final pinCodeController = TextEditingController(text: _contact.pinCode ?? '');
    final districtController = TextEditingController(text: _contact.district ?? '');
    final stateController = TextEditingController(text: _contact.stateName ?? '');
    final genderController = TextEditingController(text: _contact.gender ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E3F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 24,
            left: 24,
            right: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit Contact Details',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildEditTextField(label: 'Full Name', controller: nameController, icon: Icons.person),
                _buildEditTextField(label: 'Phone Number', controller: phoneController, icon: Icons.phone, keyboardType: TextInputType.phone),
                _buildEditTextField(label: 'Alternative Phone', controller: altPhoneController, icon: Icons.phone_android, keyboardType: TextInputType.phone),
                _buildEditTextField(label: 'WhatsApp Number', controller: whatsAppController, icon: Icons.chat, keyboardType: TextInputType.phone),
                _buildEditTextField(label: 'Landline', controller: landlineController, icon: Icons.phone_in_talk, keyboardType: TextInputType.phone),
                _buildEditTextField(label: 'Email Address', controller: emailController, icon: Icons.email, keyboardType: TextInputType.emailAddress),
                _buildEditTextField(label: 'Company Name', controller: companyController, icon: Icons.business),
                _buildEditTextField(label: 'Designation / Title', controller: designationController, icon: Icons.work),
                _buildEditTextField(label: 'Website', controller: websiteController, icon: Icons.language),
                _buildEditTextField(label: 'Address', controller: addressController, icon: Icons.location_on),
                _buildEditTextField(label: 'District', controller: districtController, icon: Icons.map),
                _buildEditTextField(label: 'State', controller: stateController, icon: Icons.map),
                _buildEditTextField(label: 'Pincode', controller: pinCodeController, icon: Icons.pin_drop, keyboardType: TextInputType.number),
                _buildEditTextField(label: 'Gender', controller: genderController, icon: Icons.person_outline),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final updated = _contact.copyWith(
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim(),
                        alternativePhone: altPhoneController.text.trim().isNotEmpty ? altPhoneController.text.trim() : null,
                        whatsApp: whatsAppController.text.trim().isNotEmpty ? whatsAppController.text.trim() : null,
                        landline: landlineController.text.trim().isNotEmpty ? landlineController.text.trim() : null,
                        email: emailController.text.trim(),
                        company: companyController.text.trim(),
                        designation: designationController.text.trim(),
                        website: websiteController.text.trim(),
                        address: addressController.text.trim(),
                        pinCode: pinCodeController.text.trim().isNotEmpty ? pinCodeController.text.trim() : null,
                        district: districtController.text.trim().isNotEmpty ? districtController.text.trim() : null,
                        stateName: stateController.text.trim().isNotEmpty ? stateController.text.trim() : null,
                        gender: genderController.text.trim().isNotEmpty ? genderController.text.trim() : null,
                      );
                      await context.read<ContactViewModel>().addScannedContact(updated);
                      if (mounted) {
                        setState(() {
                          _contact = updated;
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Contact updated successfully!'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildEditTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.08),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

    if (confirmed != true || !context.mounted) return;

    // Show loading indicator while deleting
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Deleting contact...'),
          ],
        ),
        duration: Duration(seconds: 15),
      ),
    );

    try {
      await context.read<ContactViewModel>().deleteContact(_contact.id, target: _contact);

      scaffoldMessenger.hideCurrentSnackBar();

      // Pop the screen FIRST, then show the success message on the contacts list
      if (navigator.canPop()) {
        navigator.pop({'deleted': true, 'name': _contact.name});
      }

      // Show success after pop so it appears on the contacts screen
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('${_contact.name.isNotEmpty ? _contact.name : "Contact"} deleted successfully.')),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      scaffoldMessenger.hideCurrentSnackBar();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Failed to delete: ${e.toString().replaceAll('Exception: ', '')}')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildDetailCard({
    required dynamic colors,
    required dynamic icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    Widget iconWidget;
    if (icon is IconData) {
      iconWidget = Icon(icon, color: colors.text, size: 20);
    } else {
      iconWidget = FaIcon(icon, color: colors.text, size: 20);
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colors.panel.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        color: colors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        color: colors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: colors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
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


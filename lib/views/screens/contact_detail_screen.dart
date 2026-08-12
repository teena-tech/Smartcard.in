import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/scanned_contact_model.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/contact_viewmodel.dart';
import 'home_screen.dart';
import '../../core/services/native_contact_service.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/common_drawer.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/upload_url_resolver.dart';
import '../widgets/rotating_profile_avatar_ring.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:share_plus/share_plus.dart';

class ContactDetailScreen extends StatefulWidget {
  final ScannedContactModel contact;

  const ContactDetailScreen({super.key, required this.contact});

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late ScannedContactModel _contact;
  String? _liveDevicePhoto;

  @override
  void initState() {
    super.initState();
    _contact = widget.contact;
    _fetchLiveDevicePhoto();
  }

  Future<void> _fetchLiveDevicePhoto() async {
    final photo = _contact.profileImage;
    if (photo == null || photo.trim().isEmpty) {
      if (_contact.id.startsWith('phone_') || _contact.source == 'phone') {
        try {
          final status = await Permission.contacts.status;
          if (!status.isGranted && !status.isLimited) return;

          final rawId = _contact.id.replaceFirst('phone_', '');
          final devContact = await FlutterContacts.getContact(
            rawId,
            withPhoto: true,
            withThumbnail: true,
          );
          if (devContact != null) {
            final bytes = devContact.photo ?? devContact.thumbnail ?? devContact.photoOrThumbnail;
            if (bytes != null && bytes.isNotEmpty) {
              final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              if (mounted) {
                setState(() {
                  _liveDevicePhoto = base64Str;
                });
              }
            }
          }
        } catch (e) {
          debugPrint('Live photo fetch error: $e');
        }
      }
    }
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

  void _showFullImageDialog(BuildContext context, String? imageSource, String name, String initial) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Bar with Contact Name & Close Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E3F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : 'Profile Photo Verification',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            // Main Full Screen Preview Image Container
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
                maxWidth: 420,
              ),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: _buildFullImageWidget(imageSource, initial),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullImageWidget(String? avatarSource, String initial) {
    if (avatarSource == null || avatarSource.trim().isEmpty) {
      return Container(
        height: 280,
        color: const Color(0xFFFEE2E2),
        child: Center(
          child: Text(
            initial.toUpperCase(),
            style: GoogleFonts.inter(
              color: const Color(0xFFE53935),
              fontSize: 72,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    if (avatarSource.startsWith('data:image')) {
      try {
        final base64Bytes = base64Decode(avatarSource.split(',').last);
        return Image.memory(
          base64Bytes,
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _buildFullImageWidget(null, initial),
        );
      } catch (_) {
        return _buildFullImageWidget(null, initial);
      }
    }
    if (avatarSource.startsWith('http://') || avatarSource.startsWith('https://')) {
      return Image.network(
        avatarSource,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 280,
            color: Colors.grey.shade900,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
          );
        },
        errorBuilder: (c, e, s) => _buildFullImageWidget(null, initial),
      );
    }
    final file = File(avatarSource);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => _buildFullImageWidget(null, initial),
      );
    }
    return _buildFullImageWidget(null, initial);
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

  void _handleShareContact(BuildContext context) {
    final c = _contact;
    final List<String> parts = [];

    parts.add('📇 Contact Details: ${c.name}');
    if (c.designation.isNotEmpty) parts.add('💼 Designation: ${c.designation}');
    if (c.company.isNotEmpty) parts.add('🏢 Company: ${c.company}');
    if (c.phone.isNotEmpty) parts.add('📞 Phone: ${c.phone}');
    if (c.email.isNotEmpty) parts.add('✉️ Email: ${c.email}');
    if (c.website.isNotEmpty) parts.add('🌐 Website: ${c.website}');
    if (c.address.isNotEmpty) parts.add('📍 Address: ${c.address}');

    if (c.cardUrl != null && c.cardUrl!.isNotEmpty) {
      final cardLink = c.cardUrl!.startsWith('http') ? c.cardUrl! : 'https://thesmartcards.com/c/${c.cardUrl!}';
      parts.add('💳 Digital Smart Card: $cardLink');
    }

    final shareText = parts.join('\n');
    // ignore: deprecated_member_use
    Share.share(shareText, subject: 'Contact Card: ${c.name}');
  }

  String _formatFullSmartCardUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return 'https://thesmartcards.com';
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('?sc=') || trimmed.startsWith('sc=')) {
      final q = trimmed.startsWith('?') ? trimmed : '?$trimmed';
      return 'https://thesmartcards.com$q';
    }
    if (trimmed.startsWith('/c/') || trimmed.startsWith('/')) {
      return 'https://thesmartcards.com$trimmed';
    }
    return 'https://thesmartcards.com/c/$trimmed';
  }

  List<Map<String, dynamic>> _getContactCards(ScannedContactModel contact) {
    if (contact.matchedCards != null && contact.matchedCards!.isNotEmpty) {
      return contact.matchedCards!;
    }
    final count = contact.totalCardsCount ?? 1;
    final List<Map<String, dynamic>> list = [];
    for (int i = 0; i < count; i++) {
      list.add({
        'company': i == 0 ? (contact.company.isNotEmpty ? contact.company : '') : '',
        'designation': i == 0
            ? (contact.primaryDesignation?.isNotEmpty == true ? contact.primaryDesignation! : contact.designation)
            : '',
        'cardUrl': contact.cardUrl,
        'profileImage': contact.matchedProfileImage ?? contact.profileImage,
      });
    }
    return list;
  }

  Widget _buildSmartCardSection(ScannedContactModel displayContact, dynamic colors) {
    if (!displayContact.isMatched) return const SizedBox.shrink();

    final cards = _getContactCards(displayContact);
    final totalCount = displayContact.totalCardsCount ?? cards.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SmartCards',
                  style: GoogleFonts.inter(
                    color: colors.text,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  totalCount > 1 ? '$totalCount Cards Held' : '1 Card Held',
                  style: GoogleFonts.inter(
                    color: colors.accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...cards.asMap().entries.map((entry) {
            final idx = entry.key;
            final cardData = entry.value;
            final companyName = cardData['company']?.toString().isNotEmpty == true
                ? cardData['company'].toString()
                : (idx == 0 && displayContact.company.isNotEmpty ? displayContact.company : '');
            final designationName = cardData['designation']?.toString().isNotEmpty == true
                ? cardData['designation'].toString()
                : (idx == 0
                    ? (displayContact.primaryDesignation?.isNotEmpty == true
                        ? displayContact.primaryDesignation!
                        : displayContact.designation)
                    : '');
            final rawUrl = cardData['cardUrl']?.toString() ?? displayContact.cardUrl;
            final fullUrl = _formatFullSmartCardUrl(rawUrl);
            final imgSource = cardData['profileImage']?.toString() ?? displayContact.matchedProfileImage ?? displayContact.profileImage;

            return Container(
              margin: EdgeInsets.only(bottom: idx == cards.length - 1 ? 0 : 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.panel.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accent.withValues(alpha: 0.15),
                          border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: imgSource != null && imgSource.isNotEmpty
                            ? Image.network(
                                UploadUrlResolver.resolve(imgSource, type: 'profile'),
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Center(
                                  child: Text(
                                    displayContact.name.isNotEmpty ? displayContact.name[0].toUpperCase() : 'S',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.accent),
                                  ),
                                ),
                              )
                            : Center(
                                child: Text(
                                  displayContact.name.isNotEmpty ? displayContact.name[0].toUpperCase() : 'S',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: colors.accent),
                                ),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (companyName.isNotEmpty)
                              Text(
                                companyName,
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (designationName.isNotEmpty)
                              Text(
                                designationName,
                                style: GoogleFonts.inter(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (companyName.isEmpty && designationName.isEmpty)
                              Text(
                                'Smart Card #${idx + 1}',
                                style: GoogleFonts.inter(
                                  color: colors.text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (fullUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: Text(
                          'View Card',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          final uri = Uri.parse(fullUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
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
        : (_liveDevicePhoto ?? ((currentContact.imagePath != null && currentContact.imagePath!.isNotEmpty) ? currentContact.imagePath! : null));

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
      backgroundColor: Colors.transparent,
      drawer: const CommonDrawer(
        backTitle: 'Back to Contacts',
      ),
      appBar: CommonAppBar(
        titleText: 'Contact Details',
        showBackButton: true,
        onBackTap: () => Navigator.pop(context),
        extraActions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Share Contact',
            onPressed: () => _handleShareContact(context),
          ),
        ],
        onProfileTap: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 3)),
            (route) => false,
          );
        },
      ),
      bottomNavigationBar: const GlobalBottomNav(),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/login.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: ResponsiveCenter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),
              // Circular Avatar Container with Rotating Ring & Full Image Verification Popup on Tap
              GestureDetector(
                onTap: () => _showFullImageDialog(context, avatarSource, displayContact.name, profileInitial),
                child: RotatingProfileAvatarRing(
                  size: 104,
                  borderWidth: 3.5,
                  child: avatarWidget,
                ),
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

              // Action Buttons (Call, WhatsApp, Text, Email, Share)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: const Icon(Icons.phone, color: Colors.red, size: 22),
                      label: 'Call',
                      color: const Color(0xFFFFE5E5),
                      iconColor: Colors.red,
                      onTap: () => _handleCall(context),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366), size: 22),
                      label: 'WhatsApp',
                      color: const Color(0xFFE8F5E9),
                      iconColor: const Color(0xFF25D366),
                      onTap: () => _handleWhatsApp(context),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: const Icon(Icons.message, color: Color(0xFF0284C7), size: 22),
                      label: 'Text',
                      color: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      onTap: () => _handleSms(context),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: const Icon(Icons.email, color: Color(0xFFD97706), size: 22),
                      label: 'Email',
                      color: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      onTap: () => _handleEmail(context),
                    ),
                    const SizedBox(width: 12),
                    _ActionButton(
                      icon: const Icon(Icons.share, color: Color(0xFF7C3AED), size: 22),
                      label: 'Share',
                      color: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () => _handleShareContact(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── SmartCard Verified Profile & Digital Card Preview Card ───────
              _buildSmartCardSection(displayContact, colors),

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

              // Edit & Delete Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        label: Text(
                          'Edit',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E1E3F),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _showEditDialog(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: Text(
                          'Delete',
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
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    ),
  );
  }

  void _showEditDialog(BuildContext context) async {
    final updated = await NativeContactService.openNativeContactEdit(context, _contact);
    if (updated != null && mounted) {
      setState(() {
        _contact = updated;
      });
    }
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
    return Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFFEBEE),
      ),
      child: Center(
        child: Text(
          initial.toUpperCase(),
          style: GoogleFonts.inter(
            color: const Color(0xFFE53935),
            fontSize: 38,
            fontWeight: FontWeight.bold,
          ),
        ),
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


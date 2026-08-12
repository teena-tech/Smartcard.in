import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/scanned_contact_model.dart';
import '../screens/contact_detail_screen.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/contact_viewmodel.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/utils/upload_url_resolver.dart';

class ContactListTile extends StatefulWidget {
  final ScannedContactModel contact;
  final VoidCallback onFavoriteToggle;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.onFavoriteToggle,
  });

  @override
  State<ContactListTile> createState() => _ContactListTileState();
}

class _ContactListTileState extends State<ContactListTile>
    with SingleTickerProviderStateMixin {
  static final Map<String, String> _devicePhotoCache = {};
  String? _fetchedLivePhoto;
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _checkLiveDevicePhoto();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ContactListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.id != widget.contact.id || oldWidget.contact.profileImage != widget.contact.profileImage) {
      _checkLiveDevicePhoto();
    }
  }

  void _checkLiveDevicePhoto() {
    final photo = widget.contact.profileImage;
    if (photo != null && photo.trim().isNotEmpty) return;

    final isPhone = widget.contact.source == 'phone' || widget.contact.id.startsWith('phone_');
    if (!isPhone) return;

    final cacheKey = widget.contact.id;
    if (_devicePhotoCache.containsKey(cacheKey)) {
      _fetchedLivePhoto = _devicePhotoCache[cacheKey];
      return;
    }

    final rawId = widget.contact.id.replaceFirst('phone_', '');
    if (rawId.isEmpty) return;

    Future(() async {
      try {
        final status = await Permission.contacts.status;
        if (!status.isGranted && !status.isLimited) return;

        final devContact = await FlutterContacts.getContact(
          rawId,
          withPhoto: true,
          withThumbnail: true,
        );
        if (devContact != null) {
          final bytes = devContact.photo ?? devContact.thumbnail ?? devContact.photoOrThumbnail;
          if (bytes != null && bytes.isNotEmpty) {
            final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
            _devicePhotoCache[cacheKey] = base64Str;
            if (mounted) {
              setState(() {
                _fetchedLivePhoto = base64Str;
              });
            }
          }
        }
      } catch (e) {
        debugPrint('List tile live photo fetch error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final initial = widget.contact.name.isNotEmpty ? widget.contact.name[0].toUpperCase() : '?';

    final String rawImage = (widget.contact.profileImage != null && widget.contact.profileImage!.isNotEmpty)
        ? widget.contact.profileImage!
        : (_fetchedLivePhoto ?? ((widget.contact.imagePath != null && widget.contact.imagePath!.isNotEmpty) ? widget.contact.imagePath! : ''));

    final String imageSource = rawImage.isNotEmpty ? UploadUrlResolver.resolve(rawImage, type: 'profile') : '';

    Widget imageWidget;
    if (imageSource.isEmpty) {
      imageWidget = _buildFallbackInitial(initial, colors);
    } else if (imageSource.startsWith('data:image') || imageSource.startsWith('data:')) {
      try {
        final base64Bytes = base64Decode(imageSource.split(',').last);
        imageWidget = Image.memory(
          base64Bytes,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildFallbackInitial(initial, colors),
        );
      } catch (_) {
        imageWidget = _buildFallbackInitial(initial, colors);
      }
    } else if (imageSource.startsWith('http://') || imageSource.startsWith('https://')) {
      imageWidget = Image.network(
        imageSource,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildFallbackInitial(initial, colors),
      );
    } else {
      final file = File(imageSource);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildFallbackInitial(initial, colors),
        );
      } else {
        imageWidget = _buildFallbackInitial(initial, colors);
      }
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactDetailScreen(contact: widget.contact),
          ),
        );
      },
      onLongPress: () => _showContactOptionsModal(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(left: 0, top: 0, bottom: 0, right: 12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left: Profile Image with pulse animation
            _pulseAnimation == null
                ? Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE53935), width: 2.5),
                      color: colors.panel,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageWidget,
                  )
                : AnimatedBuilder(
                    animation: _pulseAnimation!,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation!.value,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE53935),
                              width: 2.5,
                            ),
                            color: colors.panel,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: imageWidget,
                        ),
                      );
                    },
                  ),
            const SizedBox(width: 12),
            
            // Middle: Text Info (Name & Phone Number)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.contact.name.isNotEmpty ? widget.contact.name : '-',
                          style: GoogleFonts.inter(
                            color: colors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.contact.isMatched) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 16),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.contact.phone.isNotEmpty ? widget.contact.phone : '-',
                    style: GoogleFonts.inter(
                      color: colors.muted,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            if (widget.contact.isMatched) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  (widget.contact.totalCardsCount ?? 1) > 1
                      ? '${widget.contact.totalCardsCount} Cards'
                      : '1 Card',
                  style: GoogleFonts.inter(
                    color: colors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],

            // Red Arrow Icon
            const Icon(
              Icons.chevron_right,
              color: Color(0xFFE53935),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }

  void _shareContact() {
    final c = widget.contact;
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

  void _showContactOptionsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: const Color(0xFF1E1E3F),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Title Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.contact.name.isNotEmpty ? widget.contact.name : 'Contact Options',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // 1. Share Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.blueAccent, size: 22),
                ),
                title: Text(
                  'Share Contact Details',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Share phone, email and digital card link',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareContact();
                },
              ),

              const Divider(color: Colors.white10),

              // 2. Delete Option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                ),
                title: Text(
                  'Delete Contact',
                  style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Remove this contact from your list',
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackInitial(String initial, dynamic colors) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: colors.text,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final isPhone = widget.contact.source == 'phone' || widget.contact.id.startsWith('phone_');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isPhone ? 'Delete Mobile Contact?' : 'Delete Contact?',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isPhone
              ? 'This will permanently delete "${widget.contact.name}" from your mobile phone contacts (device address book) and app list.'
              : 'This will permanently delete "${widget.contact.name}" from your contacts.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Deleting contact...')),
              );
              await context.read<ContactViewModel>().deleteContact(widget.contact.id, target: widget.contact);
              scaffoldMessenger.showSnackBar(
                SnackBar(content: Text('"${widget.contact.name}" deleted successfully.')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

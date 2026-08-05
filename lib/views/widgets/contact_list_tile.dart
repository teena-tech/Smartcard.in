import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/scanned_contact_model.dart';
import '../screens/contact_detail_screen.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../core/utils/upload_url_resolver.dart';

class ContactListTile extends StatelessWidget {
  final ScannedContactModel contact;
  final VoidCallback onFavoriteToggle;

  const ContactListTile({
    super.key,
    required this.contact,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final initial = contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

    final String rawImage = (contact.profileImage != null && contact.profileImage!.isNotEmpty)
        ? contact.profileImage!
        : ((contact.imagePath != null && contact.imagePath!.isNotEmpty) ? contact.imagePath! : '');

    final String imageSource = rawImage.isNotEmpty ? UploadUrlResolver.resolve(rawImage, type: 'profile') : '';

    Widget imageWidget;
    if (imageSource.isEmpty) {
      imageWidget = _buildFallbackInitial(initial, colors);
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
            builder: (_) => ContactDetailScreen(contact: contact),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.card.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
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
            // Left: Profile Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.border),
                color: colors.panel,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageWidget,
            ),
            const SizedBox(width: 12),
            
            // Middle: Text Info (Name & Phone Number)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    contact.name.isNotEmpty ? contact.name : '-',
                    style: GoogleFonts.inter(
                      color: colors.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.phone.isNotEmpty
                        ? contact.phone
                        : (contact.designation.isNotEmpty ? contact.designation : '-'),
                    style: GoogleFonts.inter(
                      color: colors.muted,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Chevron Icon
            Icon(
              Icons.chevron_right,
              color: colors.text.withValues(alpha: 0.5),
              size: 24,
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildFallbackInitial(String initial, dynamic colors) {
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: colors.text,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}




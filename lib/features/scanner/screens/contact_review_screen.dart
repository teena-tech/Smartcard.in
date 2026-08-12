import 'package:flutter/material.dart';
import '../../../models/scanned_contact_model.dart';
import '../../../views/screens/contact_preview_screen.dart';

class ContactReviewScreen extends StatelessWidget {
  final ScannedContactModel contact;
  final String? imagePath;

  const ContactReviewScreen({
    super.key,
    required this.contact,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return ContactPreviewScreen(
      contact: contact,
      imagePath: imagePath,
    );
  }
}

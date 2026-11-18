import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/contact_model.dart';
import '../../../models/scanned_contact_model.dart';
import 'full_card_view_screen.dart';
import '../../../core/utils/upload_url_resolver.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../widgets/global_bottom_nav.dart';
import '../widgets/master_app_bar.dart';

class QrLandingScreen extends StatefulWidget {
  final ContactModel contact;
  final ScannedContactModel scannedContact;

  const QrLandingScreen({
    super.key,
    required this.contact,
    required this.scannedContact,
  });

  @override
  State<QrLandingScreen> createState() => _QrLandingScreenState();
}

class _QrLandingScreenState extends State<QrLandingScreen> {
  Timer? _autoRedirectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().incrementCardViews(widget.contact.id);
    });

    // Automatically redirect to card details after 3 seconds
    _autoRedirectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _navigateToDetails();
      }
    });
  }

  void _navigateToDetails() {
    _autoRedirectTimer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FullCardViewScreen(
          contact: widget.contact,
          scannedContact: widget.scannedContact,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final scannedContact = widget.scannedContact;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: const MasterAppBar(
        style: MasterHeaderStyle.transparent,
      ),
      bottomNavigationBar: const GlobalBottomNav(),
      body: Stack(
        children: [
          // Elegant Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                image: (contact.backgroundImage != null && contact.backgroundImage!.trim().isNotEmpty)
                    ? DecorationImage(
                        image: NetworkImage(
                          UploadUrlResolver.resolve(contact.backgroundImage!.trim(), type: 'card-bg'),
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
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Profile / Company Avatar
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.15), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: ClipOval(
                        child: Builder(
                          builder: (_) {
                            if (scannedContact.imagePath != null && scannedContact.imagePath!.isNotEmpty && File(scannedContact.imagePath!).existsSync()) {
                              return Image.file(
                                File(scannedContact.imagePath!),
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                              );
                            }
                            final profileUrl = (contact.profileImageName != null && contact.profileImageName!.trim().isNotEmpty)
                                ? UploadUrlResolver.resolve(contact.profileImageName!.trim(), type: 'profile')
                                : (contact.companyLogo != null && contact.companyLogo!.trim().isNotEmpty)
                                    ? UploadUrlResolver.resolve(contact.companyLogo!.trim(), type: 'logo')
                                    : '';
                            if (profileUrl.isNotEmpty) {
                              return Image.network(
                                profileUrl,
                                fit: BoxFit.cover,
                                width: 120,
                                height: 120,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person,
                                  color: Colors.redAccent,
                                  size: 64,
                                ),
                              );
                            }
                            return const Icon(
                              Icons.person,
                              color: Colors.redAccent,
                              size: 64,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Name / Company Title
                  Center(
                    child: Text(
                      contact.companyName.isNotEmpty ? contact.companyName : 'SmartCard Business Inc.',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Ready to connect & view professional profile',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  // Preview Option (opens full card details URL/screen directly)
                  TextButton.icon(
                    onPressed: _navigateToDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(
                      'PREVIEW CARD DETAILS',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/contact_model.dart';
import '../../../models/scanned_contact_model.dart';
import 'full_card_view_screen.dart';
import '../../../core/utils/upload_url_resolver.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../widgets/common_drawer.dart';
import '../widgets/global_bottom_nav.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileViewModel>().incrementCardViews(widget.contact.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final scannedContact = widget.scannedContact;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: const CommonDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
                  // Company Logo Block (with premium borders)
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
                      child: (contact.companyLogo != null && contact.companyLogo!.trim().isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                UploadUrlResolver.resolve(contact.companyLogo!.trim(), type: 'logo'),
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.business_rounded,
                                  color: Colors.redAccent,
                                  size: 64,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.business_rounded,
                              color: Colors.redAccent,
                              size: 64,
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Company Name
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
                  // QR Scanner / AR Scan Buttons (First View Only triggers scanner)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Starting AR scan experience...')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.view_in_ar_outlined),
                          label: Text(
                            'AR SCAN EXPERIENCE',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Go back to scan again
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(
                            'QR SCANNER',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Preview Option (opens full card details URL/screen directly)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FullCardViewScreen(
                            contact: contact,
                            scannedContact: scannedContact,
                          ),
                        ),
                      );
                    },
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

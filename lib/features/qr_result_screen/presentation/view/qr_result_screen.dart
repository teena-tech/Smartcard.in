import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smartcard_flutter/core/constants/app_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/qr_result.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';

class QrResultScreen extends StatelessWidget {
  final QrResult qrResult;

  const QrResultScreen({
    super.key,
    required this.qrResult,
  });

  void _handleOpen(BuildContext context) async {
    final raw = qrResult.rawContent;
    Uri? uri;
    if (qrResult.type == QrResultType.url) {
      uri = Uri.tryParse(raw.startsWith('http') ? raw : 'https://$raw');
    } else if (qrResult.type == QrResultType.phone) {
      uri = Uri.tryParse('tel:${qrResult.parsedFields['phone'] ?? raw}');
    } else if (qrResult.type == QrResultType.email) {
      uri = Uri.tryParse('mailto:${qrResult.parsedFields['email'] ?? raw}');
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $raw')),
        );
      }
    }
  }

  void _handleCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: qrResult.rawContent));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard ✓'),
        backgroundColor: Color(0xFF00E676),
      ),
    );
  }

  void _handleShare() {
    Share.share(qrResult.rawContent);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D18),
      appBar: MasterAppBar(
        titleText: 'QR Code Result',
        showBackButton: true,
        onBackTap: () => Navigator.maybePop(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'QR Code Found',
                    style: AppFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 350.ms)
                  .scale(duration: 350.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 28),

              // QR Code Preview Container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    )
                  ],
                ),
                child: QrImageView(
                  data: qrResult.rawContent,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              )
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .scale(delay: 150.ms, duration: 400.ms, curve: Curves.easeOut),

              const SizedBox(height: 32),

              // Info Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type:',
                      style: AppFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      qrResult.displayTitle,
                      style: AppFonts.poppins(color: const Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Content:',
                      style: AppFonts.poppins(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      qrResult.rawContent,
                      style: AppFonts.poppins(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Action Buttons Row
              Row(
                children: [
                  if (qrResult.type == QrResultType.url ||
                      qrResult.type == QrResultType.phone ||
                      qrResult.type == QrResultType.email)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _handleOpen(context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text('Open'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: AppFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                  if (qrResult.type == QrResultType.url ||
                      qrResult.type == QrResultType.phone ||
                      qrResult.type == QrResultType.email)
                    const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleCopy(context),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: AppFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleShare,
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: AppFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

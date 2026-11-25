import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:smartcard_flutter/features/contacts_screen/data/models/contact_model.dart';
import 'package:smartcard_flutter/core/widgets/master_app_bar.dart';

class DigitalCardShareScreen extends StatefulWidget {
  final ContactModel contact;

  const DigitalCardShareScreen({
    super.key,
    required this.contact,
  });

  @override
  State<DigitalCardShareScreen> createState() => _DigitalCardShareScreenState();
}

class _DigitalCardShareScreenState extends State<DigitalCardShareScreen> {
  // Key used by RepaintBoundary to capture the digital card as an image
  final GlobalKey _cardKey = GlobalKey();
  bool _isProcessing = false;

  Rect? _getShareOriginRect() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return null;
  }

  /// Render and capture the widget inside RepaintBoundary as a high-resolution PNG image.
  Future<Uint8List?> _captureCardImage() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // 3.0 pixel ratio ensures a crisp image on retina / high-DPI displays & printing
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing QR card: $e');
      return null;
    }
  }

  /// Action 1: Share text or .vcf contact card file via native share sheet
  Future<void> _shareContactInfo() async {
    final originRect = _getShareOriginRect();
    setState(() => _isProcessing = true);
    try {
      final vcfContent = await widget.contact.toVCardWithPhoto(forQrCode: false);
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = widget.contact.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      final vcfFile = File('${tempDir.path}/$sanitizedName.vcf');
      await vcfFile.writeAsString(vcfContent);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(vcfFile.path, mimeType: 'text/vcard')],
          text: widget.contact.toPlainText(),
          subject: '${widget.contact.name} - Digital Business Card',
          sharePositionOrigin: originRect,
        ),
      );
    } catch (e) {
      _showSnackbar('Failed to share contact info: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Action 2: Capture card as PNG and share via native share sheet
  Future<void> _shareCardImage() async {
    final originRect = _getShareOriginRect();
    setState(() => _isProcessing = true);
    try {
      final pngBytes = await _captureCardImage();
      if (pngBytes == null) {
        throw Exception('Could not render card image');
      }

      final tempDir = await getTemporaryDirectory();
      final sanitizedName = widget.contact.name
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
          .toLowerCase();
      final imagePath = '${tempDir.path}/${sanitizedName}_qr.png';
      final file = File(imagePath);
      await file.writeAsBytes(pngBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          text: 'Scan to save ${widget.contact.name}\'s contact details',
          subject: '${widget.contact.name} QR Card',
          sharePositionOrigin: originRect,
        ),
      );
    } catch (e) {
      _showSnackbar('Failed to share QR image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Action 3: Save captured card to the Downloads or Documents folder
  Future<void> _saveToStorage() async {
    setState(() => _isProcessing = true);
    try {
      final pngBytes = await _captureCardImage();
      if (pngBytes == null) throw Exception('Image capture failed');

      Directory? saveDir;
      if (Platform.isAndroid) {
        saveDir = Directory('/storage/emulated/0/Download');
        if (!await saveDir.exists()) {
          saveDir = await getExternalStorageDirectory();
        }
      } else {
        saveDir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${saveDir!.path}/smart_card_$timestamp.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      _showSnackbar('Saved successfully to:\n$filePath');
    } catch (e) {
      _showSnackbar('Could not save image: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vCardData = widget.contact.toVCard();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: const MasterAppBar(
        titleText: 'Share Contact Card',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Captured Business Card UI
                  Center(
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: _buildDigitalCard(context, vCardData),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Point any phone camera at this QR code\nto instantly add to contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),

                  const SizedBox(height: 32),

                  // Action Button 1: Share Contact Info
                  _buildPrimaryActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share Contact Info (vCard / Text)',
                    color: const Color(0xFF0F172A),
                    onPressed: _isProcessing ? null : _shareContactInfo,
                  ),

                  const SizedBox(height: 12),

                  // Action Button 2: Share QR Code Image
                  _buildPrimaryActionButton(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Share QR Code as Image',
                    color: const Color(0xFF0284C7),
                    onPressed: _isProcessing ? null : _shareCardImage,
                  ),

                  const SizedBox(height: 12),

                  // Action Button 3: Download / Save to Device
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _saveToStorage,
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: const Text('Save QR to Device'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      minimumSize: const Size.fromHeight(50),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            if (_isProcessing)
              Container(
                color: Colors.black.withAlpha(76),
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The printable/shareable Business Card widget with the QR Code
  Widget _buildDigitalCard(BuildContext context, String vCardData) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Preview Header
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF0284C7),
                child: Text(
                  _getInitials(widget.contact.name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contact.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.contact.jobTitle.isNotEmpty)
                      Text(
                        widget.contact.jobTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF0284C7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.contact.company.isNotEmpty)
                      Text(
                        widget.contact.company,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          ),

          // Central QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: vCardData,
              version: QrVersions.auto,
              size: 210,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Quick summary pill (Phone or Email)
          if ((widget.contact.phone != null && widget.contact.phone!.isNotEmpty) ||
              (widget.contact.email != null && widget.contact.email!.isNotEmpty))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (widget.contact.phone != null && widget.contact.phone!.isNotEmpty)
                    ? widget.contact.phone!
                    : widget.contact.email!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF475569),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'SC';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

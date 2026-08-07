import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/scan_type.dart';
import '../models/detected_card.dart';
import '../models/scanner_state.dart';
import 'qr_overlay.dart';
import 'card_overlay.dart';
import 'scanner_status.dart';

class ScannerOverlay extends StatelessWidget {
  final ScanType scanType;
  final ScannerStateEnum state;
  final DetectedCard? detectedCard;
  final double stabilityProgress;
  final VoidCallback? onTorchToggle;
  final VoidCallback? onCameraSwitch;
  final VoidCallback? onManualCapture;
  final VoidCallback? onBackPressed;
  final bool isTorchOn;

  const ScannerOverlay({
    super.key,
    required this.scanType,
    required this.state,
    this.detectedCard,
    this.stabilityProgress = 0.0,
    this.onTorchToggle,
    this.onCameraSwitch,
    this.onManualCapture,
    this.onBackPressed,
    this.isTorchOn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Mode-Specific Visual Overlay
        if (scanType == ScanType.qr)
          QrOverlay(isDetected: state == ScannerStateEnum.success)
        else
          CardOverlay(
            detectedCard: detectedCard,
            isCapturing: state == ScannerStateEnum.capturing || state == ScannerStateEnum.stable,
          ),

        // Top Controls Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: onBackPressed,
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                ),
                Text(
                  scanType == ScanType.qr ? 'Scan QR Code' : 'Scan Business Card',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: onTorchToggle,
                      icon: Icon(
                        isTorchOn ? Icons.flash_on : Icons.flash_off,
                        color: isTorchOn ? Colors.amber : Colors.white,
                      ),
                    ),
                    IconButton(
                      onPressed: onCameraSwitch,
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom Guidance Status
        Positioned(
          bottom: 36,
          left: 16,
          right: 16,
          child: ScannerStatusWidget(
            message: state.userFeedbackMessage,
            stabilityProgress: stabilityProgress,
            onManualCaptureTap: onManualCapture,
            showManualFallback: scanType == ScanType.businessCard &&
                (state == ScannerStateEnum.searching || state == ScannerStateEnum.aligning),
          ),
        ),
      ],
    );
  }
}

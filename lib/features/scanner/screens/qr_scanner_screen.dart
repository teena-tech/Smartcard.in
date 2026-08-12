import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/services/qr_extraction_service.dart';
import '../../../models/scanned_contact_model.dart';
import '../../../viewmodels/contact_viewmodel.dart';
import '../../../views/screens/contact_preview_screen.dart';
import '../models/scan_type.dart';
import '../models/scanner_state.dart';
import '../models/qr_result.dart';
import '../widgets/scanner_overlay.dart';
import 'qr_result_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _cameraController;
  bool _isTorchOn = false;
  bool _isProcessing = false;
  ScannerStateEnum _state = ScannerStateEnum.searching;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue?.trim();
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;
    setState(() => _state = ScannerStateEnum.success);
    HapticFeedback.mediumImpact();

    try {
      await _cameraController?.stop();
    } catch (_) {}

    if (!mounted) return;

    try {
      // Step 1: Database match & API profile extraction
      final ScannedContactModel scannedContact = await QrExtractionService.extract(rawValue);

      // Step 2: Save to ViewModel / Hive database
      if (mounted) {
        await context.read<ContactViewModel>().addScannedContact(scannedContact);
      }
      // Step 3: Open ContactPreviewScreen with full contact edit UI
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ContactPreviewScreen(
              contact: scannedContact,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('QR Database matching fallback: $e');
      if (!mounted) return;
      final qrResult = QrResult.fromRawString(rawValue);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QrResultScreen(qrResult: qrResult),
        ),
      );
    }
  }

  void _toggleTorch() async {
    try {
      await _cameraController?.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _cameraController?.switchCamera();
    } catch (_) {}
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _cameraController!,
            fit: BoxFit.cover,
            onDetect: _onDetect,
          ),
          ScannerOverlay(
            scanType: ScanType.qr,
            state: _state,
            isTorchOn: _isTorchOn,
            onTorchToggle: _toggleTorch,
            onCameraSwitch: _switchCamera,
            onBackPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}

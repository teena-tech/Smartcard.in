import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../../core/services/qr_extraction_service.dart';
import '../../../models/scanned_contact_model.dart';
import '../../../viewmodels/contact_viewmodel.dart';
import '../../../viewmodels/dashboard_viewmodel.dart';
import '../../../viewmodels/profile_viewmodel.dart';
import '../../../providers/contact_provider.dart';
import '../../../views/screens/contact_preview_screen.dart';
import '../../../views/widgets/duplicate_scan_popup_dialog.dart';
import '../../../core/services/firebase_contact_sync_service.dart';
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
      // Step 1: Extract contact from QR
      final ScannedContactModel scannedContact = await QrExtractionService.extract(rawValue);

      if (!mounted) return;

      final contactVm = context.read<ContactViewModel>();
      final contactProvider = context.read<ContactProvider>();
      await contactVm.recordScan();

      try {
        final profileVm = context.read<ProfileViewModel>();
        final uid = profileVm.user?.id;
        if (uid != null && uid.isNotEmpty) {
          profileVm.incrementScanCount(uid);
        }
      } catch (_) {}

      // Step 2: Duplicate check across smart cards and phone contacts
      final duplicateCheck = contactVm.checkCardDuplicate(
        scannedContact,
        phoneContacts: contactProvider.contacts,
      );

      final isDuplicateFound = (duplicateCheck.isDuplicate ||
          duplicateCheck.isSameNumberDifferentCard ||
          duplicateCheck.existingContact != null) &&
          duplicateCheck.existingContact != null;

      // When duplicate phone/contact is detected, show the 10-second transparent popup with the big swipe button
      if (isDuplicateFound && mounted) {
        // Immediately sync existing contact to Firebase Firestore in background so it appears in Firebase console right away
        FirebaseContactSyncService().syncContactToFirebase(duplicateCheck.existingContact!);

        final action = await DuplicateScanPopupDialog.show(
          context: context,
          incoming: scannedContact,
          existing: duplicateCheck.existingContact!,
        );

        if (!mounted) return;

        if (action == DuplicateScanAction.update) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ContactPreviewScreen(
                contact: scannedContact,
                existingContact: duplicateCheck.existingContact,
              ),
            ),
          );
        } else if (action == DuplicateScanAction.exit) {
          setState(() {
            _state = ScannerStateEnum.searching;
            _isProcessing = false;
          });
          try {
            context.read<DashboardViewModel>().setIndex(0);
          } catch (_) {}
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // continueScan: keep scanning without saving
          setState(() {
            _state = ScannerStateEnum.searching;
            _isProcessing = false;
          });
          try { await _cameraController?.start(); } catch (_) {}
        }
        return;
      }

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

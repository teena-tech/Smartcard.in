import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/core/di/app_di.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smartcard_flutter/core/services/qr_extraction_service.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_viewmodel.dart';
import 'package:smartcard_flutter/features/home_screen/presentation/viewmodel/dashboard_viewmodel.dart';
import 'package:smartcard_flutter/features/profile_screen/presentation/viewmodel/profile_viewmodel.dart';
import 'package:smartcard_flutter/features/contacts_screen/presentation/viewmodel/contact_notifier.dart';
import 'package:smartcard_flutter/features/contact_preview_screen/presentation/view/contact_preview_screen.dart';
import 'package:smartcard_flutter/core/widgets/duplicate_scan_popup_dialog.dart';
import 'package:smartcard_flutter/core/services/firebase_contact_sync_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scan_type.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scanner_state.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/qr_result.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/presentation/view/widgets/scanner_overlay.dart';
import 'package:smartcard_flutter/features/qr_result_screen/presentation/view/qr_result_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
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

      final contactVm = ref.read(contactViewModelProvider.notifier);
      final contactNotifier = ref.read(contactNotifierProvider.notifier);
      await contactVm.recordScan();

      try {
        final profileVm = ref.read(profileViewModelProvider.notifier);
        final uid = profileVm.user?.id;
        if (uid != null && uid.isNotEmpty) {
          profileVm.incrementScanCount(uid);
        }
      } catch (_) {}

      // Step 2: Duplicate check across smart cards and phone contacts
      final duplicateCheck = contactVm.checkCardDuplicate(
        scannedContact,
        phoneContacts: contactNotifier.contacts,
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
            ref.read(dashboardViewModelProvider.notifier).setIndex(0);
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

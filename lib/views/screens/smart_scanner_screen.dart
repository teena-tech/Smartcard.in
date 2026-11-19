import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart' as legacy;
import '../../core/providers/app_riverpod_providers.dart';

import '../../core/providers/scanner_provider.dart';
import '../../core/utils/business_card_validator.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/card_tracker_overlay.dart';
import '../widgets/image_cropper_widget.dart';
import '../widgets/scanner_overlay.dart';
import '../../features/scanner/services/image_processing_service.dart';
import '../../core/utils/top_to_bottom_slide_route.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../providers/contact_provider.dart';
import '../widgets/duplicate_scan_popup_dialog.dart';
import 'contact_preview_screen.dart';

/// Instant QR scanner + business card edge detection (auto + manual).
class SmartScannerScreen extends ConsumerStatefulWidget {
  const SmartScannerScreen({super.key});

  @override
  ConsumerState<SmartScannerScreen> createState() => _SmartScannerScreenState();
}

class _SmartScannerScreenState extends ConsumerState<SmartScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _qrController;

  // â”€â”€ MLKit card detection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _mlkitBusy = false;
  Rect? _detectedCardRect;          // screen-space rect of detected card
  Timer? _detectionTimer;           // periodic frame analysis
  String? _lastCapturedImagePath;   // path to last camera capture for analysis

  bool _hasPermission = false;
  bool _permissionChecked = false;
  bool _isProcessingQr = false;
  bool _cardLocked = false;
  String? _lastQr;
  bool _isDisposed = false;
  bool _isSavingPreview = false;
  DashboardViewModel? _dashboardViewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Controller will be dynamically initialized in _handleCameraLifecycle when active


    // Periodic card detection via MLKit on captured frames
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      _runCardDetection();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
          context.findAncestorWidgetOfExactType<ProviderScope>() != null;
      _dashboardViewModel = hasScope
          ? ProviderScope.containerOf(context, listen: false).read(dashboardViewModelProvider)
          : legacy.Provider.of<DashboardViewModel>(context, listen: false);
      _dashboardViewModel?.addListener(_onTabChanged);

      if (kIsWeb) {
        if (mounted) {
          setState(() {
            _permissionChecked = true;
            _hasPermission = true;
          });
          if (_dashboardViewModel?.currentIndex == 1) {
            _handleCameraLifecycle();
          }
        }
        return;
      }

      try {
        final status = await Permission.camera.status;
        if (mounted) {
          setState(() {
            _permissionChecked = true;
            _hasPermission = status.isGranted;
          });
          if (_dashboardViewModel?.currentIndex == 1) {
            if (status.isGranted) {
              _handleCameraLifecycle();
            } else {
              _requestPermissions();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _permissionChecked = true;
            _hasPermission = false;
          });
        }
      }
    });
  }

  /// Captures a camera frame via ImagePicker (low quality, quick) then runs
  /// MLKit text recognition to find the bounding box of detected text blocks.
  /// A wide bounding rect = likely business card in view.
  Future<void> _runCardDetection() async {
    if (_mlkitBusy || _isDisposed || !context.mounted || !_hasPermission) return;
    if (_isProcessingQr || _cardLocked) return;
    // Only run when scan tab is active
    final isScanTab = ref.read(tabIndexProvider) == 1 || (_dashboardViewModel?.currentIndex == 1);
    if (!isScanTab) return;

    // Use the last screenshot if available via the MobileScanner image stream
    // Since we can't grab a frame directly, we use a temp camera capture
    // via the camera package's takePicture-equivalent through image_picker.
    // NOTE: This is a lightweight approach without launching full image picker UI.
    // We rely on ImagePicker's pickImage with camera source silently.
    // For production: integrate camera package image stream for continuous analysis.
    // Here we simulate detection with a heuristic delay after the tab is active.
    _mlkitBusy = true;
    try {
      // Attempt to get a quick frame snapshot
      // Since MobileScanner doesn't expose raw frames easily, we use a workaround:
      // analyze the last known captured image path if set by the scan button flow.
      if (_lastCapturedImagePath != null) {
        final file = File(_lastCapturedImagePath!);
        if (await file.exists()) {
          final inputImage = InputImage.fromFilePath(_lastCapturedImagePath!);
          final recognized = await _textRecognizer.processImage(inputImage);
          if (!context.mounted) return;
          _processMLKitResult(recognized);
        }
      }
    } catch (e) {
      debugPrint('MLKit detection error: $e');
    } finally {
      _mlkitBusy = false;
    }
  }

  /// Converts MLKit text blocks to a screen-space Rect estimate.
  void _processMLKitResult(RecognizedText recognized) {
    if (recognized.blocks.isEmpty) {
      if (context.mounted) setState(() => _detectedCardRect = null);
      return;
    }

    // Union all block bounding boxes
    Rect? union;
    for (final block in recognized.blocks) {
      final r = block.boundingBox;
      union = union == null ? r : union.expandToInclude(r);
    }

    if (union != null && context.mounted) {
      // Pad the rect slightly
      final padded = union.inflate(18);
      setState(() => _detectedCardRect = padded);
    }
  }

  void _handleCameraLifecycle() {
    if (!context.mounted || _isDisposed) return;

    final isScanTab = ref.read(tabIndexProvider) == 1 || (_dashboardViewModel?.currentIndex == 1);
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;

    if (isScanTab && isCurrentRoute) {
      if (!_permissionChecked || !_hasPermission) {
        _requestPermissions();
      } else {
        if (_qrController == null) {
          _qrController = MobileScannerController(
            detectionSpeed: DetectionSpeed.noDuplicates,
            facing: CameraFacing.back,
            formats: BarcodeFormat.values.contains(BarcodeFormat.qrCode)
                ? const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix]
                : BarcodeFormat.values,
          );
          if (context.mounted) setState(() {});
        }
        try {
          _qrController?.start().catchError((e) => debugPrint("Error starting camera: $e"));
        } catch (e) {
          debugPrint("Error starting camera: $e");
        }
      }
    } else {
      if (_qrController != null) {
        try {
          _qrController?.stop();
          _qrController?.dispose();
          _qrController = null;
          if (context.mounted) setState(() {});
        } catch (e) {
          debugPrint("Error disposing camera: $e");
        }
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleCameraLifecycle();
  }

  void _onTabChanged() {
    if (context.mounted) {
      _lastQr = null;
      _isProcessingQr = false;
      _cardLocked = false;
      _detectedCardRect = null;
      _lastCapturedImagePath = null;
      ref.read(scannerNotifierProvider.notifier).resetScanState();
    }
    _handleCameraLifecycle();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dashboardViewModel?.removeListener(_onTabChanged);
    _detectionTimer?.cancel();
    _textRecognizer.close();
    try {
      _qrController?.dispose();
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_isDisposed) return;
    if (state == AppLifecycleState.paused) {
      if (_qrController != null) {
        try {
          await _qrController!.stop();
          await _qrController!.dispose();
          _qrController = null;
          if (context.mounted) setState(() {});
        } catch (e) {
          debugPrint("Error disposing camera: $e");
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_hasPermission) {
        try {
          final cameraStatus = await Permission.camera.status;
          if (cameraStatus.isGranted) {
            setState(() {
              _hasPermission = true;
              _permissionChecked = true;
            });
          }
        } catch (e) {
          debugPrint("Error checking camera permission on resume: $e");
        }
      }
      _handleCameraLifecycle();
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      if (context.mounted) {
        setState(() {
          _hasPermission = true;
          _permissionChecked = true;
        });
      }
      return;
    }

    try {
      final camStatus = await Permission.camera.status;
      if (camStatus.isGranted) {
        if (context.mounted) {
          setState(() {
            _hasPermission = true;
            _permissionChecked = true;
          });
          _handleCameraLifecycle();
        }
        return;
      }

      final result = await Permission.camera.request();
      if (context.mounted) {
        setState(() {
          _hasPermission = result.isGranted;
          _permissionChecked = true;
        });

        if (result.isGranted) {
          _handleCameraLifecycle();
        } else if (result.isPermanentlyDenied) {
          _showCameraPermissionPermanentlyDeniedDialog();
        } else if (result.isDenied) {
          _showCameraPermissionDeniedDialog();
        }
      }
    } catch (e) {
      debugPrint("Camera permission request error: $e");
      if (context.mounted) {
        setState(() {
          _hasPermission = false;
          _permissionChecked = true;
        });
      }
    }
  }


  void _showCameraPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.camera_alt_outlined, color: Color(0xFFFF5252), size: 28),
            const SizedBox(width: 12),
            Text(
              'Camera Access',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'To scan QR codes and business cards, please grant camera access.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestPermissions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Allow',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showCameraPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white10),
        ),
        title: Row(
          children: [
            const Icon(Icons.settings_outlined, color: Color(0xFFFF5252), size: 28),
            const SizedBox(width: 12),
            Text(
              'Enable in Settings',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Camera access has been permanently denied. Please enable it in the system settings to scan cards.',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Settings',
              style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _onQrDetect(BarcodeCapture capture) {
    if (_isProcessingQr || _isDisposed || !context.mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty || code == _lastQr) return;
    if (!BusinessCardValidator.validateQr(code)) return;

    _isProcessingQr = true;
    _lastQr = code;
    try {
      _qrController?.stop().catchError((e) => debugPrint("Error stopping camera: $e"));
    } catch (_) {}
    HapticFeedback.mediumImpact();

    ref.read(scannerNotifierProvider.notifier).processQrCode(code);
  }

  int _getAndroidSdkVersion() {
    try {
      final match = RegExp(r'API\s*(\d+)', caseSensitive: false).firstMatch(Platform.operatingSystemVersion);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? 33;
      }
      final verMatch = RegExp(r'^(\d+)').firstMatch(Platform.operatingSystemVersion);
      if (verMatch != null) {
        final osVer = int.tryParse(verMatch.group(1)!);
        if (osVer != null) {
          if (osVer >= 13) return 33;
          if (osVer == 12) return 31;
          if (osVer == 11) return 30;
          if (osVer == 10) return 29;
          return osVer;
        }
      }
    } catch (_) {}
    return 33;
  }

  Future<void> _pickGallery() async {
    // permission_handler is not supported on web; skip checks
    if (!kIsWeb) {
      bool isGranted = false;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final sdk = _getAndroidSdkVersion();
        if (sdk >= 33) {
          // Android 13+ (API 33+) native Photo Picker requires zero runtime storage permissions
          isGranted = true;
        } else {
          // Android <= 12 (API <= 32) requires READ_EXTERNAL_STORAGE (Permission.storage)
          final storageStatus = await Permission.storage.status;
          if (storageStatus.isGranted) {
            isGranted = true;
          } else if (storageStatus.isPermanentlyDenied) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Storage permission is required to select card images. Please enable it in Settings."),
                  backgroundColor: Colors.redAccent,
                  action: SnackBarAction(
                    label: "Settings",
                    textColor: Colors.white,
                    onPressed: () => openAppSettings(),
                  ),
                ),
              );
            }
            return;
          } else {
            final resStorage = await Permission.storage.request();
            if (resStorage.isGranted) {
              isGranted = true;
            } else if (resStorage.isPermanentlyDenied) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Storage permission is required to select card images. Please enable it in Settings."),
                    backgroundColor: Colors.redAccent,
                    action: SnackBarAction(
                      label: "Settings",
                      textColor: Colors.white,
                      onPressed: () => openAppSettings(),
                    ),
                  ),
                );
              }
              return;
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Storage permission is required to select images."),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
              return;
            }
          }
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final photoStatus = await Permission.photos.status;
        if (photoStatus.isGranted || photoStatus.isLimited) {
          isGranted = true;
        } else if (photoStatus.isPermanentlyDenied || photoStatus.isRestricted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Photo library permission is required to select card images. Please enable it in Settings."),
                backgroundColor: Colors.redAccent,
                action: SnackBarAction(
                  label: "Settings",
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          return;
        } else {
          final res = await Permission.photos.request();
          if (res.isGranted || res.isLimited) {
            isGranted = true;
          } else if (res.isPermanentlyDenied || res.isRestricted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Photo library permission is required to select card images. Please enable it in Settings."),
                  backgroundColor: Colors.redAccent,
                  action: SnackBarAction(
                    label: "Settings",
                    textColor: Colors.white,
                    onPressed: () => openAppSettings(),
                  ),
                ),
              );
            }
            return;
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Photo library permission is required to select images."),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
            return;
          }
        }
      } else {
        isGranted = true;
      }

      if (!isGranted) {
        return;
      }
    }

    await _releaseCameraForExternalAction();
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked != null && context.mounted) {
      // 1. Auto-detect card quad boundary & perspective warp
      String autoPath = picked.path;
      try {
        autoPath = await ImageProcessingService().autoDetectCardAndCrop(picked.path);
      } catch (e) {
        debugPrint("Auto detect crop error for gallery photo: $e");
      }

      // 2. Open interactive cropper so user can review and manually adjust card crop
      if (context.mounted) {
        final userCropped = await ImageCropperHelper.cropBusinessCardImage(
          autoPath,
          context: context,
        );

        final finalPath = userCropped?.path ?? autoPath;

        if (context.mounted) {
          ref.read(scannerNotifierProvider.notifier).processGalleryImage(
            imagePath: finalPath,
            manualEdgeAdjust: false,
          );
        }
      }
    } else if (context.mounted) {
      ref.read(scannerNotifierProvider.notifier).resetScanState();
      _handleCameraLifecycle();
    }
  }

  Future<void> _releaseCameraForExternalAction() async {
    if (_qrController != null) {
      try {
        await _qrController!.stop();
        await _qrController!.dispose();
      } catch (e) {
        debugPrint("Error disposing camera before external action: $e");
      }
      _qrController = null;
      if (mounted) setState(() {});
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _scanCardWithEdgeCamera() async {
    await _releaseCameraForExternalAction();
    if (context.mounted) {
      ref.read(scannerNotifierProvider.notifier).processEdgeCameraScan();
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _qrController?.toggleTorch();
    } catch (_) {}
    if (context.mounted) {
      setState(() {});
    }
  }


  Future<void> _saveAndPreview(ScanSuccess state) async {
    if (!context.mounted || _isSavingPreview) return;
    _isSavingPreview = true;
    try {
      try {
        await _qrController?.stop();
      } catch (_) {}

      final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null ||
          context.findAncestorWidgetOfExactType<ProviderScope>() != null;
      final contactVm = hasScope
          ? ProviderScope.containerOf(context, listen: false).read(contactViewModelProvider)
          : legacy.Provider.of<ContactViewModel>(context, listen: false);
      final contactProvider = hasScope
          ? ProviderScope.containerOf(context, listen: false).read(contactProviderRiverpod)
          : legacy.Provider.of<ContactProvider>(context, listen: false);
      await contactVm.recordScan();

      try {
        final profileVm = hasScope
            ? ProviderScope.containerOf(context, listen: false).read(profileViewModelProvider)
            : legacy.Provider.of<ProfileViewModel>(context, listen: false);
        final uid = profileVm.user?.id;
        if (uid != null && uid.isNotEmpty) {
          profileVm.incrementScanCount(uid);
        }
      } catch (_) {}

      final duplicateCheck = contactVm.checkCardDuplicate(
        state.contact,
        phoneContacts: contactProvider.contacts,
      );

      final bool isDuplicateFound = (duplicateCheck.isDuplicate ||
          duplicateCheck.isSameNumberDifferentCard ||
          duplicateCheck.existingContact != null) &&
          duplicateCheck.existingContact != null;

      // When duplicate phone/contact is detected, show the 10-second transparent popup with the big swipe button
      if (isDuplicateFound && mounted) {
        final action = await DuplicateScanPopupDialog.show(
          context: context,
          incoming: state.contact,
          existing: duplicateCheck.existingContact!,
        );

        if (!mounted) return;

        if (action == DuplicateScanAction.update) {
          final saved = await Navigator.of(context).push(
            TopToBottomSlideRoute(
              page: ContactPreviewScreen(
                contact: state.contact,
                existingContact: duplicateCheck.existingContact,
                imagePath: state.imagePath,
              ),
            ),
          );
          if (saved == true && mounted) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            } else {
              ref.read(tabIndexProvider.notifier).setIndex(4);
              _dashboardViewModel?.setIndex(4);
            }
            return;
          }
          _resetQrScanner();
        } else if (action == DuplicateScanAction.exit) {
          _resetQrScanner();
          ref.read(tabIndexProvider.notifier).setIndex(0);
          _dashboardViewModel?.setIndex(0);
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // Continue Scan: close alert, keep scanner active, do not save duplicate
          _resetQrScanner();
        }
        return;
      }

      // Unique phone number -> open preview directly
      final saved = await Navigator.of(context).push(
        TopToBottomSlideRoute(
          page: ContactPreviewScreen(
            contact: state.contact,
            imagePath: state.imagePath,
          ),
        ),
      );
      if (saved == true && mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          _dashboardViewModel?.setIndex(4);
        }
        return;
      }
      _resetQrScanner();
    } finally {
      _isSavingPreview = false;
    }
  }

  void _resetQrScanner() {
    _lastQr = null;
    _isProcessingQr = false;
    _isSavingPreview = false;
    _cardLocked = false;
    _detectedCardRect = null;
    _lastCapturedImagePath = null;
    if (context.mounted) {
      setState(() {});
      ref.read(scannerNotifierProvider.notifier).resetScanState();
      _handleCameraLifecycle();
    }
  }

  // â”€â”€â”€ Save Result Snackbar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showSaveResultSnackBar(ScanSaveResult result) {
    debugPrint('ðŸ“£ [UI] Showing save result: ${result.statusMessage}');

    final bothSaved = result.phoneSaved && result.apiSaved;
    final bothFailed = !result.phoneSaved && !result.apiSaved;

    final Color bgColor = bothSaved
        ? const Color(0xFF1B5E20)   // dark green
        : bothFailed
            ? Colors.redAccent.shade700
            : const Color(0xFF5D4037); // dark orange-brown

    final IconData icon = bothSaved
        ? Icons.check_circle_outline
        : bothFailed
            ? Icons.error_outline
            : Icons.warning_amber_outlined;

    // Build detail lines
    final lines = <String>[result.statusMessage];
    if (!result.phoneSaved && result.phoneError != null) {
      lines.add('â€¢ Phone: ${result.phoneError}');
    }
    if (!result.apiSaved && result.apiError != null) {
      lines.add('â€¢ SmartCard: ${result.apiError}');
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: bgColor,
          duration: const Duration(seconds: 5),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines
                      .map(
                        (l) => Text(
                          l,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: l == result.statusMessage
                                ? FontWeight.w600
                                : FontWeight.normal,
                            height: 1.4,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabIndexProvider, (previous, current) {
      _onTabChanged();
    });

    ref.listen<ScanState>(scannerNotifierProvider, (previous, state) async {
      if (state is ScanSuccess) {
        HapticFeedback.heavyImpact();
        await _saveAndPreview(state);
      } else if (state is ScanFailure) {
        _isProcessingQr = false;
        _lastQr = null;
        _handleCameraLifecycle();
        if (context.mounted) {
          if (state.error != 'Card scan cancelled') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
        }
      } else if (state is ScanTimeout) {
        _resetQrScanner();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.reason,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.deepOrange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else if (state is ScanSaveResult) {
        if (context.mounted) {
          _showSaveResultSnackBar(state);
          if (state.phoneSaved || state.apiSaved) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(true);
            } else {
              ref.read(tabIndexProvider.notifier).setIndex(4);
              _dashboardViewModel?.setIndex(4);
            }
          }
        }
      }
    });

    final state = ref.watch(scannerNotifierProvider);
    final processing = state is ScanProcessing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildScannerContent(context, state, processing),
    );
  }

  Widget _buildScannerContent(BuildContext context, ScanState state, bool processing) {
    if (!_permissionChecked) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5252)),
      );
    }

          if (!_hasPermission) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white38,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Camera & Contacts permission required',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _requestPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5252),
                      ),
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_qrController != null)
                MobileScanner(
                  controller: _qrController!,
                  fit: BoxFit.cover,
                  onDetect: processing ? null : _onQrDetect,
                  errorBuilder: (context, error) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera Error. Tap to retry.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
                            onPressed: () async {
                              try {
                                await _qrController?.start();
                              } catch (_) {}
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Live card tracking overlay with animated corner darts
              if (!processing)
                CardTrackerOverlay(
                  detectedRect: _detectedCardRect,
                  locked: _cardLocked,
                  onLocked: () {
                    // Auto-capture triggered by card lock-on
                    if (!_cardLocked && !_isProcessingQr) {
                      setState(() => _cardLocked = true);
                      HapticFeedback.heavyImpact();
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (context.mounted && !_isProcessingQr) {
                          _scanCardWithEdgeCamera();
                        }
                      });
                    }
                  },
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Point at QR for instant scan',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFF5252),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            GlassScannerButton(
                              icon: Icons.photo_library_outlined,
                              onTap: processing ? null : _pickGallery,
                            ),
                            GestureDetector(
                              onTap: processing
                                  ? null
                                  : () {
                                      HapticFeedback.mediumImpact();
                                      _scanCardWithEdgeCamera();
                                    },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _cardLocked ? Colors.greenAccent : const Color(0xFFFF5252),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_cardLocked ? Colors.greenAccent : const Color(0xFFFF5252)).withValues(alpha: 0.15),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _cardLocked ? Icons.check_circle_outline : Icons.document_scanner_outlined,
                                  color: Colors.black,
                                  size: 30,
                                ),
                              ),
                            ),
                            GlassScannerButton(
                              icon: _qrController?.value.torchState == TorchState.on
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              active: _qrController?.value.torchState == TorchState.on,
                              onTap: processing ? null : _toggleTorch,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (state is ScanProcessing)
                CardProcessingOverlay(
                  message: state.message,
                  imagePath: state.imagePath,
                ),
            ],
          );
  }
}

/// Custom Card Processing Overlay showing captured card image with laser scan sweep animation
class CardProcessingOverlay extends StatelessWidget {
  final String message;
  final String? imagePath;

  const CardProcessingOverlay({
    super.key,
    required this.message,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardWidth = size.width * 0.85;
    final cardHeight = cardWidth / 1.586;
    final hasFile = imagePath != null && imagePath!.isNotEmpty && File(imagePath!).existsSync();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card Frame with Laser Scan Animation over captured image
            Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFF5252), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasFile)
                    Image.file(
                      File(imagePath!),
                      fit: BoxFit.contain,
                    )
                  else
                    Container(
                      color: const Color(0xFF14142B),
                      child: const Center(
                        child: Icon(
                          Icons.credit_card_rounded,
                          size: 72,
                          color: Colors.white24,
                        ),
                      ),
                    ),

                  // Animated Scanning Laser Line Sweep across the card image
                  const ProcessingScanLine(),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Processing Message & Loading Spinner Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF5252),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart' as ml_barcode;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart' as ml_ocr;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../viewmodels/contact_viewmodel.dart';
import '../../viewmodels/theme_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../models/contact_model.dart';
import '../../models/scanned_contact_model.dart';
import '../../core/services/scanner_api_service.dart';
import '../../core/services/contact_saver_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/contact_parser.dart';
import '../../core/database/hive_database.dart';
import 'camera_scan_screen.dart';
import "package:edge_detection/edge_detection.dart";
import 'package:image_cropper/image_cropper.dart';
import 'qr_landing_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  late AnimationController _animationController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _opacityAnimation;

  bool _isProcessing = false;
  bool _isProcessingScan = false;
  bool _hasPermission = false;
  bool _permissionChecked = false;
  bool _isDisposed = false;
  String? _scannedData;
  ml_barcode.BarcodeScanner? _barcodeScanner;

  void _initScannerController() {
    if (_scannerController == null && !_isDisposed) {
      _scannerController = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
      );
    }

    if (_scannerController != null && _hasPermission && !_isDisposed) {
      _scannerController!.start().catchError((e) {
        debugPrint('Scanner start error: $e');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scanLineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.repeat(reverse: true);

    if (!kIsWeb) {
      _barcodeScanner = ml_barcode.BarcodeScanner(formats: [ml_barcode.BarcodeFormat.qrCode]);
    }

    _checkAndRequestPermission();
  }

  // ─── Gallery Permission Helper ──────────────────────────────────────────────

  /// Returns true if the app has sufficient gallery/photos permission.
  /// Requests it if needed; shows appropriate UI on denial.
  Future<bool> _requestGalleryPermission() async {
    if (kIsWeb) return true;

    // Android 13+ uses READ_MEDIA_IMAGES; older Android uses READ_EXTERNAL_STORAGE.
    Permission galleryPermission;
    if (defaultTargetPlatform == TargetPlatform.android) {
      // permission_handler maps this correctly per SDK version.
      galleryPermission = Permission.photos;
    } else {
      // iOS
      galleryPermission = Permission.photos;
    }

    PermissionStatus status = await galleryPermission.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    // Request the permission
    status = await galleryPermission.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (!context.mounted) return false;

    if (status.isPermanentlyDenied) {
      _showPermissionSettingsDialog(isGallery: true);
    } else {
      // Denied but not permanently — show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1E1E2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Colors.orangeAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gallery permission is required to select images.',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Allow',
            textColor: Colors.redAccent,
            onPressed: _requestGalleryPermission,
          ),
        ),
      );
    }

    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animationController.dispose();
    final controller = _scannerController;
    _scannerController = null;
    controller?.dispose();
    _barcodeScanner?.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (_isDisposed) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final controller = _scannerController;
      if (controller != null) {
        try { await controller.stop(); } catch (_) {}
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-check camera permission in case user granted it from App Settings
      if (!_hasPermission) {
        final status = await Permission.camera.status;
        if (status.isGranted && context.mounted) {
          setState(() {
            _hasPermission = true;
            _permissionChecked = true;
            _initScannerController();
          });
        }
      }
      final controller = _scannerController;
      if (_hasPermission && !_isProcessingScan && !_isDisposed && controller != null) {
        try { await controller.start(); } catch (_) {}
      }
    }
  }

  Future<void> _checkAndRequestPermission() async {
    if (kIsWeb) {
      setState(() {
        _hasPermission = true;
        _permissionChecked = true;
        _initScannerController();
      });
      return;
    }

    try {
      final cameraStatus = await Permission.camera.status;

      if (cameraStatus.isGranted) {
        setState(() {
          _hasPermission = true;
          _permissionChecked = true;
          _initScannerController();
        });
        return;
      }

      final status = await Permission.camera.request();
      if (context.mounted) {
        setState(() {
          _hasPermission = status.isGranted;
          _permissionChecked = true;
          if (status.isGranted) {
            _initScannerController();
          }
        });

        if (status.isPermanentlyDenied) {
          _showPermissionSettingsDialog();
        }
      }
    } catch (e) {
      debugPrint("Permission check error: $e");
      if (context.mounted) {
        setState(() {
          _permissionChecked = true;
          _hasPermission = false;
        });
      }
    }
  }

  /// Shows a dialog directing the user to App Settings.
  /// [isGallery] = true for gallery permission, false for camera.
  void _showPermissionSettingsDialog({bool isGallery = false}) {
    final icon = isGallery ? Icons.photo_library_outlined : Icons.videocam_outlined;
    final title = isGallery ? 'Gallery Access Required' : 'Camera Access Required';
    final message = isGallery
        ? 'Gallery permission has been permanently denied. Please enable "Photos" access for SmartCard in your device Settings.'
        : 'Camera permission has been permanently denied. Please enable "Camera" access for SmartCard in your device Settings.';

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
            Icon(icon, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Not Now',
              style: GoogleFonts.inter(color: Colors.white38),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.settings_outlined, size: 18, color: Colors.white),
            label: Text(
              'Open Settings',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDetect(BarcodeCapture capture) async {
    if (_isDisposed || _isProcessingScan || _scannerController == null) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty || code == _scannedData) return;

    if (!context.mounted) return;
    setState(() {
      _isProcessingScan = true;
      _scannedData = code;
    });

    try {
      await _scannerController!.stop();
    } catch (e) {
      debugPrint("Stop scanner error: $e");
    }

    if (!_isDisposed) _processQrCode(code);
  }

  Future<void> _processQrCode(String code) async {
    debugPrint('🔍 [QrScan] Processing QR value: $code');
    setState(() { _isProcessing = true; });
    final profileVm = context.read<ProfileViewModel>();

    ScannedContactModel? scanned;
    ContactModel? contact;

    // ── Step 1: Extract contact data (API preview → local fallback) ──────────
    try {
      debugPrint('📡 [QrScan] Calling preview API...');
      final extractedValue = _extractScValue(code);
      final response = await ScannerApiService.instance
          .previewContact({'qr_value': extractedValue})
          .timeout(const Duration(seconds: 10));
      debugPrint('📡 [QrScan] Preview API response: $response');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        contact = ContactModel(
          id: data['contact_user_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          name: (data['name'] ?? 'QR Contact').toString(),
          designation: (data['designation'] ?? '').toString(),
          companyName: (data['company'] ?? '').toString(),
          profileImageInitial: (data['name']?.toString().isNotEmpty == true)
              ? data['name'].toString().substring(0, 1).toLowerCase() : 'q',
          companyInitial: (data['company']?.toString().isNotEmpty == true)
              ? data['company'].toString().substring(0, 1).toLowerCase() : 'c',
          phone: data['phone']?.toString(),
          email: data['email']?.toString(),
          address: data['address']?.toString(),
          website: data['website']?.toString(),
          companyLogo: data['company_logo']?.toString() ?? data['logo']?.toString(),
          backgroundImage: data['background_image']?.toString() ?? data['bg_image']?.toString(),
          backgroundColor: data['bg_color']?.toString() ?? data['background_color']?.toString(),
          textColor: data['text_color']?.toString(),
          bgImageColor: data['bg_image_color']?.toString(),
          opacity: data['opacity']?.toString(),
          profileImageName: data['profile_image']?.toString() ?? data['image']?.toString(),
        );
        debugPrint('✅ [QrScan] API preview success: ${contact.name}');
      } else {
        throw Exception('API preview returned no data');
      }
    } on Exception catch (e) {
      debugPrint('⚠️ [QrScan] API preview failed ($e), using local parser.');
      try {
        scanned = ContactParser.parseQrCode(code);
        contact = ContactModel(
          id: scanned.id,
          name: scanned.name,
          designation: scanned.designation,
          companyName: scanned.company,
          profileImageInitial: scanned.name.isNotEmpty ? scanned.name[0].toLowerCase() : 'q',
          companyInitial: scanned.company.isNotEmpty ? scanned.company[0].toLowerCase() : 'c',
          phone: scanned.phone.isNotEmpty ? scanned.phone : null,
          email: scanned.email.isNotEmpty ? scanned.email : null,
          address: scanned.address.isNotEmpty ? scanned.address : null,
          website: scanned.website.isNotEmpty ? scanned.website : null,
        );
        debugPrint('✅ [QrScan] Local parse success: ${contact.name}');
      } on Exception catch (parseErr) {
        debugPrint('❌ [QrScan] Local parse also failed: $parseErr');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Invalid QR Code: could not extract contact data.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
          );
          _resetScanner();
        }
        if (context.mounted) setState(() { _isProcessing = false; });
        return;
      }
    }

    // Build ScannedContactModel if we don't have it yet
    scanned ??= ScannedContactModel(
      id: contact.id,
      name: contact.name,
      phone: contact.phone ?? '',
      email: contact.email ?? '',
      company: contact.companyName,
      designation: contact.designation,
      address: contact.address ?? '',
      website: contact.website ?? '',
      socialLinks: const [],
      createdAt: DateTime.now(),
      imagePath: contact.profileImageName,
      companyLogo: contact.companyLogo,
      backgroundImage: contact.backgroundImage,
      backgroundColor: contact.backgroundColor,
      textColor: contact.textColor,
      bgImageColor: contact.bgImageColor,
      opacity: contact.opacity,
    );

    // ── Step 2: Save to Hive + ViewModel (always, fast) ────────────────────
    debugPrint('💾 [QrScan] Saving to Hive...');
    await HiveDatabase.saveContact(scanned);
    if (context.mounted) {
      await context.read<ContactViewModel>().addScannedContact(scanned);
    }
    debugPrint('✅ [QrScan] Hive save complete.');
    debugPrint('🔁 [QrScan] Hive saved contact ID: ${contact.id}');

    // Show the landing page immediately — saves happen in the background
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrLandingScreen(
            contact: contact!,
            scannedContact: scanned!,
          ),
        ),
      ).then((_) {
        _resetScanner();
      });
    }

    // ── Step 3: Save to Phone contacts (independent) ─────────────────────
    bool phoneSaved = false;
    String? phoneError;
    try {
      debugPrint('📱 [QrScan] Requesting contacts permission...');
      final perm = await ContactSaverService.requestContactsPermission();
      debugPrint('📱 [QrScan] Contacts permission: $perm');
      if (perm) {
        phoneSaved = await ContactSaverService.saveToDevice(scanned);
        debugPrint('📱 [QrScan] Phone save result: $phoneSaved');
        debugPrint('🔁 [QrScan] Phone saved contact ID: ${contact.id}');
      } else {
        phoneError = 'Contacts permission denied';
        debugPrint('🚫 [QrScan] $phoneError');
      }
    } on Exception catch (e) {
      phoneError = e.toString().replaceFirst('Exception: ', '');
      debugPrint('🚨 [QrScan] Phone save error: $phoneError');
      debugPrint('🔁 [QrScan] Phone save failed for contact ID: ${contact.id}');
    }

    // ── Step 4: Save to SmartCard API (independent, with retry) ───────────
    bool apiSaved = false;
    String? apiError;
    
    // Check auth details and validate user id
    const storage = FlutterSecureStorage();
    String? userId = await storage.read(key: 'user_id');
    String? authToken = await storage.read(key: 'auth_token');
    
    if (userId == null || authToken == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        userId ??= prefs.getString('user_id');
        authToken ??= prefs.getString('auth_token');
      } catch (_) {}
    }
    
    debugPrint('🧑‍💻 [QrScan] Current logged-in user ID: $userId');
    debugPrint('🔐 [QrScan] Validation passed, proceeding to API save.');
    debugPrint('🔑 [QrScan] Authentication token: ${authToken != null ? "Present (${authToken.length} chars)" : "Missing"}');

    final extractedValue = _extractScValue(code);

    if (userId == null || userId.isEmpty || authToken == null || authToken.isEmpty) {
      apiError = 'Session expired. Please login again.';
      debugPrint('🚨 [QrScan] Validation failed: $apiError');
    } else {
      const maxRetries = 2;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('🌐 [QrScan] API save attempt $attempt/$maxRetries...');
          // Align payload exactly with backend database columns to prevent "Column count doesn't match value count" SQL error
          final payload = {
            'user_id': userId,
            'name': contact.name,
            'company': contact.companyName,
            'designation': contact.designation,
            'phone': contact.phone ?? '',
            'alternative_phone': '',
            'landline': '',
            'whatsapp': '',
            'email': contact.email ?? '',
            'website': contact.website ?? extractedValue,
            'address': contact.address ?? '',
            'pin_code': '',
            'social_links': '',
            'source': 'qr',
            'created_at': DateTime.now().toIso8601String(),
          };
          debugPrint('📤 [QrScan] API request payload: $payload');
          
          final apiResponse = await ScannerApiService.instance
              .saveContact(payload)
              .timeout(const Duration(seconds: 20));
          
          debugPrint('📥 [QrScan] API response body: $apiResponse');
          debugPrint('📥 [QrScan] API status code: ${apiResponse['status'] ?? "Success"}');
          apiSaved = true;
          debugPrint('✅ [QrScan] SmartCard API save succeeded.');
          profileVm.incrementScanCount(userId);
          break;
        } on Exception catch (e) {
          apiError = e.toString().replaceFirst('Exception: ', '');
          debugPrint('🚨 [QrScan] API attempt $attempt failed: $apiError');
          debugPrint('🔁 [QrScan] API save failed for contact ID: ${contact.id} on attempt $attempt');
          if (attempt < maxRetries) {
            debugPrint('🔄 [QrScan] Retrying in 2s...');
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
    }

    // ── Step 5: Show result snackbar with dual-save status ────────────────
    debugPrint('📊 [QrScan] Final — phone: $phoneSaved, api: $apiSaved');
    if (context.mounted) {
      final msg = phoneSaved && apiSaved
          ? 'Saved to Phone & SmartCard ✓'
          : phoneSaved && !apiSaved
              ? 'Saved to Phone. SmartCard sync failed.'
              : !phoneSaved && apiSaved
                  ? 'Saved to SmartCard. Phone save failed.'
                  : 'Saved locally. Phone & SmartCard sync failed.';

      final color = (phoneSaved && apiSaved)
          ? const Color(0xFF1B5E20)
          : (phoneSaved || apiSaved)
              ? const Color(0xFF5D4037)
              : Colors.redAccent.shade700;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: color,
            duration: const Duration(seconds: 5),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            content: Row(
              children: [
                Icon(
                  (phoneSaved && apiSaved) ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: Colors.white, size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    msg,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
    }

    if (context.mounted) setState(() { _isProcessing = false; });
  }

  // Future<void> _pickFromGallery() async {
  //   final picker = ImagePicker();
  //   final image = await picker.pickImage(source: ImageSource.gallery);

  //   if (image == null) return;

  //   setState(() {
  //     _isProcessing = true;
  //   });

  //   try {
  //     final inputImage = ml_barcode.InputImage.fromFilePath(image.path);
  //     final barcodes = await _barcodeScanner?.processImage(inputImage);

  //     if (barcodes != null && barcodes.isNotEmpty) {
  //       final qrValue = barcodes.first.rawValue ?? '';
  //       if (BusinessCardValidator.validateQr(qrValue)) {
  //         _processQrCode(qrValue);
  //         return;
  //       }
  //     }

  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           backgroundColor: Colors.redAccent,
  //           content: Text("No valid contact QR Code found in image.", style: TextStyle(color: Colors.white)),
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint("Gallery QR Scan error: $e");
  //   } finally {
  //     if (context.mounted) {
  //       setState(() {
  //         _isProcessing = false;
  //       });
  //     }
  //   }
  // }
  Future<void> _pickFromGallery() async {
    // ─── Step 1: Check & request gallery/photos permission ───────────────────
    final hasGalleryPermission = await _requestGalleryPermission();
    if (!hasGalleryPermission) return;

    // ─── Step 2: Proceed with image picking ──────────────────────────────────
    setState(() {
      _isProcessing = true;
    });

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // =========================
      // AUTO EDGE DETECTION
      // =========================

      final detected = await EdgeDetection.detectEdge(
        pickedFile.path,
        canUseGallery: false,
      );

      if (!detected) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text("Edge detection failed", style: TextStyle(color: Colors.white)),
            ),
          );
        }
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final detectedPath = "${pickedFile.path}_detected.jpg";

      // =========================
      // MANUAL CROP SUPPORT
      // =========================

      final croppedImage = await ImageCropper().cropImage(
        sourcePath: detectedPath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Adjust Card',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Adjust Card',
          ),
        ],
      );

      if (croppedImage == null) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // =========================
      // QR AUTO DETECTION
      // =========================

      final inputImage =
      ml_barcode.InputImage.fromFilePath(croppedImage.path);

      final barcodes =
      await _barcodeScanner?.processImage(inputImage);

      // =========================
      // AUTO QR EXTRACTION
      // =========================

      if (barcodes != null && barcodes.isNotEmpty) {

        final qrValue = barcodes.first.rawValue ?? '';

        debugPrint("QR DETECTED => $qrValue");

        if (qrValue.isNotEmpty) {

          // AUTO API FLOW
          await _processQrCode(qrValue);

          setState(() {
            _isProcessing = false;
          });

          return;
        }
      }

      // =========================
      // OCR TEXT EXTRACTION
      // =========================

      final textRecognizer =
      ml_ocr.TextRecognizer(script: ml_ocr.TextRecognitionScript.latin);

      final recognizedText =
      await textRecognizer.processImage(inputImage);

      final extractedText = recognizedText.text;

      debugPrint("OCR TEXT => $extractedText");

      await textRecognizer.close();

      // =========================
      // AUTO CONTACT EXTRACTION
      // =========================

      final phoneRegex =
      RegExp(r'(\+?\d[\d -]{8,}\d)');

      final emailRegex =
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');

      final websiteRegex =
      RegExp(r'(https?:\/\/[^\s]+)|(www\.[^\s]+)');

      String phone = '';
      String email = '';
      String website = '';

      final phoneMatch = phoneRegex.firstMatch(extractedText);
      final emailMatch = emailRegex.firstMatch(extractedText);
      final websiteMatch = websiteRegex.firstMatch(extractedText);

      if (phoneMatch != null) {
        phone = phoneMatch.group(0) ?? '';
      }

      if (emailMatch != null) {
        email = emailMatch.group(0) ?? '';
      }

      if (websiteMatch != null) {
        website = websiteMatch.group(0) ?? '';
      }

      List<String> lines =
      extractedText.split('\n');

      String name = '';
      String company = '';

      if (lines.isNotEmpty) {
        name = lines.first.trim();
      }

      if (lines.length > 1) {
        company = lines[1].trim();
      }

      // =========================
      // AUTO DATABASE SAVE
      // =========================

      final scanned = ScannedContactModel(
        id: DateTime.now()
            .millisecondsSinceEpoch
            .toString(),
        name: name,
        phone: phone,
        email: email,
        company: company,
        designation: '',
        address: '',
        website: website,
        socialLinks: const [],
        createdAt: DateTime.now(),
      );

      await HiveDatabase.saveContact(scanned);

      if (context.mounted) {
        await context
            .read<ContactViewModel>()
            .addScannedContact(scanned);
      }

      final contact = ContactModel(
        id: scanned.id,
        name: scanned.name,
        designation: scanned.designation,
        companyName: scanned.company,
        profileImageInitial:
        scanned.name.isNotEmpty
            ? scanned.name[0].toLowerCase()
            : 'c',
        companyInitial:
        scanned.company.isNotEmpty
            ? scanned.company[0].toLowerCase()
            : 'b',
        phone: scanned.phone,
        email: scanned.email,
        address: scanned.address,
        website: scanned.website,
      );

      // =========================
      // AUTO SHOW RESULT
      // =========================

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QrLandingScreen(
              contact: contact,
              scannedContact: scanned,
            ),
          ),
        ).then((_) {
          _resetScanner();
        });
      }

    } catch (e) {

      debugPrint("EDGE DETECTION ERROR => $e");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              "Business card not detected",
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      }

    } finally {

      if (context.mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _resetScanner() async {
    if (!context.mounted || _isDisposed) return;
    setState(() {
      _isProcessingScan = false;
      _scannedData = null;
    });
    if (_scannerController != null && _hasPermission && !_isDisposed) {
      try { await _scannerController!.start(); } catch (_) {}
    }
  }

  void _showContactDetails(ContactModel contact, bool phoneSaved, bool apiSaved) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.redAccent,
                    size: 64,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  "QR Contact Saved!",
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // ── Dual-Save Status Chips ───────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _SaveChip(
                    label: 'Phone',
                    icon: Icons.phone_android_outlined,
                    saved: phoneSaved,
                  ),
                  const SizedBox(width: 10),
                  const _SaveChip(
                    label: 'SmartCard',
                    icon: Icons.cloud_outlined,
                    saved: apiSaved,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const _ContactField(label: "Name", value: contact.name, icon: Icons.person),
              if (contact.companyName.isNotEmpty) const _ContactField(label: "Company", value: contact.companyName, icon: Icons.business),
              if (contact.designation.isNotEmpty) const _ContactField(label: "Designation", value: contact.designation, icon: Icons.work),
              if (contact.phone != null && contact.phone!.isNotEmpty) const _ContactField(label: "Phone", value: contact.phone!, icon: Icons.phone),
              if (contact.email != null && contact.email!.isNotEmpty) const _ContactField(label: "Email", value: contact.email!, icon: Icons.email),
              if (contact.address != null && contact.address!.isNotEmpty) const _ContactField(label: "Address", value: contact.address!, icon: Icons.location_on),
              if (contact.website != null && contact.website!.isNotEmpty) const _ContactField(label: "Website", value: contact.website!, icon: Icons.public),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          final shareText = _buildShareText(contact);
                          Share.share(shareText);
                        },
                        icon: const Icon(Icons.share, color: Colors.redAccent, size: 20),
                        label: Text(
                          "Share Contact",
                          style: GoogleFonts.inter(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _resetScanner();
                  },
                  child: Text(
                    "Scan Again",
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  String _buildShareText(ContactModel contact) {
    final buffer = StringBuffer();
    buffer.writeln("📇 ${contact.name}");
    if (contact.companyName.isNotEmpty) buffer.writeln("🏢 ${contact.companyName}");
    if (contact.designation.isNotEmpty) buffer.writeln("💼 ${contact.designation}");
    if (contact.phone != null && contact.phone!.isNotEmpty) buffer.writeln("📱 ${contact.phone}");
    if (contact.email != null && contact.email!.isNotEmpty) buffer.writeln("📧 ${contact.email}");
    if (contact.address != null && contact.address!.isNotEmpty) buffer.writeln("📍 ${contact.address}");
    if (contact.website != null && contact.website!.isNotEmpty) buffer.writeln("🌐 ${contact.website}");
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeViewModel>().colors;
    final size = MediaQuery.of(context).size;
    final padding = size.width < 360 ? 16.0 : 24.0;
    final cardWidth = (size.width - padding * 2) * 0.90;
    final cardHeight = cardWidth; // Square scan viewport window for QR code

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Card Scanner",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (!_permissionChecked)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                else if (!_hasPermission)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.videocam_off_outlined, color: Colors.white30, size: 80),
                        const SizedBox(height: 24),
                        Text(
                          "Camera Permission Required",
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            "Please grant camera access to scan QR codes on business cards.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _checkAndRequestPermission,
                          child: Text(
                            "Grant Permission",
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Center(
                    child: Container(
                      width: cardWidth,
                      height: cardHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final scanWindow = Rect.fromCenter(
                              center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
                              width: cardWidth,
                              height: cardHeight,
                            );

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                if (_scannerController != null)
                                  MobileScanner(
                                    controller: _scannerController!,
                                    fit: BoxFit.cover,
                                    scanWindow: scanWindow,
                                    onDetect: _handleDetect,
                                    errorBuilder: (context, error) {
                                      return Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.error_outline, color: Colors.white54, size: 40),
                                            const SizedBox(height: 16),
                                            Text(
                                              'Camera Error. Tap to retry.',
                                              style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              onPressed: () async {
                                                try {
                                                  await _scannerController?.start();
                                                } catch (e) {
                                                  debugPrint("Retry start error: $e");
                                                }
                                              },
                                              child: const Text('Retry'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),

                                // Glowing Green/Red Scan Laser
                                Center(
                                  child: SizedBox(
                                    width: cardWidth,
                                    height: cardHeight,
                                    child: AnimatedBuilder(
                                      animation: _animationController,
                                      builder: (context, child) => Stack(
                                        children: [
                                          Positioned(
                                            top: _scanLineAnimation.value * cardHeight,
                                            left: 16,
                                            right: 16,
                                            child: FadeTransition(
                                              opacity: _opacityAnimation,
                                              child: Container(
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.redAccent.withValues(alpha: 0.15),
                                                      Colors.redAccent,
                                                      Colors.redAccent.withValues(alpha: 0.15),
                                                      Colors.transparent,
                                                    ],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.redAccent.withValues(alpha: 0.15),
                                                      blurRadius: 10,
                                                      spreadRadius: 2,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Custom Paint Frame Overlay
                                CustomPaint(
                                  painter: ProfessionalOverlayPainter(
                                    color: Colors.redAccent,
                                    radius: 28,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Colors.redAccent),
                              const SizedBox(height: 24),
                              Text(
                                "AI Extraction Engine...",
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Reading QR metadata details",
                                style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_hasPermission || kIsWeb)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              color: Colors.transparent,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: const _ActionButton(
                        icon: Icons.photo_library_outlined,
                        label: "Gallery",
                        onTap: _pickFromGallery,
                        isPrimary: false,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: const _ActionButton(
                        icon: Icons.camera_outlined,
                        label: "Card Scan",
                        onTap: () {
                          // Route business card requests to SmartScannerScreen
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SmartScannerScreen()),
                          );
                        },
                        isPrimary: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

}

class ProfessionalOverlayPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double cardWidth;
  final double cardHeight;

  ProfessionalOverlayPainter({
    required this.color,
    required this.radius,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: cardWidth,
      height: cardHeight,
    );

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      borderPaint,
    );

    final cornerSize = 24.0;
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final topLeft = rect.topLeft;
    final topRight = rect.topRight;
    final bottomLeft = rect.bottomLeft;
    final bottomRight = rect.bottomRight;

    final path = Path()
    // Top Left Corner
      ..moveTo(topLeft.dx, topLeft.dy + cornerSize)
      ..lineTo(topLeft.dx, topLeft.dy)
      ..lineTo(topLeft.dx + cornerSize, topLeft.dy)
    // Top Right Corner
      ..moveTo(topRight.dx - cornerSize, topRight.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(topRight.dx, topRight.dy + cornerSize)
    // Bottom Left Corner
      ..moveTo(bottomLeft.dx, bottomLeft.dy - cornerSize)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomLeft.dx + cornerSize, bottomLeft.dy)
    // Bottom Right Corner
      ..moveTo(bottomRight.dx - cornerSize, bottomRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy - cornerSize);

    canvas.drawPath(path, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

String _extractScValue(String qrValue) {
  try {
    final trimmed = qrValue.trim();
    final uri = Uri.parse(trimmed);
    if (uri.queryParameters.containsKey('sc')) {
      return uri.queryParameters['sc']!;
    }
  } catch (_) {}
  return qrValue.trim();
}

class _ContactField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ContactField({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.redAccent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool saved;

  const _SaveChip({
    super.key,
    required this.label,
    required this.icon,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    final color = saved ? const Color(0xFF2E7D32) : const Color(0xFF5D4037);
    final iconColor = saved ? const Color(0xFF81C784) : Colors.orangeAccent;
    final textColor = saved ? const Color(0xFF81C784) : Colors.orangeAccent;
    final statusIcon = saved ? Icons.check_circle_outline : Icons.sync_problem_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(statusIcon, color: iconColor, size: 13),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isPrimary ? Colors.redAccent : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? Colors.transparent : Colors.white10),
        boxShadow: isPrimary
            ? [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

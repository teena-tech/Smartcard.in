import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/scan_type.dart';
import '../models/scanner_state.dart';
import '../models/detected_card.dart';
import '../models/qr_result.dart';
import '../../../models/scanned_contact_model.dart';
import '../services/card_detection_service.dart';
import '../services/ocr_service.dart';
import '../services/contact_parser_service.dart';
import '../services/image_processing_service.dart';
import '../services/qr_scanner_service.dart';

class ScannerController extends ChangeNotifier {
  ScanType _scanType = ScanType.businessCard;
  ScannerStateEnum _state = ScannerStateEnum.searching;

  DetectedCard? _detectedCard;
  double _stabilityProgress = 0.0;
  bool _isAutoCapturing = false;
  String? _lastCapturedImagePath;

  ScannedContactModel? _parsedContact;
  QrResult? _qrResult;

  final CardDetectionService _cardDetector = CardDetectionService();
  final OcrService _ocrService = OcrService();
  final ContactParserService _contactParser = ContactParserService();
  final ImageProcessingService _imageProcessor = ImageProcessingService();
  final QrScannerService _qrScanner = QrScannerService();

  // Getters
  ScanType get scanType => _scanType;
  ScannerStateEnum get state => _state;
  DetectedCard? get detectedCard => _detectedCard;
  double get stabilityProgress => _stabilityProgress;
  bool get isAutoCapturing => _isAutoCapturing;
  String? get lastCapturedImagePath => _lastCapturedImagePath;
  ScannedContactModel? get parsedContact => _parsedContact;
  QrResult? get qrResult => _qrResult;

  void setScanType(ScanType type) {
    if (_scanType == type) return;
    _scanType = type;
    reset();
  }

  void updateDetectedCard(DetectedCard? card) {
    if (_isAutoCapturing || _state == ScannerStateEnum.processing) return;

    _detectedCard = card;
    if (card != null) {
      _stabilityProgress = _cardDetector.calculateProgress(card.stabilityCounter);
      _state = _cardDetector.evaluateState(card);

      if (card.isStable && !_isAutoCapturing) {
        _triggerAutoCapture();
      }
    } else {
      _stabilityProgress = 0.0;
      _state = ScannerStateEnum.searching;
    }
    notifyListeners();
  }

  Future<void> _triggerAutoCapture() async {
    _isAutoCapturing = true;
    _state = ScannerStateEnum.stable;
    notifyListeners();

    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 350));

    _state = ScannerStateEnum.capturing;
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  Future<ScannedContactModel?> processCapturedImagePath(String imagePath) async {
    _lastCapturedImagePath = imagePath;
    _state = ScannerStateEnum.processing;
    notifyListeners();

    try {
      // Step 1: Automatically detect card edges, calculate crop box & enhance contrast
      final cleanedImagePath = await _imageProcessor.autoDetectCardAndCrop(imagePath);

      // Step 2: OCR recognition
      final rawText = await _ocrService.recognizeTextFromPath(cleanedImagePath);

      // Step 3: Parse contact details
      _parsedContact = _contactParser.parseText(
        rawText,
        imagePath: cleanedImagePath,
        source: 'business_card_scanner',
      );

      _state = ScannerStateEnum.ocrComplete;
      notifyListeners();
      return _parsedContact;
    } catch (e) {
      debugPrint('Error processing captured image: $e');
      _state = ScannerStateEnum.failure;
      notifyListeners();
      return null;
    } finally {
      _isAutoCapturing = false;
    }
  }

  void handleQrDetected(String rawPayload) {
    if (_state == ScannerStateEnum.processing || _state == ScannerStateEnum.success) return;

    final result = _qrScanner.processRawQrCode(rawPayload);
    if (result != null) {
      _qrResult = result;
      _state = ScannerStateEnum.success;
      HapticFeedback.mediumImpact();
      notifyListeners();
    }
  }

  void reset() {
    _state = ScannerStateEnum.searching;
    _detectedCard = null;
    _stabilityProgress = 0.0;
    _isAutoCapturing = false;
    _lastCapturedImagePath = null;
    _parsedContact = null;
    _qrResult = null;
    _cardDetector.reset();
    _qrScanner.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _imageProcessor.dispose();
    super.dispose();
  }
}

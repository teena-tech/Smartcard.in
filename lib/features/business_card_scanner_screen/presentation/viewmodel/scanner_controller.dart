import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scan_type.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/scanner_state.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/detected_card.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/qr_result.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/card_detection_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/ocr_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/contact_parser_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/image_processing_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/qr_scanner_service.dart';

@immutable
class ScannerUiState {
  final ScanType scanType;
  final ScannerStateEnum state;
  final DetectedCard? detectedCard;
  final double stabilityProgress;
  final bool isAutoCapturing;
  final String? lastCapturedImagePath;
  final ScannedContactModel? parsedContact;
  final QrResult? qrResult;

  const ScannerUiState({
    this.scanType = ScanType.businessCard,
    this.state = ScannerStateEnum.searching,
    this.detectedCard,
    this.stabilityProgress = 0.0,
    this.isAutoCapturing = false,
    this.lastCapturedImagePath,
    this.parsedContact,
    this.qrResult,
  });

  ScannerUiState copyWith({
    ScanType? scanType,
    ScannerStateEnum? state,
    DetectedCard? detectedCard,
    double? stabilityProgress,
    bool? isAutoCapturing,
    String? lastCapturedImagePath,
    ScannedContactModel? parsedContact,
    QrResult? qrResult,
    bool clearDetectedCard = false,
    bool clearParsedContact = false,
    bool clearQrResult = false,
    bool clearCapturedImage = false,
  }) {
    return ScannerUiState(
      scanType: scanType ?? this.scanType,
      state: state ?? this.state,
      detectedCard: clearDetectedCard ? null : (detectedCard ?? this.detectedCard),
      stabilityProgress: stabilityProgress ?? this.stabilityProgress,
      isAutoCapturing: isAutoCapturing ?? this.isAutoCapturing,
      lastCapturedImagePath: clearCapturedImage ? null : (lastCapturedImagePath ?? this.lastCapturedImagePath),
      parsedContact: clearParsedContact ? null : (parsedContact ?? this.parsedContact),
      qrResult: clearQrResult ? null : (qrResult ?? this.qrResult),
    );
  }
}

class ScannerController extends Notifier<ScannerUiState> {
  final CardDetectionService _cardDetector = CardDetectionService();
  final OcrService _ocrService = OcrService();
  final ContactParserService _contactParser = ContactParserService();
  final ImageProcessingService _imageProcessor = ImageProcessingService();
  final QrScannerService _qrScanner = QrScannerService();

  @override
  ScannerUiState build() {
    ref.onDispose(() {
      _ocrService.dispose();
      _imageProcessor.dispose();
    });
    return const ScannerUiState();
  }

  // Getters for convenience
  ScanType get scanType => state.scanType;
  ScannerStateEnum get scannerState => state.state;
  DetectedCard? get detectedCard => state.detectedCard;
  double get stabilityProgress => state.stabilityProgress;
  bool get isAutoCapturing => state.isAutoCapturing;
  String? get lastCapturedImagePath => state.lastCapturedImagePath;
  ScannedContactModel? get parsedContact => state.parsedContact;
  QrResult? get qrResult => state.qrResult;

  void setScanType(ScanType type) {
    if (state.scanType == type) return;
    state = state.copyWith(scanType: type);
    reset();
  }

  void updateDetectedCard(DetectedCard? card) {
    if (state.isAutoCapturing || state.state == ScannerStateEnum.processing) return;

    if (card != null) {
      final progress = _cardDetector.calculateProgress(card.stabilityCounter);
      final evalState = _cardDetector.evaluateState(card);

      state = state.copyWith(
        detectedCard: card,
        stabilityProgress: progress,
        state: evalState,
      );

      if (card.isStable && !state.isAutoCapturing) {
        _triggerAutoCapture();
      }
    } else {
      state = state.copyWith(
        clearDetectedCard: true,
        stabilityProgress: 0.0,
        state: ScannerStateEnum.searching,
      );
    }
  }

  Future<void> _triggerAutoCapture() async {
    state = state.copyWith(
      isAutoCapturing: true,
      state: ScannerStateEnum.stable,
    );

    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 350));

    state = state.copyWith(
      state: ScannerStateEnum.capturing,
    );
    HapticFeedback.heavyImpact();
  }

  Future<ScannedContactModel?> processCapturedImagePath(String imagePath) async {
    state = state.copyWith(
      lastCapturedImagePath: imagePath,
      state: ScannerStateEnum.processing,
    );

    try {
      final cleanedImagePath = await _imageProcessor.autoDetectCardAndCrop(imagePath);
      final rawText = await _ocrService.recognizeTextFromPath(cleanedImagePath);
      final parsed = _contactParser.parseText(
        rawText,
        imagePath: cleanedImagePath,
        source: 'business_card_scanner',
      );

      state = state.copyWith(
        parsedContact: parsed,
        state: ScannerStateEnum.ocrComplete,
        isAutoCapturing: false,
      );
      return parsed;
    } catch (e) {
      debugPrint('Error processing captured image: $e');
      state = state.copyWith(
        state: ScannerStateEnum.failure,
        isAutoCapturing: false,
      );
      return null;
    }
  }

  void handleQrDetected(String rawPayload) {
    if (state.state == ScannerStateEnum.processing || state.state == ScannerStateEnum.success) return;

    final result = _qrScanner.processRawQrCode(rawPayload);
    if (result != null) {
      HapticFeedback.mediumImpact();
      state = state.copyWith(
        qrResult: result,
        state: ScannerStateEnum.success,
      );
    }
  }

  void reset() {
    _cardDetector.reset();
    _qrScanner.reset();
    state = const ScannerUiState();
  }
}

final scannerControllerProvider =
    NotifierProvider<ScannerController, ScannerUiState>(ScannerController.new);

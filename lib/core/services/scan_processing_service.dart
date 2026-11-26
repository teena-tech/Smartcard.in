import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/utils/business_card_validator.dart';
import 'package:smartcard_flutter/core/utils/contact_parser.dart';
import 'package:smartcard_flutter/core/services/edge_detection_service.dart';
import 'package:smartcard_flutter/core/services/qr_extraction_service.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/datasources/image_processing_service.dart';

class ScanProcessingResult {
  final ScannedContactModel contact;
  final String? imagePath;
  final bool fromQr;

  const ScanProcessingResult({
    required this.contact,
    this.imagePath,
    this.fromQr = false,
  });
}

class ScanProcessingService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final MobileScannerController _barcodeScanner = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
  );

  Future<void> dispose() async {
    await _textRecognizer.close();
    if (_barcodeScanner.value.isRunning) {
      await _barcodeScanner.dispose();
    }
  }

  Rect? _barcodeBoundingBox(Barcode barcode) {
    if (barcode.corners.isNotEmpty) {
      double minX = barcode.corners.first.dx;
      double minY = barcode.corners.first.dy;
      double maxX = minX;
      double maxY = minY;
      for (final p in barcode.corners.skip(1)) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
      if (maxX > minX && maxY > minY) {
        return Rect.fromLTRB(minX, minY, maxX, maxY);
      }
    }
    return null;
  }

  Future<ScanProcessingResult> processImage({
    required String imagePath,
    bool manualEdgeAdjust = false,
    bool fromGallery = false,
    double? screenWidth,
    double? screenHeight,
    double? frameWidth,
    double? frameHeight,
  }) async {
    List<Barcode> barcodes = const [];
    try {
      final capture = await _barcodeScanner.analyzeImage(
        imagePath,
        formats: const [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
      );
      barcodes = capture?.barcodes ?? const [];
    } catch (e) {
      debugPrint('⚠️ Barcode scanning plugin unavailable/error: $e');
    }

    if (barcodes.isNotEmpty) {
      final qrValue = (barcodes.first.rawValue ?? '').toString();
      if (qrValue.isNotEmpty && BusinessCardValidator.validateQr(qrValue)) {
        final contact = await QrExtractionService.extract(qrValue);
        final cropped = await EdgeDetectionService.processImage(
          imagePath,
          manualAdjust: manualEdgeAdjust,
          fromGallery: fromGallery,
          textBoundingBox: _barcodeBoundingBox(barcodes.first),
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          screenWidth: screenWidth,
          screenHeight: screenHeight,
        );
        return ScanProcessingResult(
          contact: contact.copyWith(imagePath: cropped),
          imagePath: cropped,
          fromQr: true,
        );
      }
    }

    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text.trim();

    Rect? textBBox;
    double? left, top, right, bottom;
    for (final block in recognizedText.blocks) {
      final rect = block.boundingBox;
      if (left == null || rect.left < left) left = rect.left;
      if (top == null || rect.top < top) top = rect.top;
      if (right == null || rect.right > right) right = rect.right;
      if (bottom == null || rect.bottom > bottom) bottom = rect.bottom;
    }
    if (left != null && top != null && right != null && bottom != null) {
      textBBox = Rect.fromLTRB(left, top, right, bottom);
    }

    String? cropped;
    try {
      cropped = await ImageProcessingService().autoDetectCardAndCrop(imagePath);
    } catch (e) {
      debugPrint('ImageProcessingService quad crop fallback: $e');
      cropped = await EdgeDetectionService.processImage(
        imagePath,
        manualAdjust: manualEdgeAdjust,
        fromGallery: fromGallery,
        textBoundingBox: textBBox,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
    }

    if (cropped == null) {
      throw Exception('Edge detection cancelled');
    }

    if (BusinessCardValidator.validateText(rawText) || rawText.length >= 6) {
      final contact = ContactParser.parse(rawText).copyWith(imagePath: cropped);
      return ScanProcessingResult(contact: contact, imagePath: cropped);
    }

    if (barcodes.isNotEmpty) {
      final qrValue = (barcodes.first.rawValue ?? '').toString();
      if (qrValue.isNotEmpty) {
        final contact = await QrExtractionService.extract(qrValue);
        return ScanProcessingResult(
          contact: contact.copyWith(imagePath: cropped),
          imagePath: cropped,
          fromQr: true,
        );
      }
    }

    throw Exception('No business card or QR detected. Position card clearly and retry.');
  }

  Future<ScanProcessingResult> processQrString(String qrValue) async {
    final contact = await QrExtractionService.extract(qrValue);
    return ScanProcessingResult(contact: contact, fromQr: true);
  }

  Future<ScanProcessingResult> processFromEdgeCamera() async {
    final path = await EdgeDetectionService.scanFromCamera();
    if (path == null) throw Exception('Card scan cancelled');

    return processImage(imagePath: path, fromGallery: false);
  }
}

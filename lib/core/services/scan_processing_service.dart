import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../models/scanned_contact_model.dart';
import '../utils/business_card_validator.dart';
import '../utils/contact_parser.dart';
import 'edge_detection_service.dart';
import 'qr_extraction_service.dart';

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
  final BarcodeScanner _barcodeScanner = BarcodeScanner(
    formats: [BarcodeFormat.qrCode, BarcodeFormat.dataMatrix],
  );

  Future<void> dispose() async {
    await _textRecognizer.close();
    await _barcodeScanner.close();
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
    final inputImage = InputImage.fromFilePath(imagePath);

    final barcodes = await _barcodeScanner.processImage(inputImage);
    // Debug: log barcode detection results to help troubleshoot scanner issues
    try {
      if (barcodes.isNotEmpty) {
        for (final b in barcodes) {
          debugPrint('🔍 Barcode detected: format=${b.format}, value=${b.rawValue}, bbox=${b.boundingBox}');
        }
      } else {
        debugPrint('🔍 No barcodes detected in image: $imagePath');
      }
    } catch (e) {
      debugPrint('🔍 Barcode debug log error: $e');
    }
    if (barcodes.isNotEmpty) {
      final qrValue = barcodes.first.rawValue ?? '';
      if (qrValue.isNotEmpty && BusinessCardValidator.validateQr(qrValue)) {
        final contact = await QrExtractionService.extract(qrValue);
        final cropped = await EdgeDetectionService.processImage(
          imagePath,
          manualAdjust: manualEdgeAdjust,
          fromGallery: fromGallery,
          textBoundingBox: barcodes.first.boundingBox,
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

    final cropped = await EdgeDetectionService.processImage(
      imagePath,
      manualAdjust: manualEdgeAdjust,
      fromGallery: fromGallery,
      textBoundingBox: textBBox,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
    );

    if (cropped == null) {
      throw Exception('Edge detection cancelled');
    }

    if (BusinessCardValidator.validateText(rawText)) {
      final contact = ContactParser.parse(rawText).copyWith(imagePath: cropped);
      return ScanProcessingResult(contact: contact, imagePath: cropped);
    }

    if (barcodes.isNotEmpty) {
      final qrValue = barcodes.first.rawValue ?? '';
      if (qrValue.isNotEmpty) {
        final contact = await QrExtractionService.extract(qrValue);
        return ScanProcessingResult(
          contact: contact.copyWith(imagePath: cropped),
          imagePath: cropped,
          fromQr: true,
        );
      }
    }

    throw Exception('No business card or QR detected. Try manual edge adjust.');
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

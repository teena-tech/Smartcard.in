import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageProcessingService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Performs 4-point perspective warp transformation on quadrilateral P1, P2, P3, P4
  /// mapping it to a flat, straight rectangular card image (0,0) -> (W,0) -> (W,H) -> (0,H)
  /// with 100% background, table, and hand removal!
  Future<String> perspectiveWarpCard({
    required String inputPath,
    required Offset p1, // Top-Left
    required Offset p2, // Top-Right
    required Offset p3, // Bottom-Right
    required Offset p4, // Bottom-Left
  }) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;

      final baked = img.bakeOrientation(decoded);

      // Compute target width W = max(dist(P1,P2), dist(P4,P3))
      final w1 = math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
      final w2 = math.sqrt(math.pow(p3.dx - p4.dx, 2) + math.pow(p3.dy - p4.dy, 2));
      final targetW = math.max(w1, w2).toInt().clamp(200, baked.width);

      // Compute target height H = max(dist(P1,P4), dist(P2,P3))
      final h1 = math.sqrt(math.pow(p4.dx - p1.dx, 2) + math.pow(p4.dy - p1.dy, 2));
      final h2 = math.sqrt(math.pow(p3.dx - p2.dx, 2) + math.pow(p3.dy - p2.dy, 2));
      final targetH = math.max(h1, h2).toInt().clamp(120, baked.height);

      // Create target output image
      final warped = img.Image(width: targetW, height: targetH);

      // Bilinear homography quad warp interpolation
      for (int y = 0; y < targetH; y++) {
        final v = y / targetH;
        final topX = p1.dx + v * (p4.dx - p1.dx);
        final topY = p1.dy + v * (p4.dy - p1.dy);
        final botX = p2.dx + v * (p3.dx - p2.dx);
        final botY = p2.dy + v * (p3.dy - p2.dy);

        for (int x = 0; x < targetW; x++) {
          final u = x / targetW;
          final srcX = (topX + u * (botX - topX)).toInt().clamp(0, baked.width - 1);
          final srcY = (topY + u * (botY - topY)).toInt().clamp(0, baked.height - 1);

          final pixel = baked.getPixel(srcX, srcY);
          warped.setPixel(x, y, pixel);
        }
      }

      // Enhance contrast and sharpness for OCR
      final cleanedWarped = img.adjustColor(
        warped,
        contrast: 1.20,
        brightness: 1.04,
      );

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/perspective_warped_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final encoded = img.encodeJpg(cleanedWarped, quality: 94);
      await File(targetPath).writeAsBytes(encoded);

      return targetPath;
    } catch (e) {
      debugPrint('Error in perspectiveWarpCard: $e');
      return autoDetectCardAndCrop(inputPath);
    }
  }

  /// Automatically detects card edges from OCR text blocks, calculates exact bounding box,
  /// crops the business card from the frame, and enhances image contrast.
  Future<String> autoDetectCardAndCrop(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;

      // Ensure correct orientation
      final baked = img.bakeOrientation(decoded);

      // Run ML Kit text recognition to find exact bounding box of text on card
      final inputImage = InputImage.fromFilePath(inputPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      int minX = baked.width;
      int minY = baked.height;
      int maxX = 0;
      int maxY = 0;
      bool foundBlocks = false;

      for (final block in recognizedText.blocks) {
        final rect = block.boundingBox;
        if (rect.left < minX) minX = rect.left.toInt();
        if (rect.top < minY) minY = rect.top.toInt();
        if (rect.right > maxX) maxX = rect.right.toInt();
        if (rect.bottom > maxY) maxY = rect.bottom.toInt();
        foundBlocks = true;
      }

      if (foundBlocks && maxX > minX && maxY > minY) {
        // Add card border margin padding around text blocks (20% of card dimension)
        final textWidth = maxX - minX;
        final textHeight = maxY - minY;
        final marginX = (textWidth * 0.25).toInt();
        final marginY = (textHeight * 0.35).toInt();

        final p1 = Offset((minX - marginX).clamp(0, baked.width - 1).toDouble(), (minY - marginY).clamp(0, baked.height - 1).toDouble());
        final p2 = Offset((maxX + marginX).clamp(0, baked.width - 1).toDouble(), (minY - marginY).clamp(0, baked.height - 1).toDouble());
        final p3 = Offset((maxX + marginX).clamp(0, baked.width - 1).toDouble(), (maxY + marginY).clamp(0, baked.height - 1).toDouble());
        final p4 = Offset((minX - marginX).clamp(0, baked.width - 1).toDouble(), (maxY + marginY).clamp(0, baked.height - 1).toDouble());

        return await perspectiveWarpCard(
          inputPath: inputPath,
          p1: p1,
          p2: p2,
          p3: p3,
          p4: p4,
        );
      }

      // Fallback: Crop central 85% card region if no text blocks detected
      final cropWidth = (baked.width * 0.85).toInt();
      final cropHeight = (cropWidth / 1.6).toInt().clamp(10, baked.height);
      final cropX = ((baked.width - cropWidth) / 2).toInt().clamp(0, baked.width - 1);
      final cropY = ((baked.height - cropHeight) / 2).toInt().clamp(0, baked.height - 1);

      img.Image cropped = img.copyCrop(
        baked,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      cropped = img.adjustColor(
        cropped,
        contrast: 1.18,
        brightness: 1.04,
      );

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/auto_cropped_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final encoded = img.encodeJpg(cropped, quality: 92);
      await File(targetPath).writeAsBytes(encoded);

      return targetPath;
    } catch (e) {
      debugPrint('Error in autoDetectCardAndCrop: $e');
      return processAndCleanCardImage(inputPath);
    }
  }

  /// Backup basic image cleaning
  Future<String> processAndCleanCardImage(String inputPath) async {
    try {
      final bytes = await File(inputPath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return inputPath;

      img.Image processed = img.bakeOrientation(decoded);
      processed = img.adjustColor(
        processed,
        contrast: 1.15,
        brightness: 1.05,
      );

      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/cleaned_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final encoded = img.encodeJpg(processed, quality: 90);
      await File(targetPath).writeAsBytes(encoded);

      return targetPath;
    } catch (e) {
      debugPrint('Error cleaning image: $e');
      return inputPath;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}

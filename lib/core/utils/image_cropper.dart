import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ImageCropper {
  /// Crops a captured image based on the screen's alignment guide coordinates
  /// or a dynamic text bounding box coordinates from ML Kit.
  /// Maps screen dimensions to the actual high-resolution image size,
  /// crops the rectangle, compresses the result, and returns the cropped file path.
  static Future<String> cropBusinessCard({
    required String imagePath,
    required double screenWidth,
    required double screenHeight,
    required double cardWidth,
    required double cardHeight,
    Rect? textBoundingBox,
  }) async {
    // Capture the root isolate token BEFORE entering the background isolate.
    final rootToken = RootIsolateToken.instance!;

    return compute(_cropProcess, {
      'imagePath': imagePath,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'cardWidth': cardWidth,
      'cardHeight': cardHeight,
      'textBoundingBox': textBoundingBox != null 
          ? [textBoundingBox.left, textBoundingBox.top, textBoundingBox.width, textBoundingBox.height]
          : null,
      'rootToken': rootToken,
    });
  }

  /// Internal isolated process to prevent main thread blocking during image decoding/cropping.
  static Future<String> _cropProcess(Map<String, dynamic> params) async {
    // Initialize the background isolate's platform channel access
    final RootIsolateToken rootToken = params['rootToken'] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    final String imagePath = params['imagePath'];
    final double screenWidth = params['screenWidth'];
    final double screenHeight = params['screenHeight'];
    final double cardWidth = params['cardWidth'];
    final double cardHeight = params['cardHeight'];
    final List<double>? bboxList = params['textBoundingBox'] as List<double>?;

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Source image file does not exist at $imagePath');
    }

    // Read and decode the high-res captured image
    final bytes = await file.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) {
      throw Exception('Failed to decode captured image.');
    }

    // ==========================================
    // ADAPTIVE LOW-LIGHT ENHANCEMENT
    // Only boost brightness if the image is actually dark
    // ==========================================
    originalImage = _adaptiveEnhance(originalImage);

    // Determine target resolution coordinates
    final int imgWidth = originalImage.width;
    final int imgHeight = originalImage.height;

    // Bounds calculations
    int cropX, cropY, cropW, cropH;

    if (bboxList != null) {
      // The bounding box was detected in the original image space by ML Kit!
      final double bboxLeft = bboxList[0];
      final double bboxTop = bboxList[1];
      final double bboxWidth = bboxList[2];
      final double bboxHeight = bboxList[3];

      // Add a margin of 15% to prevent clipping edges
      final int marginW = (bboxWidth * 0.15).round();
      final int marginH = (bboxHeight * 0.15).round();

      cropX = (bboxLeft - marginW).round();
      cropY = (bboxTop - marginH).round();
      cropW = (bboxWidth + 2 * marginW).round();
      cropH = (bboxHeight + 2 * marginH).round();
    } else {
      // Calculate scaling factors mapping screen pixels to actual high-res pixels
      final double scaleX = imgWidth / screenWidth;
      final double scaleY = imgHeight / screenHeight;

      // Center coordinates calculations
      final double screenCenterX = screenWidth / 2;
      final double screenCenterY = screenHeight / 2;

      // Top-left bounds of alignment cutout relative to screen
      final double screenCardLeft = screenCenterX - (cardWidth / 2);
      final double screenCardTop = screenCenterY - (cardHeight / 2);

      // Map screen bounds to original high-res image coordinate system
      cropX = (screenCardLeft * scaleX).round();
      cropY = (screenCardTop * scaleY).round();
      cropW = (cardWidth * scaleX).round();
      cropH = (cardHeight * scaleY).round();
    }

    // Bounds safety checks
    if (cropX < 0) cropX = 0;
    if (cropY < 0) cropY = 0;
    if (cropX + cropW > imgWidth) cropW = imgWidth - cropX;
    if (cropY + cropH > imgHeight) cropH = imgHeight - cropY;

    // Guard against zero or negative dimensions
    if (cropW <= 0 || cropH <= 0) {
      cropX = 0;
      cropY = 0;
      cropW = imgWidth;
      cropH = imgHeight;
    }

    // Crop the card out of the original image
    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    // ==========================================
    // AUTO-STRAIGHTEN: Detect skew and correct
    // ==========================================
    croppedImage = _autoStraighten(croppedImage);

    // Resize the cropped image to a standardized optimized resolution (width: 1000px)
    final img.Image resizedImage = img.copyResize(croppedImage, width: 1000);

    // Compress the resized image to JPG (quality: 88)
    final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 88);

    // Save to local cache directory
    final tempDir = await getTemporaryDirectory();
    final String croppedPath =
        '${tempDir.path}/cropped_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final croppedFile = File(croppedPath);
    await croppedFile.writeAsBytes(compressedBytes);

    // Optionally delete original un-cropped photo to conserve space
    try {
      await file.delete();
    } catch (_) {}

    return croppedPath;
  }

  /// Resizes any given image file to an optimized standard resolution (width: 1000px).
  /// Replaces the source file with the resized version to conserve space.
  static Future<String> resizeToStandard(String path) async {
    final rootToken = RootIsolateToken.instance!;
    return compute(_resizeProcess, {'path': path, 'rootToken': rootToken});
  }

  static Future<String> _resizeProcess(Map<String, dynamic> params) async {
    final RootIsolateToken rootToken = params['rootToken'] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootToken);

    final String path = params['path'];
    final file = File(path);
    if (!await file.exists()) return path;

    final bytes = await file.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return path;

    // Apply adaptive enhancements for gallery images too
    originalImage = _adaptiveEnhance(originalImage);

    // Auto-straighten gallery images
    originalImage = _autoStraighten(originalImage);

    // Proportional downscale to 1000px width
    final img.Image resizedImage = img.copyResize(originalImage, width: 1000);

    final List<int> compressedBytes = img.encodeJpg(resizedImage, quality: 88);
    await file.writeAsBytes(compressedBytes);
    return path;
  }

  // ==========================================
  // ADAPTIVE ENHANCEMENT
  // Measures average luminance and only boosts dark images.
  // Prevents over-brightening well-lit cards.
  // ==========================================
  static img.Image _adaptiveEnhance(img.Image image) {
    // Sample pixels to estimate average brightness (fast sampling — every 50th pixel)
    double totalLuminance = 0;
    int sampledCount = 0;
    final int step = math.max(1, (image.width * image.height) ~/ 500);

    for (int i = 0; i < image.width * image.height; i += step) {
      final int x = i % image.width;
      final int y = i ~/ image.width;
      if (y >= image.height) break;

      final pixel = image.getPixel(x, y);
      // Standard luminance formula
      final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
      totalLuminance += lum;
      sampledCount++;
    }

    final double avgLuminance = sampledCount > 0 ? totalLuminance / sampledCount : 128.0;

    // Dark image: average luminance below 90 (out of 255)
    if (avgLuminance < 90) {
      image = img.adjustColor(
        image,
        brightness: 0.25,
        contrast: 1.4,
        saturation: 1.1,
      );
      // Sharpen to compensate for low-light blur
      image = img.convolution(image, filter: [
        0, -1,  0,
       -1,  5, -1,
        0, -1,  0,
      ]);
    } else if (avgLuminance < 140) {
      // Medium brightness: light enhancement only
      image = img.adjustColor(
        image,
        brightness: 0.08,
        contrast: 1.15,
      );
      // Subtle sharpen
      image = img.convolution(image, filter: [
        0, -0.5,  0,
       -0.5,  3, -0.5,
        0, -0.5,  0,
      ]);
    }
    // Bright images (avgLuminance >= 140): no processing needed — skip to save CPU

    return image;
  }

  // ==========================================
  // AUTO-STRAIGHTEN
  // Detects if the image is slightly tilted by analyzing
  // edge pixel distribution and corrects small rotations (< 15°).
  // ==========================================
  static img.Image _autoStraighten(img.Image image) {
    // Convert to grayscale for edge analysis
    final img.Image gray = img.grayscale(image);

    // Simple horizontal projection-based skew detection
    // Count dark pixels per row to find text line positions
    final List<int> rowCounts = List.filled(gray.height, 0);
    final int threshold = 128;

    for (int y = 0; y < gray.height; y++) {
      int count = 0;
      for (int x = 0; x < gray.width; x += 3) {
        final pixel = gray.getPixel(x, y);
        if (pixel.r < threshold) count++;
      }
      rowCounts[y] = count;
    }

    // Find dominant text lines (peaks in row histogram)
    final List<int> peaks = [];
    final int avgCount = rowCounts.fold(0, (a, b) => a + b) ~/ math.max(1, rowCounts.length);

    for (int y = 1; y < rowCounts.length - 1; y++) {
      if (rowCounts[y] > avgCount * 1.5 &&
          rowCounts[y] > rowCounts[y - 1] &&
          rowCounts[y] > rowCounts[y + 1]) {
        peaks.add(y);
      }
    }

    // If we detect at least 2 peaks, compute tilt angle
    if (peaks.length >= 2) {
      // Estimate skew by checking if left side and right side text starts differ
      // Use first and last text peak to compute angle
      final int topPeakY = peaks.first;
      final int bottomPeakY = peaks.last;

      // Find leftmost dark pixel on top and bottom peak rows
      int topLeftX = _findFirstDarkPixel(gray, topPeakY, threshold);
      int bottomLeftX = _findFirstDarkPixel(gray, bottomPeakY, threshold);

      if (topLeftX >= 0 && bottomLeftX >= 0) {
        final int dy = bottomPeakY - topPeakY;
        final int dx = bottomLeftX - topLeftX;

        if (dy > 0) {
          double angle = math.atan2(dx.toDouble(), dy.toDouble()) * (180.0 / math.pi);

          // Only correct small tilts (< 10 degrees) to avoid destroying content
          if (angle.abs() > 0.5 && angle.abs() < 10.0) {
            image = img.copyRotate(image, angle: -angle);
          }
        }
      }
    }

    return image;
  }

  /// Finds the x-coordinate of the first dark pixel in a given row.
  static int _findFirstDarkPixel(img.Image gray, int y, int threshold) {
    for (int x = 0; x < gray.width; x++) {
      final pixel = gray.getPixel(x, y);
      if (pixel.r < threshold) return x;
    }
    return -1;
  }
}

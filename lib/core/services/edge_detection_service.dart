import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Auto + optional manual business-card edge detection and perspective crop.
class EdgeDetectionService {
  /// Auto-detect → enhance → perspective correct → save.
  static Future<String> autoDetectAndCrop(
    String imagePath, {
    Rect? textBoundingBox,
    double? frameWidth,
    double? frameHeight,
    double? screenWidth,
    double? screenHeight,
  }) async {
    final rootToken = RootIsolateToken.instance!;
    return compute(_autoDetectIsolate, {
      'imagePath': imagePath,
      'textBoundingBox': textBoundingBox != null
          ? [
              textBoundingBox.left,
              textBoundingBox.top,
              textBoundingBox.width,
              textBoundingBox.height,
            ]
          : null,
      'frameWidth': frameWidth,
      'frameHeight': frameHeight,
      'screenWidth': screenWidth,
      'screenHeight': screenHeight,
      'rootToken': rootToken,
    });
  }

  /// Runs auto crop, then opens native manual edge UI if [manualAdjust] is true.
  static Future<String?> processImage(
    String imagePath, {
    bool manualAdjust = false,
    bool fromGallery = false,
    Rect? textBoundingBox,
    double? frameWidth,
    double? frameHeight,
    double? screenWidth,
    double? screenHeight,
  }) async {
    String processed;
    try {
      processed = await autoDetectAndCrop(
        imagePath,
        textBoundingBox: textBoundingBox,
        frameWidth: frameWidth,
        frameHeight: frameHeight,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
      );
    } catch (_) {
      processed = imagePath;
    }

    if (!manualAdjust) return processed;

    return manualAdjustEdges(
      processed,
      fromGallery: fromGallery,
    );
  }

  static Future<Directory?> _getSafeTempDir() async {
    if (kIsWeb) return null;
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      try {
        return Directory.systemTemp;
      } catch (_) {
        return null;
      }
    }
  }

  /// Manual edge UI fallback (returns sourcePath directly).
  static Future<String?> manualAdjustEdges(
    String sourcePath, {
    bool fromGallery = true,
  }) async {
    return sourcePath;
  }

  /// Camera capture fallback.
  static Future<String?> scanFromCamera() async {
    return null;
  }

  static Future<String> _autoDetectIsolate(Map<String, dynamic> params) async {
    BackgroundIsolateBinaryMessenger.ensureInitialized(
      params['rootToken'] as RootIsolateToken,
    );

    final imagePath = params['imagePath'] as String;
    final bboxList = params['textBoundingBox'] as List<double>?;
    final frameWidth = params['frameWidth'] as double?;
    final frameHeight = params['frameHeight'] as double?;
    final screenWidth = params['screenWidth'] as double?;
    final screenHeight = params['screenHeight'] as double?;

    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image not found: $imagePath');
    }

    final bytes = await file.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) throw Exception('Failed to decode image');

    image = _adaptiveEnhance(image);

    final corners = _findDocumentCorners(image, bboxList, frameWidth, frameHeight, screenWidth, screenHeight);

    img.Image output;
    if (corners != null) {
      output = _perspectiveCorrect(image, corners);
    } else {
      output = _rectCrop(image, bboxList, frameWidth, frameHeight, screenWidth, screenHeight);
    }

    output = _autoStraighten(output);
    output = _sharpenText(output);

    final resized = img.copyResize(output, width: 1200);
    final compressed = img.encodeJpg(resized, quality: 90);

    final tempDir = await _getSafeTempDir();
    if (tempDir == null) return imagePath;
    final outPath =
        '${tempDir.path}/auto_card_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(outPath).writeAsBytes(compressed);
    return outPath;
  }

  static List<math.Point<int>>? _findDocumentCorners(
    img.Image image,
    List<double>? bboxList,
    double? frameWidth,
    double? frameHeight,
    double? screenWidth,
    double? screenHeight,
  ) {
    if (bboxList != null) {
      final l = bboxList[0].round();
      final t = bboxList[1].round();
      final r = (bboxList[0] + bboxList[2]).round();
      final b = (bboxList[1] + bboxList[3]).round();
      return [
        math.Point(l, t),
        math.Point(r, t),
        math.Point(r, b),
        math.Point(l, b),
      ];
    }

    final box = _detectDocumentBounds(image);
    if (box != null) {
      return [
        math.Point(box.left, box.top),
        math.Point(box.left + box.width, box.top),
        math.Point(box.left + box.width, box.top + box.height),
        math.Point(box.left, box.top + box.height),
      ];
    }

    if (frameWidth != null &&
        frameHeight != null &&
        screenWidth != null &&
        screenHeight != null) {
      final scaleX = image.width / screenWidth;
      final scaleY = image.height / screenHeight;
      final cx = screenWidth / 2;
      final cy = screenHeight / 2;
      final l = ((cx - frameWidth / 2) * scaleX).round();
      final t = ((cy - frameHeight / 2) * scaleY).round();
      final r = ((cx + frameWidth / 2) * scaleX).round();
      final b = ((cy + frameHeight / 2) * scaleY).round();
      return [
        math.Point(l, t),
        math.Point(r, t),
        math.Point(r, b),
        math.Point(l, b),
      ];
    }
    return null;
  }

  static img.Image _rectCrop(
    img.Image image,
    List<double>? bboxList,
    double? frameWidth,
    double? frameHeight,
    double? screenWidth,
    double? screenHeight,
  ) {
    final corners = _findDocumentCorners(image, bboxList, frameWidth, frameHeight, screenWidth, screenHeight);
    if (corners == null) return image;

    final l = corners.map((p) => p.x).reduce(math.min).clamp(0, image.width - 1);
    final t = corners.map((p) => p.y).reduce(math.min).clamp(0, image.height - 1);
    final r = corners.map((p) => p.x).reduce(math.max).clamp(l + 1, image.width);
    final b = corners.map((p) => p.y).reduce(math.max).clamp(t + 1, image.height);

    return img.copyCrop(image, x: l, y: t, width: r - l, height: b - t);
  }

  /// Bilinear perspective warp to axis-aligned rectangle.
  static img.Image _perspectiveCorrect(
    img.Image src,
    List<math.Point<int>> corners,
  ) {
    final ordered = _orderCorners(corners);
    final outW = _distD(ordered[0], ordered[1]).round().clamp(100, 2400);
    final outH = _distD(ordered[0], ordered[3]).round().clamp(80, 1600);

    if (outW < 2 || outH < 2 || src.width < 2 || src.height < 2) {
      return _rectCrop(src, null, null, null, null, null);
    }

    final dst = img.Image(width: outW, height: outH);
    final uDenom = (outW - 1).clamp(1, outW);
    final vDenom = (outH - 1).clamp(1, outH);

    for (int y = 0; y < outH; y++) {
      for (int x = 0; x < outW; x++) {
        final u = x / uDenom;
        final v = y / vDenom;

        final top = _lerpPoint(ordered[0], ordered[1], u);
        final bottom = _lerpPoint(ordered[3], ordered[2], u);
        final srcPt = _lerpPoint(top, bottom, v);

        final sx = srcPt.x.round().clamp(0, src.width - 1);
        final sy = srcPt.y.round().clamp(0, src.height - 1);
        dst.setPixel(x, y, src.getPixel(sx, sy));
      }
    }
    return dst;
  }

  static List<math.Point<double>> _orderCorners(List<math.Point<int>> pts) {
    final sorted = List<math.Point<int>>.from(pts);
    sorted.sort((a, b) => (a.y + a.x).compareTo(b.y + b.x));
    final top = sorted.take(2).toList()..sort((a, b) => a.x.compareTo(b.x));
    final bottom = sorted.skip(2).toList()..sort((a, b) => a.x.compareTo(b.x));
    return [
      math.Point(top[0].x.toDouble(), top[0].y.toDouble()),
      math.Point(top[1].x.toDouble(), top[1].y.toDouble()),
      math.Point(bottom[1].x.toDouble(), bottom[1].y.toDouble()),
      math.Point(bottom[0].x.toDouble(), bottom[0].y.toDouble()),
    ];
  }

  static math.Point<double> _lerpPoint(
    math.Point<double> a,
    math.Point<double> b,
    double t,
  ) {
    return math.Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
  }

  static double _dist(math.Point<int> a, math.Point<int> b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  static double _distD(math.Point<double> a, math.Point<double> b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }

  static ({int left, int top, int width, int height})? _detectDocumentBounds(
    img.Image image,
  ) {
    final analysis = img.copyResize(image, width: 640);
    final gray = img.grayscale(analysis);

    int minX = gray.width, minY = gray.height, maxX = 0, maxY = 0;
    int edgeCount = 0;

    for (int y = 1; y < gray.height - 1; y++) {
      for (int x = 1; x < gray.width - 1; x++) {
        final c = gray.getPixel(x, y).r;
        final gx = (gray.getPixel(x + 1, y).r - gray.getPixel(x - 1, y).r).abs();
        final gy = (gray.getPixel(x, y + 1).r - gray.getPixel(x, y - 1).r).abs();
        if (gx + gy > 40 && c < 220) {
          edgeCount++;
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (edgeCount < 200 || maxX <= minX || maxY <= minY) return null;

    final scaleX = image.width / gray.width;
    final scaleY = image.height / gray.height;
    final marginX = ((maxX - minX) * 0.05).round();
    final marginY = ((maxY - minY) * 0.05).round();

    final left = ((minX - marginX) * scaleX).round().clamp(0, image.width - 1);
    final top = ((minY - marginY) * scaleY).round().clamp(0, image.height - 1);
    final right = ((maxX + marginX) * scaleX).round().clamp(left + 1, image.width);
    final bottom = ((maxY + marginY) * scaleY).round().clamp(top + 1, image.height);

    return (left: left, top: top, width: right - left, height: bottom - top);
  }

  static img.Image _adaptiveEnhance(img.Image image) {
    double totalLum = 0;
    int count = 0;
    final step = math.max(1, (image.width * image.height) ~/ 500);

    for (int i = 0; i < image.width * image.height; i += step) {
      final x = i % image.width;
      final y = i ~/ image.width;
      if (y >= image.height) break;
      final p = image.getPixel(x, y);
      totalLum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      count++;
    }

    final avg = count > 0 ? totalLum / count : 128;

    if (avg < 85) {
      return img.convolution(
        img.adjustColor(
          image,
          brightness: 0.32,
          contrast: 1.5,
          saturation: 1.08,
          gamma: 1.1,
        ),
        filter: [0, -1, 0, -1, 5, -1, 0, -1, 0],
      );
    }
    if (avg < 140) {
      return img.adjustColor(image, brightness: 0.1, contrast: 1.22, gamma: 1.05);
    }
    return image;
  }

  static img.Image _sharpenText(img.Image image) {
    return img.convolution(
      image,
      filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0],
    );
  }

  static img.Image _autoStraighten(img.Image image) {
    final gray = img.grayscale(image);
    final rowCounts = List<int>.filled(gray.height, 0);
    const threshold = 128;

    for (int y = 0; y < gray.height; y++) {
      for (int x = 0; x < gray.width; x += 3) {
        if (gray.getPixel(x, y).r < threshold) rowCounts[y]++;
      }
    }

    final avg = rowCounts.fold(0, (a, b) => a + b) ~/ math.max(1, rowCounts.length);
    final peaks = <int>[];

    for (int y = 1; y < rowCounts.length - 1; y++) {
      if (rowCounts[y] > avg * 1.4 &&
          rowCounts[y] > rowCounts[y - 1] &&
          rowCounts[y] > rowCounts[y + 1]) {
        peaks.add(y);
      }
    }

    if (peaks.length >= 2) {
      final topLeft = _firstDarkX(gray, peaks.first, threshold);
      final bottomLeft = _firstDarkX(gray, peaks.last, threshold);
      if (topLeft >= 0 && bottomLeft >= 0) {
        final dy = peaks.last - peaks.first;
        final dx = bottomLeft - topLeft;
        if (dy > 0) {
          final angle = math.atan2(dx.toDouble(), dy.toDouble()) * (180 / math.pi);
          if (angle.abs() > 0.5 && angle.abs() < 10) {
            return img.copyRotate(image, angle: -angle);
          }
        }
      }
    }
    return image;
  }

  static int _firstDarkX(img.Image gray, int y, int threshold) {
    for (int x = 0; x < gray.width; x++) {
      if (gray.getPixel(x, y).r < threshold) return x;
    }
    return -1;
  }
}

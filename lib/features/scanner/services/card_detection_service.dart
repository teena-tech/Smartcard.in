import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/card_corners.dart';
import '../models/detected_card.dart';
import '../models/scanner_state.dart';

class CardDetectionService {
  CardCorners? _previousCorners;
  int _consecutiveStableFrames = 0;
  static const int requiredStableFrames = 5;

  /// Analyzes text bounding blocks from a camera frame to construct the four corners of a detected card
  /// and evaluates whether the card position is stable, too close, too far, or tilted.
  DetectedCard? analyzeTextBlocks(
    RecognizedText recognized,
    Size screenSize,
  ) {
    if (recognized.blocks.isEmpty) {
      _consecutiveStableFrames = 0;
      _previousCorners = null;
      return null;
    }

    // Combine all bounding boxes of text blocks to estimate card quad
    Rect? unionRect;
    for (final block in recognized.blocks) {
      final r = block.boundingBox;
      unionRect = unionRect == null ? r : unionRect.expandToInclude(r);
    }

    if (unionRect == null) return null;

    // Inflate slightly to encompass card border around text
    final paddedRect = unionRect.inflate(24);

    // Map rect corners to screen space coordinates
    final corners = CardCorners.fromRect(paddedRect);

    // Compute metrics
    final cardArea = corners.width * corners.height;
    final screenArea = screenSize.width * screenSize.height;
    final areaRatio = screenArea > 0 ? (cardArea / screenArea) : 0.4;

    // Check stability against previous corners
    bool isFrameStable = false;
    if (_previousCorners != null) {
      final dxTopLeft = (corners.topLeft.dx - _previousCorners!.topLeft.dx).abs();
      final dyTopLeft = (corners.topLeft.dy - _previousCorners!.topLeft.dy).abs();
      final dxBottomRight = (corners.bottomRight.dx - _previousCorners!.bottomRight.dx).abs();
      final dyBottomRight = (corners.bottomRight.dy - _previousCorners!.bottomRight.dy).abs();

      // If movement is under 12 pixels, frame is stable
      if (dxTopLeft < 14 && dyTopLeft < 14 && dxBottomRight < 14 && dyBottomRight < 14) {
        isFrameStable = true;
        _consecutiveStableFrames++;
      } else {
        _consecutiveStableFrames = (0.5 * _consecutiveStableFrames).toInt();
      }
    } else {
      _consecutiveStableFrames = 1;
    }

    _previousCorners = corners;

    final isFullyStable = _consecutiveStableFrames >= requiredStableFrames;

    return DetectedCard(
      corners: corners,
      areaPercentage: areaRatio,
      isStable: isFullyStable,
      stabilityCounter: _consecutiveStableFrames.clamp(0, requiredStableFrames),
    );
  }

  /// Map detected card metrics to high-level ScannerStateEnum
  ScannerStateEnum evaluateState(DetectedCard? card) {
    if (card == null) return ScannerStateEnum.searching;

    if (card.areaPercentage < 0.12) {
      return ScannerStateEnum.tooFar;
    }

    if (card.areaPercentage > 0.85) {
      return ScannerStateEnum.tooClose;
    }

    if (card.isStable) {
      return ScannerStateEnum.stable;
    }

    if (card.stabilityCounter > 1) {
      return ScannerStateEnum.aligning;
    }

    return ScannerStateEnum.cardDetected;
  }

  /// Calculates stability ratio from 0.0 to 1.0
  double calculateProgress(int stabilityCounter) {
    return (stabilityCounter / requiredStableFrames).clamp(0.0, 1.0);
  }

  void reset() {
    _consecutiveStableFrames = 0;
    _previousCorners = null;
  }
}

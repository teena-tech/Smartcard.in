import 'package:equatable/equatable.dart';
import 'package:smartcard_flutter/features/smart_scanner_screen/data/models/card_corners.dart';

class DetectedCard extends Equatable {
  final CardCorners corners;
  final double confidence;
  final double areaPercentage;
  final double rotationAngle;
  final bool isStable;
  final int stabilityCounter;

  const DetectedCard({
    required this.corners,
    this.confidence = 1.0,
    this.areaPercentage = 0.5,
    this.rotationAngle = 0.0,
    this.isStable = false,
    this.stabilityCounter = 0,
  });

  DetectedCard copyWith({
    CardCorners? corners,
    double? confidence,
    double? areaPercentage,
    double? rotationAngle,
    bool? isStable,
    int? stabilityCounter,
  }) {
    return DetectedCard(
      corners: corners ?? this.corners,
      confidence: confidence ?? this.confidence,
      areaPercentage: areaPercentage ?? this.areaPercentage,
      rotationAngle: rotationAngle ?? this.rotationAngle,
      isStable: isStable ?? this.isStable,
      stabilityCounter: stabilityCounter ?? this.stabilityCounter,
    );
  }

  @override
  List<Object?> get props => [
        corners,
        confidence,
        areaPercentage,
        rotationAngle,
        isStable,
        stabilityCounter,
      ];
}

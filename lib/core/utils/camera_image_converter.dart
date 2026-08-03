import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Converts [CameraImage] frames to ML Kit [InputImage] (Android YUV420).
class CameraImageConverter {
  static InputImage? fromCameraImage(
    CameraImage image,
    CameraDescription camera,
    DeviceOrientation deviceOrientation,
  ) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    final rotation = _rotationFromOrientation(
      camera.sensorOrientation,
      deviceOrientation,
    );

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  static InputImageRotation _rotationFromOrientation(
    int sensorOrientation,
    DeviceOrientation orientation,
  ) {
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        return InputImageRotation.rotation0deg;
      case DeviceOrientation.landscapeLeft:
        return InputImageRotation.rotation90deg;
      case DeviceOrientation.portraitDown:
        return InputImageRotation.rotation180deg;
      case DeviceOrientation.landscapeRight:
        return InputImageRotation.rotation270deg;
    }
  }
}

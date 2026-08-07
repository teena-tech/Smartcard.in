import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTorchOn = false;
  int _selectedCameraIndex = 0;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized && _controller != null && _controller!.value.isInitialized;
  bool get isTorchOn => _isTorchOn;

  Future<bool> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return false;

      // Select primary back camera
      _selectedCameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) _selectedCameraIndex = 0;

      return await _startCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('CameraService initialization failed: $e');
      return false;
    }
  }

  Future<bool> _startCamera(CameraDescription description) async {
    await dispose();

    _controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error starting camera controller: $e');
      _isInitialized = false;
      return false;
    }
  }

  Future<void> toggleTorch() async {
    if (!isInitialized) return;
    try {
      _isTorchOn = !_isTorchOn;
      await _controller!.setFlashMode(
        _isTorchOn ? FlashMode.torch : FlashMode.off,
      );
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _startCamera(_cameras[_selectedCameraIndex]);
  }

  Future<XFile?> takePicture() async {
    if (!isInitialized) return null;
    try {
      return await _controller!.takePicture();
    } catch (e) {
      debugPrint('Error taking picture: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    _isInitialized = false;
    if (_controller != null) {
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint('Error disposing camera: $e');
      }
      _controller = null;
    }
  }
}

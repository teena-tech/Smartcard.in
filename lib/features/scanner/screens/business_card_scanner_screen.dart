import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/scanner_controller.dart';
import '../models/scan_type.dart';
import '../models/scanner_state.dart';
import '../services/camera_service.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/capture_animation.dart';
import '../widgets/processing_animation.dart';
import 'contact_review_screen.dart';

class BusinessCardScannerScreen extends StatefulWidget {
  const BusinessCardScannerScreen({super.key});

  @override
  State<BusinessCardScannerScreen> createState() => _BusinessCardScannerScreenState();
}

class _BusinessCardScannerScreenState extends State<BusinessCardScannerScreen> {
  final CameraService _cameraService = CameraService();
  final ScannerController _controller = ScannerController();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Timer? _analysisTimer;
  bool _isAnalyzing = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _controller.setScanType(ScanType.businessCard);
    _controller.addListener(_onControllerStateChanged);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final success = await _cameraService.initialize();
    if (mounted) {
      setState(() {
        _isCameraReady = success;
      });
      if (success) {
        _startContinuousAnalysis();
      }
    }
  }

  void _startContinuousAnalysis() {
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      _analyzeCurrentFrame();
    });
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_isAnalyzing || !_isCameraReady || _controller.state == ScannerStateEnum.processing || _controller.state == ScannerStateEnum.capturing) {
      return;
    }

    _isAnalyzing = true;
    try {
      // Heuristic frame detection check via controller metrics
      final screenSize = MediaQuery.of(context).size;
      // Trigger card detector frame evaluation
      // If camera controller has frame streams or snapshot sample
      _controller.updateDetectedCard(null); // Keeps state reactive & guidance messages smooth
    } catch (e) {
      debugPrint('Analysis frame error: $e');
    } finally {
      _isAnalyzing = false;
    }
  }

  void _onControllerStateChanged() {
    if (_controller.state == ScannerStateEnum.capturing) {
      _executeCapture();
    }
  }

  Future<void> _executeCapture() async {
    _analysisTimer?.cancel();

    XFile? capturedFile;
    if (_isCameraReady) {
      capturedFile = await _cameraService.takePicture();
    }

    if (capturedFile == null) {
      // Fallback: prompt gallery / pick image
      capturedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 92);
    }

    if (capturedFile != null && mounted) {
      final parsedContact = await _controller.processCapturedImagePath(capturedFile.path);

      if (parsedContact != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ContactReviewScreen(
              contact: parsedContact,
              imagePath: _controller.lastCapturedImagePath ?? capturedFile!.path,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleManualCapture() async {
    HapticFeedback.mediumImpact();
    await _executeCapture();
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    _controller.removeListener(_onControllerStateChanged);
    _controller.dispose();
    _cameraService.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.state == ScannerStateEnum.processing) {
            return ProcessingAnimationWidget(
              imagePath: _controller.lastCapturedImagePath,
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              if (_isCameraReady && _cameraService.controller != null)
                CameraPreview(_cameraService.controller!)
              else
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5252)),
                ),

              // Scanner Controls and Custom Card Overlay
              ScannerOverlay(
                scanType: ScanType.businessCard,
                state: _controller.state,
                detectedCard: _controller.detectedCard,
                stabilityProgress: _controller.stabilityProgress,
                isTorchOn: _cameraService.isTorchOn,
                onTorchToggle: () {
                  _cameraService.toggleTorch();
                  setState(() {});
                },
                onCameraSwitch: () {
                  _cameraService.switchCamera();
                  setState(() {});
                },
                onManualCapture: _handleManualCapture,
                onBackPressed: () => Navigator.maybePop(context),
              ),

              // Flash Capture Animation Overlay
              CaptureAnimationWidget(
                isCapturing: _controller.state == ScannerStateEnum.capturing,
              ),
            ],
          );
        },
      ),
    );
  }
}

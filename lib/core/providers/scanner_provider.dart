import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bloc/scan_bloc.dart';
import '../../core/services/edge_detection_service.dart';
import '../../core/services/scan_processing_service.dart';
import '../../models/scanned_contact_model.dart';

export '../../bloc/scan_bloc.dart'
    show
        ScanState,
        ScanInitial,
        ScanReady,
        ScanProcessing,
        ScanSuccess,
        ScanFailure,
        ScanTimeout,
        ScanSaveResult,
        ScanEvent,
        StartCameraDetection,
        AutoCaptureTriggered,
        ProcessGalleryImage,
        ProcessEdgeCameraScan,
        ProcessQrCode,
        ResetScanState,
        EmitSaveResult;

class ScannerNotifier extends Notifier<ScanState> {
  late final ScanProcessingService _processor;
  bool _busy = false;
  Timer? _timeoutTimer;

  static const int _timeoutSeconds = 45;

  @override
  ScanState build() {
    _processor = ScanProcessingService();
    ref.onDispose(() {
      _cancelTimeout();
      _processor.dispose();
    });
    return ScanInitial();
  }

  bool get isBusy => _busy;

  void startCameraDetection() {
    state = ScanReady();
  }

  Future<void> autoCaptureTriggered({
    required String imagePath,
    required double screenWidth,
    required double screenHeight,
    required double cardWidth,
    required double cardHeight,
  }) async {
    if (_busy) return;
    _busy = true;
    _startTimeout();

    state = ScanProcessing(
      message: 'Auto-detecting card edges...',
      imagePath: imagePath,
    );

    try {
      final result = await _processor.processImage(
        imagePath: imagePath,
        screenWidth: screenWidth,
        screenHeight: screenHeight,
        frameWidth: cardWidth,
        frameHeight: cardHeight,
      );

      _cancelTimeout();
      state = ScanSuccess(
        contact: result.contact,
        imagePath: result.imagePath,
        fromQr: result.fromQr,
      );
    } catch (e) {
      _cancelTimeout();
      state = ScanFailure(error: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }
  }

  Future<void> processGalleryImage({
    required String imagePath,
    bool manualEdgeAdjust = false,
  }) async {
    if (_busy) return;
    _busy = true;
    _startTimeout();

    state = ScanProcessing(
      message: 'Detecting card from gallery...',
      imagePath: imagePath,
    );

    try {
      final result = await _processor.processImage(
        imagePath: imagePath,
        manualEdgeAdjust: manualEdgeAdjust,
        fromGallery: true,
      );
      _cancelTimeout();
      state = ScanSuccess(
        contact: result.contact,
        imagePath: result.imagePath,
        fromQr: result.fromQr,
      );
    } catch (e) {
      _cancelTimeout();
      state = ScanFailure(error: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }
  }

  Future<void> processEdgeCameraScan() async {
    if (_busy) return;
    _busy = true;
    _startTimeout();

    state = const ScanProcessing(message: 'Opening document scanner...');

    try {
      final path = await EdgeDetectionService.scanFromCamera();
      if (path == null) throw Exception('Card scan cancelled');

      // Update processing state with the cropped card image path immediately
      state = ScanProcessing(
        message: 'Processing business card OCR...',
        imagePath: path,
      );

      final result = await _processor.processImage(
        imagePath: path,
        fromGallery: false,
      );
      _cancelTimeout();
      state = ScanSuccess(
        contact: result.contact,
        imagePath: result.imagePath,
        fromQr: result.fromQr,
      );
    } catch (e) {
      _cancelTimeout();
      state = ScanFailure(error: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }
  }

  Future<void> processQrCode(String qrValue) async {
    if (_busy) return;
    _busy = true;
    _startTimeout();

    state = const ScanProcessing(message: 'Parsing QR contact data...');

    try {
      final result = await _processor.processQrString(qrValue);
      _cancelTimeout();
      state = ScanSuccess(
        contact: result.contact,
        imagePath: result.imagePath,
        fromQr: result.fromQr,
      );
    } catch (e) {
      _cancelTimeout();
      state = ScanFailure(error: e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _busy = false;
    }
  }

  void resetScanState() {
    _cancelTimeout();
    _busy = false;
    state = ScanReady();
  }

  void emitSaveResult({
    required ScannedContactModel contact,
    String? imagePath,
    required bool phoneSaved,
    required bool apiSaved,
    String? phoneError,
    String? apiError,
  }) {
    debugPrint(
      '📊 [ScannerNotifier] Save result — phone: $phoneSaved, api: $apiSaved'
      '${phoneError != null ? ", phoneErr: $phoneError" : ""}'
      '${apiError != null ? ", apiErr: $apiError" : ""}',
    );
    state = ScanSaveResult(
      contact: contact,
      imagePath: imagePath,
      phoneSaved: phoneSaved,
      apiSaved: apiSaved,
      phoneError: phoneError,
      apiError: apiError,
    );
  }

  void _startTimeout() {
    _cancelTimeout();
    _timeoutTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      _busy = false;
      debugPrint('⏱️ ScannerNotifier: timeout fired after ${_timeoutSeconds}s');
      if (state is ScanProcessing) {
        state = const ScanTimeout(
          reason: 'Processing took too long. Contact saved locally if scan succeeded.',
        );
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
}

final scannerNotifierProvider =
    NotifierProvider<ScannerNotifier, ScanState>(ScannerNotifier.new);


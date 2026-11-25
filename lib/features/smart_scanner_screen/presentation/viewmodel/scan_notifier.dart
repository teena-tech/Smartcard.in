import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:equatable/equatable.dart';

import 'package:smartcard_flutter/core/services/edge_detection_service.dart';
import 'package:smartcard_flutter/core/services/scan_processing_service.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

// ==========================================
// EVENTS
// ==========================================
abstract class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => [];
}

class StartCameraDetection extends ScanEvent {}

class AutoCaptureTriggered extends ScanEvent {
  final String imagePath;
  final double screenWidth;
  final double screenHeight;
  final double cardWidth;
  final double cardHeight;

  const AutoCaptureTriggered({
    required this.imagePath,
    required this.screenWidth,
    required this.screenHeight,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  List<Object?> get props => [imagePath, screenWidth, screenHeight, cardWidth, cardHeight];
}

class ProcessGalleryImage extends ScanEvent {
  final String imagePath;
  final bool manualEdgeAdjust;

  const ProcessGalleryImage({
    required this.imagePath,
    this.manualEdgeAdjust = false,
  });

  @override
  List<Object?> get props => [imagePath, manualEdgeAdjust];
}

class ProcessEdgeCameraScan extends ScanEvent {
  const ProcessEdgeCameraScan();
}

class ProcessQrCode extends ScanEvent {
  final String qrValue;
  const ProcessQrCode({required this.qrValue});

  @override
  List<Object?> get props => [qrValue];
}

class ResetScanState extends ScanEvent {}

class EmitSaveResult extends ScanEvent {
  final ScannedContactModel contact;
  final String? imagePath;
  final bool phoneSaved;
  final bool apiSaved;
  final String? phoneError;
  final String? apiError;

  const EmitSaveResult({
    required this.contact,
    this.imagePath,
    required this.phoneSaved,
    required this.apiSaved,
    this.phoneError,
    this.apiError,
  });

  @override
  List<Object?> get props => [contact, imagePath, phoneSaved, apiSaved];
}

// ==========================================
// STATES
// ==========================================
abstract class ScanState extends Equatable {
  const ScanState();

  @override
  List<Object?> get props => [];
}

class ScanInitial extends ScanState {}

class ScanReady extends ScanState {}

class ScanProcessing extends ScanState {
  final String message;
  final String? imagePath;
  const ScanProcessing({this.message = 'Processing card...', this.imagePath});

  @override
  List<Object?> get props => [message, imagePath];
}

class ScanSuccess extends ScanState {
  final ScannedContactModel contact;
  final String? imagePath;
  final bool fromQr;
  const ScanSuccess({
    required this.contact,
    this.imagePath,
    this.fromQr = false,
  });

  @override
  List<Object?> get props => [contact, imagePath, fromQr];
}

class ScanFailure extends ScanState {
  final String error;
  const ScanFailure({required this.error});

  @override
  List<Object?> get props => [error];
}

class ScanTimeout extends ScanState {
  final String reason;
  const ScanTimeout({this.reason = 'Processing timed out. Please retry.'});

  @override
  List<Object?> get props => [reason];
}

/// Emitted after a successful scan + dual-save attempt.
class ScanSaveResult extends ScanState {
  final ScannedContactModel contact;
  final String? imagePath;
  final bool phoneSaved;
  final bool apiSaved;
  final String? phoneError;
  final String? apiError;

  const ScanSaveResult({
    required this.contact,
    this.imagePath,
    required this.phoneSaved,
    required this.apiSaved,
    this.phoneError,
    this.apiError,
  });

  String get statusMessage {
    if (phoneSaved && apiSaved) return 'Contact saved to Phone & SmartCard ✓';
    if (phoneSaved && !apiSaved) return 'Saved to Phone Contacts. SmartCard sync failed.';
    if (!phoneSaved && apiSaved) return 'Saved to SmartCard. Phone contact save failed.';
    return 'Save failed. Contact stored locally only.';
  }

  @override
  List<Object?> get props => [contact, imagePath, phoneSaved, apiSaved, phoneError, apiError];
}

// ==========================================
// RIVERPOD NOTIFIER
// ==========================================
class ScanNotifier extends Notifier<ScanState> {
  final ScanProcessingService _processor = ScanProcessingService();
  bool _busy = false;
  Timer? _timeoutTimer;

  static const int _timeoutSeconds = 45;

  @override
  ScanState build() {
    ref.onDispose(() {
      _cancelTimeout();
      _processor.dispose();
    });
    return ScanInitial();
  }

  void add(ScanEvent event) {
    if (event is ResetScanState) {
      resetScanState();
    } else if (event is ProcessQrCode) {
      processQrCode(event.qrValue);
    } else if (event is ProcessEdgeCameraScan) {
      processEdgeCameraScan();
    } else if (event is AutoCaptureTriggered) {
      autoCaptureTriggered(
        imagePath: event.imagePath,
        screenWidth: event.screenWidth,
        screenHeight: event.screenHeight,
        cardWidth: event.cardWidth,
        cardHeight: event.cardHeight,
      );
    } else if (event is ProcessGalleryImage) {
      processGalleryImage(
        imagePath: event.imagePath,
        manualEdgeAdjust: event.manualEdgeAdjust,
      );
    } else if (event is EmitSaveResult) {
      emitSaveResult(
        contact: event.contact,
        imagePath: event.imagePath,
        phoneSaved: event.phoneSaved,
        apiSaved: event.apiSaved,
        phoneError: event.phoneError,
        apiError: event.apiError,
      );
    } else if (event is StartCameraDetection) {
      startCameraDetection();
    }
  }

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

    state = ScanProcessing(message: 'Auto-detecting card edges...', imagePath: imagePath);

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

    state = ScanProcessing(message: 'Detecting card from gallery...', imagePath: imagePath);

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

      state = ScanProcessing(message: 'Processing business card OCR...', imagePath: path);

      final result = await _processor.processImage(imagePath: path, fromGallery: false);
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
      if (state is ScanProcessing) {
        state = const ScanTimeout(reason: 'Processing took too long. Contact saved locally if scan succeeded.');
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
}

final scanNotifierProvider = NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);


/// Compatibility alias


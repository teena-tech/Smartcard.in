import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/services/edge_detection_service.dart';
import '../core/services/scan_processing_service.dart';
import '../models/scanned_contact_model.dart';

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
  List<Object?> get props => [
    imagePath,
    screenWidth,
    screenHeight,
    cardWidth,
    cardHeight,
  ];
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

/// Internal event fired by the UI after dual-save completes to propagate
/// the outcome back through the bloc stream for the BlocConsumer listener.
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

  /// Human-readable summary for the UI snackbar / status row.
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
// BLOC
// ==========================================
class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final ScanProcessingService _processor = ScanProcessingService();
  bool _busy = false;
  Timer? _timeoutTimer;

  /// 45 s covers: API preview (≤8 s) + device contacts fetch + insert + API save.
  static const int _timeoutSeconds = 45;

  ScanBloc() : super(ScanInitial()) {
    on<StartCameraDetection>((_, emit) => emit(ScanReady()));

    on<AutoCaptureTriggered>(_onAutoCapture);
    on<ProcessGalleryImage>(_onGalleryImage);
    on<ProcessEdgeCameraScan>(_onEdgeCameraScan);
    on<ProcessQrCode>(_onQrCode);
    on<ResetScanState>(_onReset);
    on<EmitSaveResult>(_onSaveResult);
  }

  Future<void> _onAutoCapture(
    AutoCaptureTriggered event,
    Emitter<ScanState> emit,
  ) async {
    if (_busy) return;
    _busy = true;
    _startTimeout(emit);

    emit(ScanProcessing(message: 'Auto-detecting card edges...', imagePath: event.imagePath));

    try {
      final result = await _processor.processImage(
        imagePath: event.imagePath,
        screenWidth: event.screenWidth,
        screenHeight: event.screenHeight,
        frameWidth: event.cardWidth,
        frameHeight: event.cardHeight,
      );

      _cancelTimeout();
      emit(
        ScanSuccess(
          contact: result.contact,
          imagePath: result.imagePath,
          fromQr: result.fromQr,
        ),
      );
    } catch (e) {
      _cancelTimeout();
      emit(ScanFailure(error: e.toString().replaceFirst('Exception: ', '')));
    } finally {
      _busy = false;
    }
  }

  Future<void> _onGalleryImage(
    ProcessGalleryImage event,
    Emitter<ScanState> emit,
  ) async {
    if (_busy) return;
    _busy = true;
    _startTimeout(emit);

    emit(ScanProcessing(message: 'Detecting card from gallery...', imagePath: event.imagePath));

    try {
      final result = await _processor.processImage(
        imagePath: event.imagePath,
        manualEdgeAdjust: event.manualEdgeAdjust,
        fromGallery: true,
      );
      _cancelTimeout();
      emit(
        ScanSuccess(
          contact: result.contact,
          imagePath: result.imagePath,
          fromQr: result.fromQr,
        ),
      );
    } catch (e) {
      _cancelTimeout();
      emit(ScanFailure(error: e.toString().replaceFirst('Exception: ', '')));
    } finally {
      _busy = false;
    }
  }

  Future<void> _onEdgeCameraScan(
    ProcessEdgeCameraScan event,
    Emitter<ScanState> emit,
  ) async {
    if (_busy) return;
    _busy = true;
    _startTimeout(emit);

    emit(const ScanProcessing(message: 'Opening document scanner...'));

    try {
      final path = await EdgeDetectionService.scanFromCamera();
      if (path == null) throw Exception('Card scan cancelled');

      // Update processing state with the cropped card image path immediately!
      emit(ScanProcessing(message: 'Processing business card OCR...', imagePath: path));

      final result = await _processor.processImage(imagePath: path, fromGallery: false);
      _cancelTimeout();
      emit(
        ScanSuccess(
          contact: result.contact,
          imagePath: result.imagePath,
          fromQr: result.fromQr,
        ),
      );
    } catch (e) {
      _cancelTimeout();
      emit(ScanFailure(error: e.toString().replaceFirst('Exception: ', '')));
    } finally {
      _busy = false;
    }
  }

  Future<void> _onQrCode(ProcessQrCode event, Emitter<ScanState> emit) async {
    if (_busy) return;
    _busy = true;
    _startTimeout(emit);

    emit(const ScanProcessing(message: 'Parsing QR contact data...'));

    try {
      final result = await _processor.processQrString(event.qrValue);
      _cancelTimeout();
      emit(
        ScanSuccess(
          contact: result.contact,
          imagePath: result.imagePath,
          fromQr: result.fromQr,
        ),
      );
    } catch (e) {
      _cancelTimeout();
      emit(ScanFailure(error: e.toString().replaceFirst('Exception: ', '')));
    } finally {
      _busy = false;
    }
  }

  void _onReset(ResetScanState event, Emitter<ScanState> emit) {
    _cancelTimeout();
    _busy = false;
    emit(ScanReady());
  }

  void _onSaveResult(EmitSaveResult event, Emitter<ScanState> emit) {
    debugPrint(
      '📊 [ScanBloc] Save result — phone: ${event.phoneSaved}, api: ${event.apiSaved}'
      '${event.phoneError != null ? ", phoneErr: ${event.phoneError}" : ""}'
      '${event.apiError != null ? ", apiErr: ${event.apiError}" : ""}',
    );
    emit(ScanSaveResult(
      contact: event.contact,
      imagePath: event.imagePath,
      phoneSaved: event.phoneSaved,
      apiSaved: event.apiSaved,
      phoneError: event.phoneError,
      apiError: event.apiError,
    ));
  }

  void _startTimeout(Emitter<ScanState> emit) {
    _cancelTimeout();
    _timeoutTimer = Timer(const Duration(seconds: _timeoutSeconds), () {
      _busy = false;
      debugPrint('⏱️ ScanBloc: timeout fired after ${_timeoutSeconds}s');
      if (!isClosed && state is ScanProcessing) {
        emit(const ScanTimeout(reason: 'Processing took too long. Contact saved locally if scan succeeded.'));
      }
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  Future<void> close() {
    _cancelTimeout();
    _processor.dispose();
    return super.close();
  }
}

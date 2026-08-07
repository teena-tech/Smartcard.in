import 'package:flutter/foundation.dart';
import '../models/qr_result.dart';

class QrScannerService {
  bool _isProcessing = false;

  /// Fast validation and parsing of QR code payload
  QrResult? processRawQrCode(String? rawPayload) {
    if (_isProcessing || rawPayload == null || rawPayload.trim().isEmpty) {
      return null;
    }

    _isProcessing = true;
    try {
      final result = QrResult.fromRawString(rawPayload);
      return result;
    } catch (e) {
      debugPrint('QR Processing error: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  void reset() {
    _isProcessing = false;
  }
}

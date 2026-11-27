import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';

class DocumentScannerService {
  DocumentScanner? _documentScanner;

  Future<String?> scanCardWithNativeWarp() async {
    if (!Platform.isAndroid) return null;

    try {
      _documentScanner ??= DocumentScanner(
        options: DocumentScannerOptions(
          mode: ScannerMode.full,
          pageLimit: 1,
        ),
      );

      final result = await _documentScanner!.scanDocument();
      final images = result.images;
      if (images != null && images.isNotEmpty) {
        return images.first;
      }
    } catch (e) {
      debugPrint('ML Kit DocumentScanner error: $e');
    }
    return null;
  }

  void dispose() {
    _documentScanner?.close();
    _documentScanner = null;
  }
}

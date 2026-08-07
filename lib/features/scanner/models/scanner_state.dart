enum ScannerStateEnum {
  searching,
  cardDetected,
  aligning,
  tooFar,
  tooClose,
  tilted,
  lowConfidence,
  stable,
  capturing,
  processing,
  ocrComplete,
  review,
  success,
  failure,
}

extension ScannerStateExtension on ScannerStateEnum {
  String get userFeedbackMessage {
    switch (this) {
      case ScannerStateEnum.searching:
        return 'Looking for a business card...';
      case ScannerStateEnum.cardDetected:
        return 'Card detected';
      case ScannerStateEnum.aligning:
        return 'Align the card';
      case ScannerStateEnum.tooFar:
        return 'Move closer';
      case ScannerStateEnum.tooClose:
        return 'Move slightly back';
      case ScannerStateEnum.tilted:
        return 'Straighten the card';
      case ScannerStateEnum.lowConfidence:
        return 'Adjust lighting or angle';
      case ScannerStateEnum.stable:
        return 'Perfect! Hold steady...';
      case ScannerStateEnum.capturing:
        return 'Capturing ✓';
      case ScannerStateEnum.processing:
        return 'Processing card details...';
      case ScannerStateEnum.ocrComplete:
        return 'Text recognized ✓';
      case ScannerStateEnum.review:
        return 'Review contact info';
      case ScannerStateEnum.success:
        return 'Saved successfully ✓';
      case ScannerStateEnum.failure:
        return 'Scan failed. Tap to retry.';
    }
  }
}

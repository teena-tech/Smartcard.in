import 'app_validators.dart';

class BusinessCardValidator {
  /// Validates if the recognized OCR text matches a business card pattern.
  /// Rejects selfies, empty images, or unrelated images.
  static bool validateText(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return false;

    // Minimum text length
    if (cleaned.length < 8) return false;

    final lowerText = cleaned.toLowerCase();

    // Check for standard contact patterns
    final hasEmail = AppValidators.hasEmail(cleaned);
    final hasPhone = AppValidators.hasPhone(cleaned);
    final hasWebsite = AppValidators.hasUrl(cleaned);

    if (hasPhone || hasEmail || hasWebsite) {
      return true;
    }

    final lines = cleaned
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // If 2 or more lines of readable text are extracted, allow parsing
    if (lines.length >= 2) {
      return true;
    }

    final List<String> keywords = [
      'manager', 'director', 'developer', 'engineer', 'founder', 'ceo', 'cto',
      'president', 'designer', 'owner', 'street', 'road', 'avenue', 'suite', 'floor',
      'card', 'pvt', 'ltd', 'inc', 'corp', 'company', 'services', 'solutions', 'tech'
    ];
    for (final kw in keywords) {
      if (lowerText.contains(kw)) {
        return true;
      }
    }

    return false;
  }

  /// Validates if the scanned QR code value matches business card or standard data payload requirements.
  static bool validateQr(String qrValue) {
    final trimmed = qrValue.trim();
    if (trimmed.isEmpty) return false;

    final upper = trimmed.toUpperCase();
    
    // Accept standard contact QR types
    if (upper.contains('BEGIN:VCARD') || upper.startsWith('MECARD:')) {
      return true;
    }

    // Accept ONLY SmartCards domain QR code URLs — reject all other HTTP/HTTPS URLs
    if (upper.startsWith('MAILTO:') || upper.startsWith('TEL:')) {
      return true;
    }
    if (upper.startsWith('HTTP://') || upper.startsWith('HTTPS://')) {
      final lower = trimmed.toLowerCase();
      final isSmartCard = lower.contains('thesmartcard') ||
          lower.contains('smartcard') ||
          lower.contains('scard') ||
          lower.contains('localhost') ||
          lower.contains('127.0.0.1') ||
          lower.contains('10.0.2.2') ||
          lower.contains('192.168.');
      return isSmartCard; // skip all other domain QR codes
    }

    // Reject any other URI scheme (upi://, intent://, geo://, etc.)
    // Only allow plain text, vCard, meCard, SmartCards URLs, tel:, mailto:
    final schemeMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9+\-.]+)://').firstMatch(trimmed);
    if (schemeMatch != null) {
      // Has a URI scheme — only allowed schemes are SmartCards http/https
      return false; // all other schemes (upi, intent, geo, market, etc.) rejected
    }

    // If it is just plain text, check if it contains phone/email
    final hasEmail = AppValidators.hasEmail(trimmed);
    final hasPhone = AppValidators.hasPhone(trimmed);

    return hasEmail || hasPhone;
  }
}

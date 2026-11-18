library;

/// Centralized International Phone Number & OTP Delivery Helper.
/// Supports India, USA, UK, Canada, Australia, UAE, and other global regions.
/// Provides E.164 formatting, country validation, and delivery channel rules.

class CountryData {
  final String name;
  final String code; // e.g. '+91'
  final String isoCode; // e.g. 'IN'
  final String flag; // e.g. '🇮🇳'
  final int minLength;
  final int maxLength;
  final String example;

  const CountryData({
    required this.name,
    required this.code,
    required this.isoCode,
    required this.flag,
    required this.minLength,
    required this.maxLength,
    required this.example,
  });
}

class InternationalPhoneHelper {
  static const List<CountryData> supportedCountries = [
    CountryData(
      name: 'India',
      code: '+91',
      isoCode: 'IN',
      flag: '🇮🇳',
      minLength: 10,
      maxLength: 10,
      example: '9876543210',
    ),
    CountryData(
      name: 'United States',
      code: '+1',
      isoCode: 'US',
      flag: '🇺🇸',
      minLength: 10,
      maxLength: 10,
      example: '2025550123',
    ),
    CountryData(
      name: 'United Kingdom',
      code: '+44',
      isoCode: 'GB',
      flag: '🇬🇧',
      minLength: 10,
      maxLength: 11,
      example: '7911123456',
    ),
    CountryData(
      name: 'Canada',
      code: '+1',
      isoCode: 'CA',
      flag: '🇨🇦',
      minLength: 10,
      maxLength: 10,
      example: '4165550123',
    ),
    CountryData(
      name: 'Australia',
      code: '+61',
      isoCode: 'AU',
      flag: '🇦🇺',
      minLength: 9,
      maxLength: 10,
      example: '412345678',
    ),
    CountryData(
      name: 'UAE',
      code: '+971',
      isoCode: 'AE',
      flag: '🇦🇪',
      minLength: 9,
      maxLength: 9,
      example: '501234567',
    ),
    CountryData(
      name: 'Saudi Arabia',
      code: '+966',
      isoCode: 'SA',
      flag: '🇸🇦',
      minLength: 9,
      maxLength: 9,
      example: '512345678',
    ),
    CountryData(
      name: 'Qatar',
      code: '+974',
      isoCode: 'QA',
      flag: '🇶🇦',
      minLength: 8,
      maxLength: 8,
      example: '33123456',
    ),
    CountryData(
      name: 'Oman',
      code: '+968',
      isoCode: 'OM',
      flag: '🇴🇲',
      minLength: 8,
      maxLength: 8,
      example: '91234567',
    ),
    CountryData(
      name: 'Kuwait',
      code: '+965',
      isoCode: 'KW',
      flag: '🇰🇼',
      minLength: 8,
      maxLength: 8,
      example: '91234567',
    ),
    CountryData(
      name: 'Bahrain',
      code: '+973',
      isoCode: 'BH',
      flag: '🇧🇭',
      minLength: 8,
      maxLength: 8,
      example: '39123456',
    ),
    CountryData(
      name: 'Singapore',
      code: '+65',
      isoCode: 'SG',
      flag: '🇸🇬',
      minLength: 8,
      maxLength: 8,
      example: '81234567',
    ),
    CountryData(
      name: 'Malaysia',
      code: '+60',
      isoCode: 'MY',
      flag: '🇲🇾',
      minLength: 9,
      maxLength: 10,
      example: '123456789',
    ),
    CountryData(
      name: 'Germany',
      code: '+49',
      isoCode: 'DE',
      flag: '🇩🇪',
      minLength: 10,
      maxLength: 11,
      example: '15123456789',
    ),
    CountryData(
      name: 'France',
      code: '+33',
      isoCode: 'FR',
      flag: '🇫🇷',
      minLength: 9,
      maxLength: 9,
      example: '612345678',
    ),
    CountryData(
      name: 'Japan',
      code: '+81',
      isoCode: 'JP',
      flag: '🇯🇵',
      minLength: 10,
      maxLength: 10,
      example: '9012345678',
    ),
    CountryData(
      name: 'South Africa',
      code: '+27',
      isoCode: 'ZA',
      flag: '🇿🇦',
      minLength: 9,
      maxLength: 9,
      example: '821234567',
    ),
    CountryData(
      name: 'New Zealand',
      code: '+64',
      isoCode: 'NZ',
      flag: '🇳🇿',
      minLength: 8,
      maxLength: 10,
      example: '211234567',
    ),
  ];

  static const CountryData defaultCountry = CountryData(
    name: 'India',
    code: '+91',
    isoCode: 'IN',
    flag: '🇮🇳',
    minLength: 10,
    maxLength: 10,
    example: '9876543210',
  );

  /// Find country by dial code (e.g. '+91')
  static CountryData findByCode(String code) {
    final cleanCode = code.startsWith('+') ? code : '+$code';
    return supportedCountries.firstWhere(
      (c) => c.code == cleanCode,
      orElse: () => defaultCountry,
    );
  }

  /// Strips all non-digit characters from string.
  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Validates a phone number based on its selected country code.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validatePhoneNumber({
    required String phone,
    required String countryCode,
    bool isWhatsApp = false,
    String? fieldName,
  }) {
    final digits = digitsOnly(phone);
    final effectiveFieldName = fieldName ?? (isWhatsApp ? 'WhatsApp number' : 'phone number');

    if (digits.isEmpty) {
      return 'Please enter a $effectiveFieldName.';
    }

    final country = findByCode(countryCode);

    // Specific country checks
    if (country.code == '+91') {
      if (digits.length != 10) {
        return 'Please enter a valid 10-digit Indian $effectiveFieldName.';
      }
      if (!RegExp(r'^[6-9]').hasMatch(digits)) {
        return 'Indian mobile numbers start with 6, 7, 8, or 9.';
      }
      return null;
    }

    if (country.code == '+1') {
      if (digits.length != 10) {
        return 'Please enter a valid 10-digit $effectiveFieldName for ${country.name}.';
      }
      return null;
    }

    if (digits.length < country.minLength || digits.length > country.maxLength) {
      if (country.minLength == country.maxLength) {
        return 'Please enter a valid ${country.minLength}-digit $effectiveFieldName for ${country.name}.';
      } else {
        return 'Please enter a $effectiveFieldName between ${country.minLength} and ${country.maxLength} digits for ${country.name}.';
      }
    }

    // Standard ITU-T E.164 boundary check (max 15 digits total)
    if (digits.length < 7 || digits.length > 15) {
      return 'Please enter a valid international $effectiveFieldName (7-15 digits).';
    }

    return null;
  }

  /// Formats phone number into standard international E.164 format:
  /// e.g. "+919876543210", "+12025550123"
  static String toE164({
    required String phone,
    required String countryCode,
  }) {
    final digits = digitsOnly(phone);
    final codeDigits = digitsOnly(countryCode);

    // If the entered number already includes the country code prefix
    if (digits.startsWith(codeDigits) && digits.length > codeDigits.length + 6) {
      return '+$digits';
    }

    return '+$codeDigits$digits';
  }

  /// Formats phone number for backend APIs:
  /// - For Indian users (+91): if 10 digits, keeps clean 10-digit string (e.g. "9876543210")
  ///   to preserve 100% backward compatibility with existing Indian user accounts.
  /// - For international users: returns standard E.164 (e.g. "+12025550123", "+971501234567").
  static String formatForBackend({
    required String phone,
    required String countryCode,
  }) {
    final digits = digitsOnly(phone);
    final cleanCode = countryCode.startsWith('+') ? countryCode : '+$countryCode';

    if (cleanCode == '+91') {
      // If 10 digits, send 10 digits as expected by existing Indian user records
      if (digits.length == 10) {
        return digits;
      }
      // If user typed 91 prefix
      if (digits.startsWith('91') && digits.length == 12) {
        return digits.substring(2);
      }
      return digits;
    }

    return toE164(phone: digits, countryCode: cleanCode);
  }

  /// Parses a phone number that might already contain country code or be a raw Indian number.
  /// Returns a tuple of (countryCode, nationalNumber).
  static ({String countryCode, String nationalNumber, String flag}) parseRaw(String raw) {
    if (raw.trim().isEmpty) {
      return (countryCode: '+91', nationalNumber: '', flag: '🇮🇳');
    }

    final trimmed = raw.trim();

    // If starts with '+'
    if (trimmed.startsWith('+')) {
      final digits = digitsOnly(trimmed);
      // Try to find the longest matching country dial code
      for (final country in supportedCountries) {
        final cDigits = digitsOnly(country.code);
        if (digits.startsWith(cDigits)) {
          final national = digits.substring(cDigits.length);
          return (
            countryCode: country.code,
            nationalNumber: national,
            flag: country.flag,
          );
        }
      }
    }

    // If standard 10-digit number without +, treat as India (+91)
    final digits = digitsOnly(trimmed);
    if (digits.length == 10) {
      return (countryCode: '+91', nationalNumber: digits, flag: '🇮🇳');
    }

    // Default fallback
    return (countryCode: '+91', nationalNumber: digits, flag: '🇮🇳');
  }
}

/// Centralized phone number normalization utility.
/// Handles +91, 91, 0 prefixes and produces a consistent 10-digit tail for comparison.
class PhoneNormalizer {
  /// Strips all non-digit characters.
  static String digitsOnly(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  /// Returns the last 10 digits for comparison (normalizes country code variants).
  /// e.g. +91 98765 43210, 919876543210, 9876543210 → all yield "9876543210"
  static String last10(String phone) {
    final digits = digitsOnly(phone);
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Returns true if two phone numbers represent the same number.
  static bool isSame(String a, String b) {
    final da = last10(a);
    final db = last10(b);
    return da.length >= 7 && da == db;
  }

  /// Returns true if [number] already exists in [existing] list (normalized comparison).
  static bool existsIn(String number, Iterable<String> existing) {
    final n10 = last10(number);
    if (n10.length < 7) return false;
    for (final e in existing) {
      if (last10(e) == n10) return true;
    }
    return false;
  }

  /// Deduplicates a list of phone numbers using normalized comparison.
  static List<String> deduplicate(List<String> phones) {
    final seen = <String>{};
    final result = <String>[];
    for (final p in phones) {
      final normalized = last10(p);
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(p);
      }
    }
    return result;
  }

  /// Normalizes phone number by stripping spaces, hyphens, brackets, and country codes
  static String normalize(String phone) => last10(phone);
}

/// Global helper for phone number normalization as per duplicate/scam detection requirement.
/// Handles:
/// - +91 98765 43210
/// - +919876543210
/// - 09876543210
/// - 98765-43210
String normalizePhoneNumber(String phone) => PhoneNormalizer.last10(phone);

class AppValidators {
  /// Regular expression to match standard email formats.
  static final RegExp emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  /// Regular expression to match global phone number formats (with or without country code).
  static final RegExp phoneRegex = RegExp(
    r'\+?[0-9][0-9\- \(\)\.]{7,18}[0-9]',
  );

  /// Regular expression to match websites specifically for business cards
  static final RegExp urlRegex = RegExp(
    r'(www\.|https?:\/\/|\.com\b|\.in\b|\.co\b|\.org\b|\.net\b)',
    caseSensitive: false,
  );

  /// General Website Regex for parsing URLs
  static final RegExp websiteRegex = RegExp(
    r'(https?:\/\/)?(www\.)?[a-zA-Z0-9-]+\.[a-zA-Z]{2,3}(\.[a-zA-Z]{2,})?(\/[^\s]*)?',
    caseSensitive: false,
  );

  /// Checks if the given string has a valid email.
  static bool hasEmail(String text) => emailRegex.hasMatch(text);

  /// Checks if the given string has a valid phone number.
  static bool hasPhone(String text) => phoneRegex.hasMatch(text);

  /// Checks if the given string has a valid URL.
  static bool hasUrl(String text) => urlRegex.hasMatch(text);
}

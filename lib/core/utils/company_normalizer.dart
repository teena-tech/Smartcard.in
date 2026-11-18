/// Centralized company name normalization and similarity comparator.
/// Handles punctuation, casing, extra whitespace, and legal entity suffixes
/// (e.g., "ABC Technologies Pvt. Ltd." vs "abc technologies").
class CompanyNormalizer {
  /// Cleans and normalizes a company name.
  static String normalize(String company) {
    if (company.trim().isEmpty) return '';
    var s = company.toLowerCase().trim();

    // Replace punctuation with space
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');

    // Collapse multiple whitespace characters into a single space
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove common corporate suffixes for accurate comparison
    const suffixes = [
      'private limited',
      'pvt ltd',
      'pvt limited',
      'pvt',
      'limited',
      'ltd',
      'incorporated',
      'inc',
      'corporation',
      'corp',
      'company',
      'co',
      'llc',
      'llp',
      'gmbh',
      'technologies',
      'technology',
      'tech',
      'solutions',
      'services',
      'enterprises',
      'enterprise',
      'group',
      'consulting',
      'consultancy',
      'holdings',
      'holding',
      'industries',
      'industry',
      'international',
      'global',
      'agency',
      'labs',
    ];

    bool changed = true;
    while (changed) {
      changed = false;
      for (final suf in suffixes) {
        if (s.endsWith(' $suf') && s.length > suf.length + 1) {
          final remainder = s.substring(0, s.length - (suf.length + 1)).trim();
          if (remainder.isNotEmpty) {
            s = remainder;
            changed = true;
            break;
          }
        }
      }
    }

    return s;
  }

  /// Determines whether two company names are the same or substantially similar.
  ///
  /// Requirement:
  /// "If company information is missing from either card, do not automatically classify
  /// it as a different company solely because the company field is empty."
  static bool isSimilar(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);

    // If either is missing/empty, do not automatically treat as different
    if (na.isEmpty || nb.isEmpty) return true;

    // Exact normalized match
    if (na == nb) return true;

    const stopWords = {
      'company',
      'co',
      'corporation',
      'corp',
      'incorporated',
      'inc',
      'limited',
      'ltd',
      'private',
      'pvt',
      'llc',
      'llp',
      'gmbh',
      'technologies',
      'technology',
      'tech',
      'solutions',
      'solution',
      'services',
      'service',
      'enterprise',
      'enterprises',
      'group',
      'holdings',
      'consulting',
      'consultancy',
      'industries',
      'industry',
      'international',
      'global',
      'agency',
      'labs',
      'and',
      'the',
      'of',
    };

    // Substring match with word boundaries (e.g., "Google Cloud" vs "Google")
    if (na.isNotEmpty && nb.isNotEmpty) {
      final regA = RegExp(r'\b' + RegExp.escape(na) + r'\b');
      final regB = RegExp(r'\b' + RegExp.escape(nb) + r'\b');
      if (regA.hasMatch(nb) || regB.hasMatch(na)) {
        final shorter = na.length <= nb.length ? na : nb;
        if (!stopWords.contains(shorter)) {
          return true;
        }
      }
    }

    // Word token overlap excluding common generic corporate stop words
    final wordsA = na
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet();
    final wordsB = nb
        .split(' ')
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet();
    if (wordsA.isNotEmpty && wordsB.isNotEmpty) {
      final intersection = wordsA.intersection(wordsB);
      if (intersection.isNotEmpty) return true;
    }

    return false;
  }
}

import '../../models/scanned_contact_model.dart';
import 'app_validators.dart';

class ContactParser {
  /// Parses raw text extracted from a business card and returns a [ScannedContactModel].
  static ScannedContactModel parse(String rawText) {
    // Clean unwanted symbols and clean OCR artifacts
    final cleanedText = _cleanOcrText(rawText);
    
    // Split text into lines, trim, and filter out empty/duplicate lines
    final List<String> lines = cleanedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    // Unique lines to prevent double-processing
    final List<String> uniqueLines = [];
    for (var line in lines) {
      if (!uniqueLines.contains(line)) {
        uniqueLines.add(line);
      }
    }

    String? name;
    String? designation;
    String? companyName;
    String? phone;
    String? alternativePhone;
    String? landline;
    String? whatsApp;
    String? email;
    String? website;
    String? address;
    String? pinCode;
    final List<String> socialLinks = [];

    // 1. Identify Emails
    final emailRegex = AppValidators.emailRegex;
    for (final line in uniqueLines) {
      final match = emailRegex.firstMatch(line);
      if (match != null) {
        email = match.group(0);
        break;
      }
    }

    // 2. Identify Phones (Mobile, Alternative, Landline, WhatsApp, Additional)
    final phoneRegex = RegExp(r'(\+?\d[\d\-\s\(\)\.]{6,16}\d)');
    final List<String> allDetectedPhones = [];
    final Set<String> seenPhoneDigits = {};
    final List<String> additionalPhones = [];

    void addPhoneCandidate(String candidate, {bool isWa = false, bool isLand = false}) {
      final clean = candidate.replaceAll(RegExp(r'^(mob(ile)?|tel(ephone)?|ph(one)?|cell|p|m|t|alt|f|fax|wa|whatsapp|landline|work|office|contact)\s*[:\-\.]?\s*', caseSensitive: false), '').trim();
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 7 && digits.length <= 16) {
        final norm = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
        if (seenPhoneDigits.add(norm)) {
          final formatted = _formatPhoneNumber(clean);
          allDetectedPhones.add(formatted);
          if (isWa && whatsApp == null) {
            whatsApp = formatted;
          }
          if (isLand && landline == null) {
            landline = formatted;
          }
        }
      }
    }

    for (final line in uniqueLines) {
      if (line.contains('@') || line.toLowerCase().contains('www.') || line.toLowerCase().contains('http')) {
        continue;
      }
      final lowerLine = line.toLowerCase();
      final isWa = lowerLine.contains('whatsapp') || lowerLine.contains('wa:') || lowerLine.contains('wa ');
      final isLand = lowerLine.contains('landline') || lowerLine.contains('tel:') || lowerLine.contains('land');

      // Split lines with multiple phone numbers (e.g. +91 90728 63555 / 90720 20000 | 044-2456789)
      final subChunks = line.split(RegExp(r'[/,|;\\]|\s+(?:or|and|&)\s+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final chunk in subChunks) {
        final matches = phoneRegex.allMatches(chunk);
        if (matches.isNotEmpty) {
          for (final m in matches) {
            final matchedStr = m.group(0);
            if (matchedStr != null && matchedStr.isNotEmpty) {
              addPhoneCandidate(matchedStr, isWa: isWa, isLand: isLand);
            }
          }
        } else if (chunk.replaceAll(RegExp(r'\D'), '').length >= 7) {
          addPhoneCandidate(chunk, isWa: isWa, isLand: isLand);
        }
      }
    }

    // Assign Phone fields without overwriting
    if (allDetectedPhones.isNotEmpty) {
      phone = allDetectedPhones[0];
      if (allDetectedPhones.length > 1) {
        alternativePhone = allDetectedPhones[1];
      }
      if (allDetectedPhones.length > 2) {
        additionalPhones.addAll(allDetectedPhones.sublist(2));
      }
    }
    whatsApp ??= phone;

    bool isPhoneLine(String line) {
      if (phoneRegex.hasMatch(line)) return true;
      final clean = line.replaceAll(RegExp(r'\D'), '');
      if (clean.length >= 7) return true;
      return allDetectedPhones.any((p) => line.contains(p) || p.contains(line));
    }

    // 3. Identify Website / URL
    final websiteRegex = AppValidators.websiteRegex;
    for (final line in uniqueLines) {
      if (line.contains('@')) continue; // Skip email lines

      final match = websiteRegex.firstMatch(line);
      if (match != null) {
        final matchedStr = match.group(0)!;
        if (matchedStr.toLowerCase().contains('www.') ||
            matchedStr.toLowerCase().startsWith('http') ||
            line.toLowerCase().endsWith('.com') ||
            line.toLowerCase().endsWith('.in') ||
            line.toLowerCase().endsWith('.org') ||
            line.toLowerCase().endsWith('.co') ||
            line.toLowerCase().endsWith('.net')) {
          website = matchedStr;
          break;
        }
      }
    }

    // 4. Identify Social Media Links
    final socialRegex = RegExp(
      r'(linkedin\.com|twitter\.com|github\.com|facebook\.com|instagram\.com|x\.com)\/[a-zA-Z0-9_\-\.]+',
      caseSensitive: false,
    );
    for (final line in uniqueLines) {
      final match = socialRegex.firstMatch(line);
      if (match != null) {
        socialLinks.add(match.group(0)!);
      }
    }

    // 5. Identify Designation / Job Title
    final List<String> designationKeywords = [
      'manager', 'director', 'developer', 'engineer', 'founder', 'ceo', 'cto', 'co-founder',
      'executive', 'consultant', 'president', 'specialist', 'designer', 'partner', 'analyst',
      'accountant', 'architect', 'lead', 'head', 'representative', 'officer', 'supervisor',
      'programmer', 'expert', 'strategist', 'technician', 'consulting', 'vp', 'vice president',
      'owner', 'principal', 'chairman', 'proprietor', 'agent'
    ];

    for (final line in uniqueLines) {
      final lowerLine = line.toLowerCase();
      bool hasKeyword = designationKeywords.any((kw) => lowerLine.contains(kw));
      bool isPhone = isPhoneLine(line);
      if (hasKeyword && line != email && !isPhone && line != website) {
        designation = line;
        break;
      }
    }

    // 6. Identify Company Name
    final List<String> companySuffixes = [
      'inc', 'ltd', 'corp', 'solutions', 'technologies', 'group', 'pvt', 'private',
      'limited', 'association', 'agency', 'media', 'design', 'software', 'ventures',
      'consulting', 'firm', 'industries', 'co', 'llc', 'llp', 'systems', 'services'
    ];

    for (final line in uniqueLines) {
      final lowerLine = line.toLowerCase();
      bool hasSuffix = companySuffixes.any((suffix) {
        final reg = RegExp('\\b$suffix\\b|\\b$suffix\\.', caseSensitive: false);
        return reg.hasMatch(lowerLine);
      });
      bool isPhone = isPhoneLine(line);

      if (hasSuffix && line != email && !isPhone && line != website && line != designation) {
        companyName = line;
        break;
      }
    }

    // 7. Identify PIN Code (5 or 6 digit number)
    final pinRegex = RegExp(r'\b([1-9][0-9]{4,5})\b');
    for (final line in uniqueLines) {
      final match = pinRegex.firstMatch(line);
      if (match != null) {
        // Verify it isn't part of any parsed phone numbers
        final potentialPin = match.group(0)!;
        bool isPhone = false;
        for (var p in allDetectedPhones) {
          if (p.contains(potentialPin)) isPhone = true;
        }
        if (!isPhone) {
          pinCode = potentialPin;
          break;
        }
      }
    }

    // 8. Identify Address
    final List<String> addressKeywords = [
      'street', 'road', 'rd', 'ave', 'avenue', 'lane', 'ln', 'drive', 'dr', 'court', 'ct',
      'plaza', 'building', 'bldg', 'floor', 'fl', 'suite', 'ste', 'sector', 'sec', 'city',
      'state', 'zip', 'pin', 'code', 'box', 'p.o.', 'po box', 'india', 'usa', 'near',
      'opposite', 'opp', 'phase', 'nagar', 'colony', 'block', 'dist', 'district', 'building'
    ];

    final List<String> addressLines = [];
    for (final line in uniqueLines) {
      bool isPhone = isPhoneLine(line);
      if (line == email || isPhone || line == website || line == designation || line == companyName) {
        continue;
      }
      final lowerLine = line.toLowerCase();
      bool isAddress = addressKeywords.any((kw) => lowerLine.contains(kw)) ||
          RegExp(r'\b[0-9]{5,6}\b').hasMatch(line) ||
          (line.contains(',') && RegExp(r'[0-9]').hasMatch(line));

      if (isAddress) {
        addressLines.add(line);
      }
    }
    if (addressLines.isNotEmpty) {
      address = addressLines.join(', ');
    }

    // 9. Identify Person Name (Heuristics)
    for (final line in uniqueLines) {
      bool isPhone = isPhoneLine(line);
      if (line == email ||
          isPhone ||
          line == website ||
          line == designation ||
          line == companyName ||
          addressLines.contains(line) ||
          socialLinks.contains(line)) {
        continue;
      }

      // Skip lines that are too short or long, or purely digits
      if (line.length < 3 || line.length > 30) continue;
      if (RegExp(r'^[0-9\-\+\s\(\)\.\,]+$').hasMatch(line)) continue;

      name = line;
      break;
    }

    // Fallback Values
    name ??= (uniqueLines.isNotEmpty ? uniqueLines.first : 'Scanned Contact');
    designation ??= '';
    companyName ??= '';
    phone ??= '';
    email ??= '';
    website ??= '';
    address ??= '';

    // Clean address if it accidentally included name
    if (address.contains(name)) {
      address = address.replaceAll(name, '').trim();
      if (address.startsWith(',')) address = address.substring(1).trim();
    }

    return ScannedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      company: companyName,
      designation: designation,
      phone: phone,
      alternativePhone: alternativePhone,
      additionalPhones: additionalPhones,
      landline: landline,
      whatsApp: whatsApp,
      email: email,
      website: website,
      address: address,
      pinCode: pinCode,
      socialLinks: socialLinks,
      createdAt: DateTime.now(),
    );
  }

  /// Formats phone numbers to international standard if possible (+XX XXXXX XXXXX).
  static String _formatPhoneNumber(String input) {
    // Remove formatting characters like space, dash, parenthesis
    final digits = input.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If it starts with + and has 12 digits (like +919876543210)
    if (digits.startsWith('+') && digits.length >= 12) {
      final countryCode = digits.substring(0, 3);
      final remaining = digits.substring(3);
      if (remaining.length == 10) {
        return '$countryCode ${remaining.substring(0, 5)} ${remaining.substring(5)}';
      }
    }
    
    // Standard 10 digits number
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    
    return input; // return as is if format cannot be applied
  }

  /// Removes common OCR noise and unwanted symbol sets
  static String _cleanOcrText(String text) {
    return text
        .replaceAll(RegExp(r'[•°*©®]|\[\]|\|'), '') // symbols
        .replaceAll(RegExp(r' {2,}'), ' ') // multiple spaces
        .trim();
  }

  /// Parses a vCard string into a [ScannedContactModel].
  static ScannedContactModel parseVCard(String vcardText) {
    String name = '';
    String company = '';
    String designation = '';
    String phone = '';
    String? alternativePhone;
    String? landline;
    String? whatsApp;
    String email = '';
    String website = '';
    String address = '';
    String? pinCode;
    String? profileImage;

    // Unfold RFC 2426/6350 folded lines before parsing (CRLF/LF followed by space/tab)
    final unfolded = vcardText.replaceAll(RegExp(r'\r?\n[ \t]'), '');
    final lines = unfolded.split(RegExp(r'\r?\n'));
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      final upperLine = line.toUpperCase();
      if (upperLine.startsWith('FN:')) {
        name = line.substring(3).trim();
      } else if (upperLine.startsWith('N:') && name.isEmpty) {
        final parts = line.substring(2).split(';');
        final first = parts.length > 1 ? parts[1].trim() : '';
        final last = parts.isNotEmpty ? parts[0].trim() : '';
        name = '$first $last'.trim();
      } else if (upperLine.startsWith('ORG:')) {
        final parts = line.substring(4).split(';');
        company = parts.isNotEmpty ? parts[0].trim() : '';
      } else if (upperLine.startsWith('TITLE:')) {
        designation = line.substring(6).trim();
      } else if (upperLine.startsWith('TEL;') || upperLine.startsWith('TEL:')) {
        final idx = line.indexOf(':');
        if (idx != -1) {
          final val = _unwrapBracketedScalar(line.substring(idx + 1).trim());
          if (val.isEmpty) continue;
          if (upperLine.contains('FAX') || upperLine.contains('LANDLINE')) {
            landline = val;
          } else if (upperLine.contains('WHATSAPP') || upperLine.contains('WA')) {
            whatsApp = val;
          } else if (phone.isEmpty) {
            phone = val;
          } else if (upperLine.contains('WORK') || upperLine.contains('ALT')) {
            alternativePhone = val;
          } else {
            alternativePhone = val;
          }
        }
      } else if (upperLine.startsWith('EMAIL:') || RegExp(r'^EMAIL;.*:', caseSensitive: false).hasMatch(line)) {
        final idx = line.indexOf(':');
        if (idx != -1) {
          email = _unwrapBracketedScalar(line.substring(idx + 1).trim());
        }
      } else if (upperLine.startsWith('URL:') || RegExp(r'^URL;.*:', caseSensitive: false).hasMatch(line)) {
        final idx = line.indexOf(':');
        if (idx != -1) {
          website = line.substring(idx + 1).trim();
        }
      } else if (upperLine.startsWith('ADR:') || RegExp(r'^ADR;.*:', caseSensitive: false).hasMatch(line)) {
        final idx = line.indexOf(':');
        if (idx != -1) {
          final parts = line.substring(idx + 1).split(';');
          address = parts.where((p) => p.trim().isNotEmpty).join(', ').trim();
          
          // Try to extract PIN code from address parts
          final pinMatch = RegExp(r'\b([1-9][0-9]{4,5})\b').firstMatch(address);
          if (pinMatch != null) {
            pinCode = pinMatch.group(0);
          }
        }
      } else if (upperLine.startsWith('PHOTO;') || upperLine.startsWith('PHOTO:')) {
        final idx = line.indexOf(':');
        if (idx != -1) {
          final header = upperLine.substring(0, idx);
          final val = line.substring(idx + 1).trim();
          if (val.isNotEmpty &&
              val.toLowerCase() != 'null' &&
              val.toLowerCase() != 'undefined') {
            profileImage = _normalizeVCardPhoto(header, val);
          }
        }
      }
    }

    String unescapeVCard(String val) =>
        val.replaceAll(r'\,', ',').replaceAll(r'\;', ';').replaceAll(r'\\', r'\');

    // Clean name
    name = unescapeVCard(name).replaceAll(';', ' ').replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    company = unescapeVCard(company).trim();
    designation = unescapeVCard(designation).trim();
    if (name.isEmpty) name = 'QR Contact';
    whatsApp ??= phone.isNotEmpty ? phone : null;

    return ScannedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      company: company,
      designation: designation,
      phone: phone,
      alternativePhone: alternativePhone,
      landline: landline,
      whatsApp: whatsApp,
      email: email,
      website: website,
      address: address,
      pinCode: pinCode,
      profileImage: profileImage,
      socialLinks: const [],
      createdAt: DateTime.now(),
    );
  }

  static String _unwrapBracketedScalar(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[')) {
      final m = RegExp(r'''^\[\s*["']([^"']+)["']''').firstMatch(trimmed);
      if (m != null) return m.group(1)!.trim();
    }
    return trimmed;
  }

  static String _normalizeVCardPhoto(String upperHeader, String rawValue) {
    final val = rawValue.trim();
    if (val.startsWith('http://') ||
        val.startsWith('https://') ||
        val.startsWith('data:')) {
      return val;
    }
    final looksBase64 = upperHeader.contains('ENCODING=B') ||
        upperHeader.contains('BASE64') ||
        val.startsWith('/9j/') ||
        val.startsWith('iVBOR') ||
        val.startsWith('UklGR') ||
        val.startsWith('R0lGOD');
    if (!looksBase64) return val;

    final String subtype;
    if (upperHeader.contains('PNG') || val.startsWith('iVBOR')) {
      subtype = 'png';
    } else if (upperHeader.contains('WEBP') || val.startsWith('UklGR')) {
      subtype = 'webp';
    } else if (upperHeader.contains('GIF') || val.startsWith('R0lGOD')) {
      subtype = 'gif';
    } else {
      subtype = 'jpeg';
    }
    final cleanB64 = val.replaceAll(RegExp(r'\s+'), '');
    return 'data:image/$subtype;base64,$cleanB64';
  }

  /// Parses a MECARD string into a [ScannedContactModel].
  static ScannedContactModel parseMeCard(String mecardText) {
    String name = '';
    String company = '';
    String designation = '';
    String phone = '';
    String? alternativePhone;
    String? landline;
    String? whatsApp;
    String email = '';
    String website = '';
    String address = '';
    String? pinCode;

    // MECARD:N:name;TEL:phone;...
    final content = mecardText.substring(7);
    final fields = content.split(';');
    for (var field in fields) {
      field = field.trim();
      final upperField = field.toUpperCase();
      if (upperField.startsWith('N:')) {
        name = field.substring(2).replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      } else if (upperField.startsWith('ORG:')) {
        company = field.substring(4).trim();
      } else if (upperField.startsWith('TEL:')) {
        final val = field.substring(4).trim();
        if (phone.isEmpty) {
          phone = val;
        } else {
          alternativePhone = val;
        }
      } else if (upperField.startsWith('EMAIL:')) {
        email = field.substring(6).trim();
      } else if (upperField.startsWith('URL:')) {
        website = field.substring(4).trim();
      } else if (upperField.startsWith('ADR:')) {
        address = field.substring(4).replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
        final pinMatch = RegExp(r'\b([1-9][0-9]{4,5})\b').firstMatch(address);
        if (pinMatch != null) {
          pinCode = pinMatch.group(0);
        }
      }
    }

    if (name.isEmpty) name = 'QR Contact';
    if (company.isEmpty) company = '';
    if (designation.isEmpty) designation = '';
    whatsApp ??= phone.isNotEmpty ? phone : null;

    return ScannedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      company: company,
      designation: designation,
      phone: phone,
      alternativePhone: alternativePhone,
      landline: landline,
      whatsApp: whatsApp,
      email: email,
      website: website,
      address: address,
      pinCode: pinCode,
      socialLinks: const [],
      createdAt: DateTime.now(),
    );
  }

  /// Smart routing to detect format and parse QR value
  static ScannedContactModel parseQrCode(String code) {
    final trimmed = code.trim();
    final upper = trimmed.toUpperCase();
    if (upper.contains('BEGIN:VCARD')) {
      return parseVCard(trimmed);
    } else if (upper.startsWith('MECARD:')) {
      return parseMeCard(trimmed);
    } else if (upper.startsWith('MAILTO:')) {
      return ScannedContactModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'QR Contact',
        company: '',
        designation: '',
        phone: '',
        email: trimmed.substring(7).split('?').first,
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );
    } else if (upper.startsWith('TEL:')) {
      return ScannedContactModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'QR Contact',
        company: '',
        designation: '',
        phone: trimmed.substring(4).trim(),
        email: '',
        website: '',
        address: '',
        socialLinks: const [],
        createdAt: DateTime.now(),
      );
    } else if (upper.startsWith('HTTP://') ||
        upper.startsWith('HTTPS://') ||
        upper.startsWith('WWW.')) {
      final url = upper.startsWith('WWW.') ? 'https://$trimmed' : trimmed;
      return ScannedContactModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Website Contact',
        company: '',
        designation: '',
        phone: '',
        email: '',
        website: url,
        address: '',
        socialLinks: [url],
        createdAt: DateTime.now(),
      );
    } else {
      return parse(trimmed);
    }
  }
}

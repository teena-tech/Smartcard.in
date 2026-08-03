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

    // 2. Identify Phones (Mobile, Alternative, Landline, WhatsApp)
    final phoneRegex = AppValidators.phoneRegex;
    final List<String> mobileList = [];
    final List<String> landlineList = [];
    final List<String> whatsappList = [];
    final List<String> otherList = [];

    for (final line in uniqueLines) {
      // Avoid parsing emails or websites as phone numbers
      if (line.contains('@') || line.toLowerCase().contains('www.') || line.toLowerCase().contains('http')) {
        continue;
      }
      final match = phoneRegex.firstMatch(line);
      if (match != null) {
        final lowerLine = line.toLowerCase();
        // Handle slash or comma separated multiple numbers in single line (e.g. +91 90728 63555 / 90720 20000)
        final subNumbers = line.split(RegExp(r'[/,]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        for (final subNum in subNumbers) {
          if (!phoneRegex.hasMatch(subNum)) continue;
          String cleanPhone = subNum.replaceAll(RegExp(r'^(mob(ile)?|tel(ephone)?|ph(one)?|cell|p|m|t|alt|f|fax|wa|whatsapp|landline|work)\s*[:\-\.]?\s*', caseSensitive: false), '').trim();
          cleanPhone = cleanPhone.replaceAll(RegExp(r'[^\d+\-\s\(\)]'), '').trim();

          if (cleanPhone.isNotEmpty) {
            if (lowerLine.contains('whatsapp') || lowerLine.contains('wa:') || lowerLine.contains('wa ')) {
              whatsappList.add(cleanPhone);
            } else if (lowerLine.contains('landline') || lowerLine.contains('tel:') || lowerLine.contains('land') || (cleanPhone.startsWith('0') && !cleanPhone.startsWith('09') && !cleanPhone.startsWith('08') && !cleanPhone.startsWith('07'))) {
              landlineList.add(cleanPhone);
            } else if (lowerLine.contains('mob') || lowerLine.contains('cell') || lowerLine.contains('m:')) {
              mobileList.add(cleanPhone);
            } else {
              otherList.add(cleanPhone);
            }
          }
        }
      }
    }

    // Assign Phone fields
    if (mobileList.isNotEmpty) {
      phone = _formatPhoneNumber(mobileList[0]);
      if (mobileList.length > 1) {
        alternativePhone = _formatPhoneNumber(mobileList[1]);
      }
    } else if (otherList.isNotEmpty) {
      phone = _formatPhoneNumber(otherList[0]);
      if (otherList.length > 1) {
        alternativePhone = _formatPhoneNumber(otherList[1]);
      }
    }

    if (whatsappList.isNotEmpty) {
      whatsApp = _formatPhoneNumber(whatsappList[0]);
    } else if (phone != null) {
      whatsApp = phone; // Fallback WhatsApp to primary phone number
    }

    if (landlineList.isNotEmpty) {
      landline = _formatPhoneNumber(landlineList[0]);
      phone ??= landline;
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
      bool isPhone = mobileList.contains(line) || landlineList.contains(line) || otherList.contains(line);
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
      bool isPhone = mobileList.contains(line) || landlineList.contains(line) || otherList.contains(line);

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
        for (var p in [...mobileList, ...landlineList, ...otherList]) {
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
      bool isPhone = phoneRegex.hasMatch(line) || mobileList.contains(line) || landlineList.contains(line) || otherList.contains(line);
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
      bool isPhone = mobileList.contains(line) || landlineList.contains(line) || otherList.contains(line);
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
    designation ??= 'Professional';
    companyName ??= 'Unknown Company';
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

    final lines = vcardText.split(RegExp(r'\r?\n'));
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
          final val = line.substring(idx + 1).trim();
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
          email = line.substring(idx + 1).trim();
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
      }
    }

    // Clean name
    name = name.replaceAll(';', ' ').replaceAll(',', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty) name = 'QR Contact';
    if (company.isEmpty) company = 'Unknown Company';
    if (designation.isEmpty) designation = 'Professional';
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
    if (company.isEmpty) company = 'Unknown Company';
    if (designation.isEmpty) designation = 'Professional';
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
        company: 'Unknown Company',
        designation: 'Professional',
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
        company: 'Unknown Company',
        designation: 'Professional',
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
        company: 'Unknown Company',
        designation: 'Professional',
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

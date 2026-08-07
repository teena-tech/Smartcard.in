import 'package:flutter/foundation.dart';
import '../../../models/scanned_contact_model.dart';

class ContactParserService {
  /// Extracts structured contact info (name, company, designation, phone, email, website, address)
  /// from raw OCR text blocks using regex and layout heuristics.
  ScannedContactModel parseText(String rawText, {String? imagePath, String? source = 'camera'}) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String name = '';
    String company = '';
    String designation = '';
    String phone = '';
    String? altPhone;
    String email = '';
    String website = '';
    List<String> addressParts = [];
    String? pinCode;

    // Regex Patterns
    final emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    final websiteRegex = RegExp(r'(https?://)?(www\.)?[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+', caseSensitive: false);
    final phoneRegex = RegExp(r'(\+?\d{1,4}[-.\s]?)?\(?\d{3,5}\)?[-.\s]?\d{3,5}[-.\s]?\d{3,5}');
    final pinCodeRegex = RegExp(r'\b\d{6}\b'); // Indian pincodes

    final companyKeywords = [
      'pvt', 'ltd', 'inc', 'corp', 'corporation', 'technologies', 'solutions',
      'group', 'enterprises', 'co.', 'company', 'services', 'systems', 'studio',
      'agency', 'labs', 'industries', 'infotech', 'consultancy', 'consulting'
    ];

    final designationKeywords = [
      'manager', 'director', 'engineer', 'founder', 'co-founder', 'ceo', 'cto',
      'cfo', 'vp', 'vice president', 'president', 'developer', 'executive',
      'consultant', 'architect', 'lead', 'head', 'officer', 'partner', 'specialist',
      'designer', 'analyst', 'associate', 'advisor', 'managing director'
    ];

    final remainingLines = <String>[];

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Email match
      if (email.isEmpty && emailRegex.hasMatch(line)) {
        email = emailRegex.firstMatch(line)?.group(0) ?? '';
        continue;
      }

      // Website match
      if (website.isEmpty && websiteRegex.hasMatch(line) && !line.contains('@')) {
        final match = websiteRegex.firstMatch(line)?.group(0) ?? '';
        if (match.toLowerCase() != 'com' && match.contains('.')) {
          website = match.startsWith('http') ? match : 'www.$match'.replaceAll('www.www.', 'www.');
          continue;
        }
      }

      // Phone match
      if (phoneRegex.hasMatch(line) && (lower.contains('tel') || lower.contains('mob') || lower.contains('ph') || lower.contains('+') || line.replaceAll(RegExp(r'\D'), '').length >= 10)) {
        final digitsOnly = line.replaceAll(RegExp(r'[^\d+]'), '');
        if (digitsOnly.length >= 8) {
          if (phone.isEmpty) {
            phone = line;
          } else if (altPhone == null && line != phone) {
            altPhone = line;
          }
          continue;
        }
      }

      // Designation match
      if (designation.isEmpty && designationKeywords.any((kw) => lower.contains(kw))) {
        designation = line;
        continue;
      }

      // Company match
      if (company.isEmpty && companyKeywords.any((kw) => lower.contains(kw))) {
        company = line;
        continue;
      }

      // Pincode match
      if (pinCode == null && pinCodeRegex.hasMatch(line)) {
        pinCode = pinCodeRegex.firstMatch(line)?.group(0);
      }

      remainingLines.add(line);
    }

    // Heuristics for Name & remaining fields
    for (int i = 0; i < remainingLines.length; i++) {
      final line = remainingLines[i];
      final lower = line.toLowerCase();

      // Skip lines that look like addresses or social handles
      if (lower.contains('road') || lower.contains('street') || lower.contains('nagar') ||
          lower.contains('floor') || lower.contains('suite') || lower.contains('city') ||
          lower.contains('state') || lower.contains('india') || lower.contains('chennai') ||
          lower.contains('bangalore') || lower.contains('mumbai') || lower.contains('delhi')) {
        addressParts.add(line);
        continue;
      }

      if (name.isEmpty && _isLikelyName(line)) {
        name = line;
      } else if (company.isEmpty && i < 3 && line.length > 2) {
        company = line;
      } else {
        addressParts.add(line);
      }
    }

    // Fallbacks
    if (name.isEmpty && remainingLines.isNotEmpty) {
      name = remainingLines.first;
    }

    final fullAddress = addressParts.join(', ');

    return ScannedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.isEmpty ? 'Scanned Contact' : name,
      company: company,
      designation: designation,
      phone: phone,
      alternativePhone: altPhone,
      email: email,
      website: website,
      address: fullAddress,
      pinCode: pinCode,
      socialLinks: const [],
      imagePath: imagePath,
      createdAt: DateTime.now(),
      source: source ?? 'camera',
    );
  }

  bool _isLikelyName(String line) {
    if (line.length < 2 || line.length > 40) return false;
    // Names usually start with capital letters and don't contain digits or excessive symbols
    final nameRegex = RegExp(r"^[A-Z][a-zA-Z\s\.'\-]+$");
    return nameRegex.hasMatch(line) && !line.contains('http') && !line.contains('www');
  }
}

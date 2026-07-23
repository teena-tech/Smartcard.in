import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import '../../models/scanned_contact_model.dart';
import '../utils/business_card_validator.dart';
import '../utils/contact_parser.dart';
import 'scanner_api_service.dart';

class QrExtractionService {
  static const Duration _apiTimeout = Duration(seconds: 8);

  static Future<ScannedContactModel> extract(String qrValue) async {
    final trimmed = qrValue.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty QR code');
    }

    if (!BusinessCardValidator.validateQr(trimmed)) {
      throw Exception('Invalid QR contact format');
    }

    if (_isUrl(trimmed)) {
      final fromApi = await _fetchFromApi(trimmed);
      if (fromApi != null) return fromApi;
    }

    if (_isWhatsAppLink(trimmed)) {
      return _parseWhatsApp(trimmed);
    }

    if (trimmed.toLowerCase().startsWith('mailto:')) {
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
    }

    if (trimmed.toLowerCase().startsWith('tel:')) {
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
    }

    return ContactParser.parseQrCode(trimmed);
  }

  static bool _isUrl(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.');
  }

  static bool _isWhatsAppLink(String value) {
    final lower = value.toLowerCase();
    return lower.contains('wa.me/') ||
        lower.contains('api.whatsapp.com') ||
        lower.contains('chat.whatsapp.com');
  }

  static ScannedContactModel _parseWhatsApp(String link) {
    String phone = '';
    final phoneMatch = RegExp(r'(?:phone=|wa\.me/)(\d+)').firstMatch(link);
    if (phoneMatch != null) {
      phone = '+${phoneMatch.group(1)}';
    }

    return ScannedContactModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'WhatsApp Contact',
      company: 'Unknown Company',
      designation: 'Professional',
      phone: phone,
      whatsApp: phone,
      email: '',
      website: link,
      address: '',
      socialLinks: [link],
      createdAt: DateTime.now(),
    );
  }

  static Future<ScannedContactModel?> _fetchFromApi(String qrValue) async {
    try {
      final extractedValue = _extractScValue(qrValue);
      final response = await ScannerApiService.instance
          .previewContact({'qr_value': extractedValue})
          .timeout(_apiTimeout);

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        String cleanWebsite = '';
        final rawWeb = data['website'] ?? data['url'];
        if (rawWeb != null) {
          if (rawWeb is List) {
            cleanWebsite = rawWeb.map((w) {
              if (w is Map) return (w['url'] ?? w['name'] ?? '').toString();
              return w.toString();
            }).where((s) => s.isNotEmpty).join('\n');
          } else {
            final str = rawWeb.toString().trim();
            if (str.startsWith('[')) {
              try {
                final List parsed = jsonDecode(str);
                cleanWebsite = parsed.map((w) {
                  if (w is Map) return (w['url'] ?? w['name'] ?? '').toString();
                  return w.toString();
                }).where((s) => s.isNotEmpty).join('\n');
              } catch (_) {
                cleanWebsite = str;
              }
            } else {
              cleanWebsite = str;
            }
          }
        }

        String cleanWhatsapp = '';
        final rawWa = data['whatsapp'] ?? data['whatsapp_number'];
        if (rawWa != null) {
          if (rawWa is List) {
            cleanWhatsapp = rawWa.map((e) => e.toString()).where((s) => s.isNotEmpty).join('\n');
          } else {
            final str = rawWa.toString().trim();
            if (str.startsWith('[')) {
              try {
                final List parsed = jsonDecode(str);
                cleanWhatsapp = parsed.map((e) => e.toString()).where((s) => s.isNotEmpty).join('\n');
              } catch (_) {
                cleanWhatsapp = str;
              }
            } else {
              cleanWhatsapp = str;
            }
          }
        }

        List<String> socialLinksList = [];
        final rawSocial = data['social_links'] ?? data['socialLinks'];
        if (rawSocial != null) {
          if (rawSocial is List) {
            socialLinksList = rawSocial.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
          } else {
            final str = rawSocial.toString().trim();
            if (str.startsWith('[')) {
              try {
                final List parsed = jsonDecode(str);
                socialLinksList = parsed.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
              } catch (_) {
                if (str.isNotEmpty) socialLinksList = [str];
              }
            } else if (str.isNotEmpty) {
              socialLinksList = [str];
            }
          }
        }

        final addressParts = [
          data['address']?.toString(),
          data['district']?.toString(),
          data['state_name']?.toString(),
          data['pincode']?.toString(),
        ].where((s) => s != null && s.trim().isNotEmpty).join(', ');

        return ScannedContactModel(
          id: data['contact_user_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: (data['name'] ?? data['full_name'] ?? 'QR Contact').toString(),
          company: (data['company'] ?? data['company_name'] ?? 'Unknown Company').toString(),
          designation: (data['designation'] ?? data['title'] ?? 'Professional').toString(),
          phone: (data['phone'] ?? data['mobile'] ?? data['phone_number'] ?? '').toString(),
          alternativePhone: (data['alternate_phone'] ?? data['alt_phone'])?.toString(),
          whatsApp: cleanWhatsapp,
          email: (data['email'] ?? '').toString(),
          website: cleanWebsite,
          address: addressParts.isNotEmpty ? addressParts : (data['address'] ?? '').toString(),
          socialLinks: socialLinksList,
          createdAt: DateTime.now(),
        );
      }
    } on TimeoutException {
      debugPrint('QR API extraction timed out — using local parser');
    } catch (e) {
      debugPrint('QR API extraction failed: $e');
    }
    return null;
  }

  static String _extractScValue(String qrValue) {
    try {
      final trimmed = qrValue.trim();
      final uri = Uri.parse(trimmed);
      if (uri.queryParameters.containsKey('sc')) {
        return uri.queryParameters['sc']!;
      }
    } catch (_) {}
    return qrValue.trim();
  }
}

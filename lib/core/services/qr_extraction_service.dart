import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';
import 'package:smartcard_flutter/core/utils/business_card_validator.dart';
import 'package:smartcard_flutter/core/utils/contact_parser.dart';
import 'package:smartcard_flutter/core/services/scanner_api_service.dart';

class QrExtractionService {
  static const Duration _apiTimeout = Duration(seconds: 8);

  static bool _isSmartCardDomain(String value) {
    final lower = value.toLowerCase();
    return lower.contains('thesmartcards.com') ||
        lower.contains('thesmartcards.in') ||
        lower.contains('thesmartcards') ||
        lower.contains('thesmartcard') ||
        lower.contains('smartcards') ||
        lower.contains('smartcard') ||
        lower.contains('scard') ||
        lower.contains('localhost') ||
        lower.contains('127.0.0.1') ||
        lower.contains('10.0.2.2') ||
        lower.contains('192.168.');
  }

  static Future<ScannedContactModel> extract(String qrValue) async {
    final trimmed = qrValue.trim();
    if (trimmed.isEmpty) {
      throw Exception('Empty QR code');
    }

    if (!BusinessCardValidator.validateQr(trimmed)) {
      throw Exception('Invalid QR contact format');
    }

    if (_isUrl(trimmed)) {
      if (_isSmartCardDomain(trimmed)) {
        final fromApi = await _fetchFromApi(trimmed);
        if (fromApi != null) return fromApi;
      }

      // Fallback: parse URL or QR content gracefully if API preview fails or returns 404
      final parsedFallback = ContactParser.parseQrCode(trimmed);
      if (parsedFallback.phone.isNotEmpty || parsedFallback.email.isNotEmpty || (parsedFallback.name.isNotEmpty && parsedFallback.name != 'QR Contact')) {
        return parsedFallback;
      }

      // If URL contains a path or profile link, extract name from URL path segment
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        final lastSeg = uri.pathSegments.last.replaceAll(RegExp(r'[\-_]'), ' ').trim();
        if (lastSeg.isNotEmpty && lastSeg.toLowerCase() != 'profile') {
          final titleName = lastSeg.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ').trim();
          return ScannedContactModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: titleName.isNotEmpty ? titleName : 'SmartCard Contact',
            company: '',
            designation: '',
            phone: '',
            email: '',
            website: trimmed,
            address: '',
            socialLinks: [trimmed],
            createdAt: DateTime.now(),
          );
        }
      }

      throw Exception('Card not available in database.');
    }

    if (_isWhatsAppLink(trimmed)) {
      return _parseWhatsApp(trimmed);
    }

    if (trimmed.toLowerCase().startsWith('mailto:')) {
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
    }

    if (trimmed.toLowerCase().startsWith('tel:')) {
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
    }

    var parsed = ContactParser.parseQrCode(trimmed);
    final isSmartUrl =
        parsed.website.isNotEmpty && _isSmartCardDomain(parsed.website);
    final hasPhoto = parsed.profileImage != null &&
        parsed.profileImage!.trim().isNotEmpty &&
        parsed.profileImage!.trim().toLowerCase() != 'null';
    final isCompactInlinePhoto =
        parsed.profileImage?.trim().startsWith('data:') ?? false;

    if (isSmartUrl && (!hasPhoto || isCompactInlinePhoto)) {
      final fromApi = await _fetchFromApi(parsed.website);
      if (fromApi != null) {
        final apiPhoto = fromApi.matchedProfileImage ?? fromApi.profileImage;
        final mergedPhoto = (apiPhoto != null &&
                apiPhoto.trim().isNotEmpty &&
                apiPhoto.trim().toLowerCase() != 'null')
            ? apiPhoto
            : parsed.profileImage;
        return parsed.copyWith(
          profileImage: mergedPhoto,
          companyLogo: fromApi.companyLogo ?? parsed.companyLogo,
          matchedProfileImage: mergedPhoto,
          cardUrl: parsed.cardUrl ?? parsed.website,
          isMatched: parsed.isMatched || fromApi.isMatched || (mergedPhoto != null && mergedPhoto.isNotEmpty),
          matchedUserId: parsed.matchedUserId ?? fromApi.matchedUserId,
          socialLinks: fromApi.socialLinks.isNotEmpty ? fromApi.socialLinks : parsed.socialLinks,
          address: parsed.address.isNotEmpty ? parsed.address : fromApi.address,
        );
      }
    }

    if (isSmartUrl && parsed.cardUrl == null) {
      parsed = parsed.copyWith(
        cardUrl: parsed.website,
        matchedProfileImage: parsed.matchedProfileImage ??
            (hasPhoto ? parsed.profileImage : null),
      );
    }
    return parsed;
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
      company: '',
      designation: '',
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

        final userMap = data['user'] is Map ? data['user'] as Map : null;
        final cardMap = data['card'] is Map ? data['card'] as Map : null;
        final rawProfileImg = (data['profile_image'] ??
                data['profileImage'] ??
                data['profile_image_name'] ??
                data['profileImageName'] ??
                data['user_image'] ??
                data['userImage'] ??
                data['user_photo'] ??
                data['userPhoto'] ??
                data['photo'] ??
                data['image'] ??
                data['avatar'] ??
                cardMap?['profile_image'] ??
                cardMap?['profileImageName'] ??
                userMap?['profile_image'] ??
                userMap?['image'])
            ?.toString();
        final rawCompanyLogo = (data['company_logo'] ??
                data['logo'] ??
                data['companyLogo'] ??
                cardMap?['company_logo'] ??
                cardMap?['logo'])
            ?.toString();

        return ScannedContactModel(
          id: data['contact_user_id']?.toString() ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: (data['name'] ?? data['full_name'] ?? 'QR Contact').toString(),
          company: (data['company'] ?? data['company_name'] ?? '').toString(),
          designation: (data['designation'] ?? data['title'] ?? '').toString(),
          phone: (data['phone'] ?? data['mobile'] ?? data['phone_number'] ?? '').toString(),
          alternativePhone: (data['alternate_phone'] ?? data['alt_phone'])?.toString(),
          whatsApp: cleanWhatsapp,
          email: (data['email'] ?? '').toString(),
          website: cleanWebsite,
          address: addressParts.isNotEmpty ? addressParts : (data['address'] ?? '').toString(),
          socialLinks: socialLinksList,
          profileImage: (rawProfileImg != null &&
                  rawProfileImg.trim().isNotEmpty &&
                  rawProfileImg.trim().toLowerCase() != 'null' &&
                  rawProfileImg.trim().toLowerCase() != 'undefined')
              ? rawProfileImg.trim()
              : null,
          companyLogo: (rawCompanyLogo != null &&
                  rawCompanyLogo.trim().isNotEmpty &&
                  rawCompanyLogo.trim().toLowerCase() != 'null' &&
                  rawCompanyLogo.trim().toLowerCase() != 'undefined')
              ? rawCompanyLogo.trim()
              : null,
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
      if (uri.pathSegments.isNotEmpty) {
        final lastSegment = uri.pathSegments.last.trim();
        if (lastSegment.isNotEmpty && lastSegment.toLowerCase() != 'profile') {
          return lastSegment;
        }
      }
    } catch (_) {}
    return qrValue.trim();
  }
}

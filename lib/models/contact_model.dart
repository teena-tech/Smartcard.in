import 'package:http/http.dart' as http;

import '../core/services/vcard_photo_service.dart';

class ContactModel {
  final String id;
  final String name;
  final String designation;
  final String companyName;
  final String? profileImageInitial;
  final String? companyInitial;
  final String? phone;
  final String? email;
  final String? address;
  final String? website;
  final String? profileImageName;
  final String? companyLogo;
  final String? backgroundImage;
  final String? backgroundColor;
  final String? textColor;
  final String? bgImageColor;
  final dynamic opacity;

  ContactModel({
    this.id = '',
    required this.name,
    String? designation,
    String? jobTitle,
    String? companyName,
    String? company,
    this.profileImageInitial,
    this.companyInitial,
    this.phone,
    this.email,
    this.address,
    this.website,
    this.profileImageName,
    this.companyLogo,
    this.backgroundImage,
    this.backgroundColor,
    this.textColor,
    this.bgImageColor,
    this.opacity,
  })  : designation = jobTitle ?? designation ?? '',
        companyName = company ?? companyName ?? '';

  String get jobTitle => designation;
  String get company => companyName;

  /// Generates a standardized vCard 3.0 string for QR code generation or `.vcf` export.
  /// When [inlinePhotoBase64] is provided, embeds an inline JPEG (`PHOTO;ENCODING=b;TYPE=JPEG`)
  /// so Google Contacts, Android Contacts, and iOS Contacts load the contact photo reliably.
  String toVCard({
    String? inlinePhotoBase64,
    bool includePhotoUri = true,
    bool foldLines = false,
    bool useCrlf = false,
  }) {
    final eol = useCrlf ? '\r\n' : '\n';
    final lines = <String>[
      'BEGIN:VCARD',
      'VERSION:3.0',
    ];

    final trimmedName = name.trim();
    lines.add('FN:${_escapeVCard(trimmedName)}');

    final nameParts = trimmedName.split(' ');
    final lastName = nameParts.length > 1 ? nameParts.last : '';
    final firstName = nameParts.length > 1
        ? nameParts.sublist(0, nameParts.length - 1).join(' ')
        : trimmedName;
    lines.add('N:${_escapeVCard(lastName)};${_escapeVCard(firstName)};;;');

    final comp = _unwrapSingleJsonValue(companyName.isNotEmpty ? companyName : company);
    if (comp.isNotEmpty) {
      lines.add('ORG:${_escapeVCard(comp)}');
    }

    final title = _unwrapSingleJsonValue(designation.isNotEmpty ? designation : jobTitle);
    if (title.isNotEmpty) {
      lines.add('TITLE:${_escapeVCard(title)}');
    }

    if (phone != null && phone!.trim().isNotEmpty) {
      final cleanPhone = _unwrapSingleJsonValue(phone!);
      if (cleanPhone.isNotEmpty) {
        lines.add('TEL;TYPE=CELL,VOICE:$cleanPhone');
      }
    }

    if (email != null && email!.trim().isNotEmpty) {
      final cleanEmail = _unwrapSingleJsonValue(email!);
      if (cleanEmail.isNotEmpty) {
        lines.add('EMAIL;TYPE=WORK,INTERNET:$cleanEmail');
      }
    }

    if (website != null && website!.trim().isNotEmpty) {
      var url = _unwrapSingleJsonValue(website!);
      if (url.isNotEmpty) {
        if (!url.startsWith('http://') && !url.startsWith('https://')) {
          url = 'https://$url';
        }
        lines.add('URL:$url');
      }
    }

    if (address != null && address!.trim().isNotEmpty) {
      final cleanAddress = _unwrapSingleJsonValue(address!);
      if (cleanAddress.isNotEmpty) {
        lines.add('ADR;TYPE=WORK:;;${_escapeVCard(cleanAddress)};;;;');
      }
    }

    final cleanInline = inlinePhotoBase64?.replaceAll(RegExp(r'\s+'), '') ?? '';
    if (cleanInline.isNotEmpty) {
      final photoLine = 'PHOTO;ENCODING=b;TYPE=JPEG:$cleanInline';
      lines.add(foldLines ? VCardPhotoService.foldVCardLine(photoLine, lineBreak: eol) : photoLine);
    } else if (profileImageName != null) {
      final normalized = VCardPhotoService.normalizePhotoSource(profileImageName);
      if (normalized != null) {
        if (normalized.startsWith('data:') && normalized.contains(';base64,')) {
          final header = normalized.substring(5, normalized.indexOf(';base64,')).toUpperCase();
          final b64 = normalized
              .substring(normalized.indexOf(';base64,') + 8)
              .replaceAll(RegExp(r'\s+'), '');
          final subtype = header.contains('PNG')
              ? 'PNG'
              : (header.contains('WEBP') ? 'WEBP' : 'JPEG');
          if (b64.isNotEmpty) {
            final photoLine = 'PHOTO;ENCODING=b;TYPE=$subtype:$b64';
            lines.add(foldLines ? VCardPhotoService.foldVCardLine(photoLine, lineBreak: eol) : photoLine);
          }
        } else if (includePhotoUri &&
            (normalized.startsWith('http://') || normalized.startsWith('https://'))) {
          lines.add('PHOTO;VALUE=URI:$normalized');
        }
      }
    }

    lines.add('END:VCARD');
    return '${lines.join(eol)}$eol';
  }

  /// Resolves the profile photo asynchronously and embeds an inline Base64 JPEG
  /// directly inside the vCard (`PHOTO;ENCODING=b;TYPE=JPEG`), compacting when
  /// [forQrCode] is true so the QR stays comfortably scannable.
  Future<String> toVCardWithPhoto({
    bool forQrCode = false,
    int maxTotalQrBytes = 2200,
    http.Client? httpClient,
  }) async {
    String? inlinePhotoBase64;
    final photoSource = VCardPhotoService.normalizePhotoSource(profileImageName);
    if (photoSource != null) {
      if (forQrCode) {
        final baseNoPhoto = toVCard(includePhotoUri: false);
        const headerLen = 'PHOTO;ENCODING=b;TYPE=JPEG:\n'.length + 4;
        final remaining = maxTotalQrBytes - baseNoPhoto.length - headerLen;
        if (remaining >= 600) {
          inlinePhotoBase64 = await VCardPhotoService.getQrPhotoBase64(
            photoSource,
            maxBase64Chars: remaining.clamp(600, 1480),
            httpClient: httpClient,
          );
        }
      } else {
        inlinePhotoBase64 = await VCardPhotoService.getVcfPhotoBase64(
          photoSource,
          httpClient: httpClient,
        );
      }
    }
    return toVCard(
      inlinePhotoBase64: inlinePhotoBase64,
      foldLines: !forQrCode,
      useCrlf: !forQrCode,
    );
  }

  /// Plain text summary suitable for WhatsApp, SMS, or Telegram sharing.
  String toPlainText() {
    final parts = <String>[];
    parts.add('📇 $name');
    final title = designation.isNotEmpty ? designation : jobTitle;
    final comp = companyName.isNotEmpty ? companyName : company;
    if (title.isNotEmpty || comp.isNotEmpty) {
      parts.add([title, comp].where((e) => e.isNotEmpty).join(' @ '));
    }
    if (phone != null && phone!.isNotEmpty) parts.add('📞 Phone: $phone');
    if (email != null && email!.isNotEmpty) parts.add('✉️ Email: $email');
    if (website != null && website!.isNotEmpty) parts.add('🌐 Web: $website');
    if (address != null && address!.isNotEmpty) parts.add('📍 Address: $address');
    return parts.join('\n');
  }

  static String _escapeVCard(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,');
  }

  static String _unwrapSingleJsonValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '[]' || trimmed.toLowerCase() == 'null') {
      return '';
    }
    if (trimmed.startsWith('[')) {
      final firstMatch = RegExp(r'''^\[\s*["']([^"']+)["']''').firstMatch(trimmed);
      if (firstMatch != null) return firstMatch.group(1)!.trim();
    }
    return trimmed;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'designation': designation,
      'companyName': companyName,
      'profileImageInitial': profileImageInitial,
      'companyInitial': companyInitial,
      'phone': phone,
      'email': email,
      'address': address,
      'website': website,
      'profileImageName': profileImageName,
      'companyLogo': companyLogo,
      'backgroundImage': backgroundImage,
      'backgroundColor': backgroundColor,
      'textColor': textColor,
      'bgImageColor': bgImageColor,
      'opacity': opacity,
    };
  }

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      profileImageInitial: json['profileImageInitial']?.toString(),
      companyInitial: json['companyInitial']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      website: json['website']?.toString(),
      profileImageName: json['profileImageName']?.toString(),
      companyLogo: json['companyLogo']?.toString(),
      backgroundImage: json['backgroundImage']?.toString(),
      backgroundColor: json['backgroundColor']?.toString(),
      textColor: json['textColor']?.toString(),
      bgImageColor: json['bgImageColor']?.toString(),
      opacity: json['opacity'],
    );
  }
}

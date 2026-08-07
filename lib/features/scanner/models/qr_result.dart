import 'package:equatable/equatable.dart';

enum QrResultType {
  url,
  phone,
  email,
  vCard,
  wifi,
  text,
}

class QrResult extends Equatable {
  final QrResultType type;
  final String rawContent;
  final String displayTitle;
  final Map<String, String> parsedFields;
  final DateTime scannedAt;

  const QrResult({
    required this.type,
    required this.rawContent,
    required this.displayTitle,
    required this.parsedFields,
    required this.scannedAt,
  });

  factory QrResult.fromRawString(String raw) {
    final trimmed = raw.trim();
    final lower = trimmed.toLowerCase();

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return QrResult(
        type: QrResultType.url,
        rawContent: trimmed,
        displayTitle: 'Website Link',
        parsedFields: {'url': trimmed},
        scannedAt: DateTime.now(),
      );
    } else if (lower.startsWith('tel:')) {
      final phone = trimmed.substring(4);
      return QrResult(
        type: QrResultType.phone,
        rawContent: trimmed,
        displayTitle: 'Phone Number',
        parsedFields: {'phone': phone},
        scannedAt: DateTime.now(),
      );
    } else if (lower.startsWith('mailto:')) {
      final email = trimmed.substring(7);
      return QrResult(
        type: QrResultType.email,
        rawContent: trimmed,
        displayTitle: 'Email Address',
        parsedFields: {'email': email},
        scannedAt: DateTime.now(),
      );
    } else if (lower.startsWith('begin:vcard')) {
      final fields = _parseVCard(trimmed);
      return QrResult(
        type: QrResultType.vCard,
        rawContent: trimmed,
        displayTitle: fields['name'] ?? 'Digital Contact',
        parsedFields: fields,
        scannedAt: DateTime.now(),
      );
    } else if (lower.startsWith('wifi:')) {
      return QrResult(
        type: QrResultType.wifi,
        rawContent: trimmed,
        displayTitle: 'Wi-Fi Network',
        parsedFields: {'wifi': trimmed},
        scannedAt: DateTime.now(),
      );
    } else {
      return QrResult(
        type: QrResultType.text,
        rawContent: trimmed,
        displayTitle: 'Text Data',
        parsedFields: {'text': trimmed},
        scannedAt: DateTime.now(),
      );
    }
  }

  static Map<String, String> _parseVCard(String vcard) {
    final Map<String, String> map = {};
    final lines = vcard.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts[0].toUpperCase();
      final val = parts.sublist(1).join(':').trim();

      if (key.startsWith('FN') || key.startsWith('N')) {
        map['name'] = val.replaceAll(';', ' ').trim();
      } else if (key.startsWith('TEL')) {
        map['phone'] = val;
      } else if (key.startsWith('EMAIL')) {
        map['email'] = val;
      } else if (key.startsWith('ORG')) {
        map['company'] = val;
      } else if (key.startsWith('TITLE')) {
        map['designation'] = val;
      } else if (key.startsWith('URL')) {
        map['website'] = val;
      } else if (key.startsWith('ADR')) {
        map['address'] = val.replaceAll(';', ' ').trim();
      }
    }
    return map;
  }

  @override
  List<Object?> get props => [type, rawContent, displayTitle, parsedFields, scannedAt];
}

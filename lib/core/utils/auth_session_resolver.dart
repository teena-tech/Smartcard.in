import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthSessionResolver {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<String?> resolveUserId({String? fallbackUserId}) async {
    final fallback = _normalizeUserId(fallbackUserId);
    if (fallback != null) return fallback;

    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.trim().isEmpty) return null;

    final payload = _decodeJwtPayload(token.trim());
    if (payload == null) return null;

    final candidates = [
      payload['id'],
      payload['user_id'],
      payload['userId'],
      payload['sub'],
    ];

    for (final candidate in candidates) {
      final resolved = _normalizeUserId(candidate);
      if (resolved != null) return resolved;
    }

    final nestedUser = payload['user'];
    if (nestedUser is Map) {
      for (final key in ['id', 'user_id', 'userId']) {
        final resolved = _normalizeUserId(nestedUser[key]);
        if (resolved != null) return resolved;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
    } catch (_) {
      return null;
    }

    return null;
  }

  static String? _normalizeUserId(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = int.tryParse(text);
    if (parsed != null && parsed > 0) {
      return parsed.toString();
    }

    return text;
  }
}

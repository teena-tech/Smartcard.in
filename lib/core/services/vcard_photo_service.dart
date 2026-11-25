import 'dart:convert';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';
import 'package:smartcard_flutter/core/services/api_config.dart';

/// Downloads, normalizes, and caches profile photos for vCard 3.0 QR codes
/// and downloadable/shareable `.vcf` files so Android Google Contacts and
/// iOS Contacts reliably display the contact picture.
class VCardPhotoService {
  const VCardPhotoService._();

  static final Map<String, Uint8List> _rawBytesCache = {};
  static final Map<String, String> _encodedCache = {};

  static bool _isLocalDevicePath(String value) {
    if (value.startsWith('file://')) return true;
    const localPrefixes = <String>[
      '/data/',
      '/storage/emulated/',
      '/sdcard/',
      '/mnt/',
      '/Users/',
      '/tmp/',
      '/var/',
      '/private/',
    ];
    return localPrefixes.any(value.startsWith);
  }

  /// Clears in-memory cached photo bytes and encoded Base64 payloads (for tests).
  static void clearCache() {
    _rawBytesCache.clear();
    _encodedCache.clear();
  }

  /// Resolves a raw photo reference (URL, data URI, relative upload path, or file path)
  /// to normalized absolute URL / source string, or null if blank/invalid/SVG.
  static String? normalizePhotoSource(String? rawSource) {
    if (rawSource == null) return null;
    final trimmed = rawSource.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    if (lower == 'null' || lower == 'undefined' || lower.endsWith('.svg')) {
      return null;
    }
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }
    if (_isLocalDevicePath(trimmed)) {
      return trimmed;
    }

    final cleaned = trimmed.replaceFirst(RegExp(r'^/+'), '');
    if (trimmed.startsWith('/') &&
        !cleaned.toLowerCase().startsWith('shared-uploads/') &&
        !cleaned.toLowerCase().startsWith('users/')) {
      try {
        final base = ApiConfig.baseUrl.replaceFirst(RegExp(r'/+$'), '');
        return '$base/$cleaned';
      } catch (_) {
        return 'https://thesmartcards.in/$cleaned';
      }
    }

    try {
      return UploadUrlResolver.resolve(cleaned, type: 'profile');
    } catch (_) {
      return 'https://thesmartcards.in/$cleaned';
    }
  }

  /// Resolves raw image bytes from a normalized source string.
  static Future<Uint8List?> fetchPhotoBytes(
    String? rawSource, {
    http.Client? httpClient,
  }) async {
    final source = normalizePhotoSource(rawSource);
    if (source == null) return null;

    if (httpClient == null && _rawBytesCache.containsKey(source)) {
      return _rawBytesCache[source];
    }

    try {
      Uint8List? bytes;
      if (source.startsWith('data:')) {
        final comma = source.indexOf(',');
        if (comma != -1) {
          bytes = base64Decode(source.substring(comma + 1).replaceAll(RegExp(r'\s+'), ''));
        }
      } else if (source.startsWith('http://') || source.startsWith('https://')) {
        final uri = Uri.tryParse(source);
        if (uri != null) {
          final res = await (httpClient != null ? httpClient.get(uri) : http.get(uri))
              .timeout(const Duration(seconds: 8));
          final ct = (res.headers['content-type'] ?? '').toLowerCase();
          if (res.statusCode == 200 && res.bodyBytes.isNotEmpty && !ct.contains('svg')) {
            bytes = res.bodyBytes;
          }
        }
      } else if (!kIsWeb) {
        final file = File(source.replaceFirst('file://', ''));
        if (await file.exists()) {
          final read = await file.readAsBytes();
          if (read.isNotEmpty) bytes = read;
        }
      }

      if (bytes != null && bytes.isNotEmpty && httpClient == null) {
        _rawBytesCache[source] = bytes;
      }
      return (bytes != null && bytes.isNotEmpty) ? bytes : null;
    } catch (e) {
      debugPrint('⚠️ [VCardPhotoService] Failed to fetch photo bytes: $e');
      return null;
    }
  }

  /// Encodes high-quality JPEG Base64 suitable for `.vcf` file attachments
  /// (`maxDim = 256px`), automatically stepping down quality/size so the
  /// underlying JPEG stays strictly under 50 KB (`<= 48 KB`).
  static String? encodeJpegForVcf(
    Uint8List rawBytes, {
    int maxJpegBytes = 48 * 1024,
  }) {
    if (rawBytes.isEmpty) return null;
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        const presets = <({int maxDim, int quality})>[
          (maxDim: 256, quality: 82),
          (maxDim: 256, quality: 68),
          (maxDim: 256, quality: 52),
          (maxDim: 192, quality: 60),
          (maxDim: 160, quality: 50),
        ];
        Uint8List? best;
        for (final preset in presets) {
          final resized =
              (decoded.width > preset.maxDim || decoded.height > preset.maxDim)
                  ? img.copyResize(
                      decoded,
                      width: decoded.width >= decoded.height
                          ? preset.maxDim
                          : null,
                      height: decoded.height > decoded.width
                          ? preset.maxDim
                          : null,
                      interpolation: img.Interpolation.average,
                    )
                  : decoded;
          final encoded = img.encodeJpg(resized, quality: preset.quality);
          best = encoded;
          if (encoded.length <= maxJpegBytes) {
            return base64Encode(encoded);
          }
        }
        if (best != null && best.length <= maxJpegBytes) {
          return base64Encode(best);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VCardPhotoService] encodeJpegForVcf fallback: $e');
    }
    if (rawBytes.length >= 2 &&
        rawBytes[0] == 0xFF &&
        rawBytes[1] == 0xD8 &&
        rawBytes.length <= maxJpegBytes) {
      return base64Encode(rawBytes);
    }
    return null;
  }

  /// Encodes a compact low-resolution JPEG Base64 string (`<= 96x96`) that fits
  /// comfortably inside a scannable QR code within [maxBase64Chars].
  static String? encodeCompactJpegForQr(
    Uint8List rawBytes, {
    int maxBase64Chars = 1480,
  }) {
    if (rawBytes.isEmpty || maxBase64Chars < 600) return null;
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return null;

      const presets = <({int dim, int quality})>[
        (dim: 96, quality: 45),
        (dim: 80, quality: 38),
        (dim: 72, quality: 32),
        (dim: 64, quality: 25),
        (dim: 56, quality: 20),
        (dim: 48, quality: 16),
        (dim: 40, quality: 12),
        (dim: 36, quality: 10),
      ];

      for (final preset in presets) {
        final targetW = decoded.width >= decoded.height ? preset.dim : null;
        final targetH = decoded.height > decoded.width ? preset.dim : null;
        final resized = (decoded.width > preset.dim || decoded.height > preset.dim)
            ? img.copyResize(
                decoded,
                width: targetW,
                height: targetH,
                interpolation: img.Interpolation.average,
              )
            : decoded;
        final jpg = img.encodeJpg(resized, quality: preset.quality);
        final b64 = base64Encode(jpg);
        if (b64.length <= maxBase64Chars) {
          return b64;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [VCardPhotoService] encodeCompactJpegForQr error: $e');
    }
    return null;
  }

  /// Resolves and caches a crisp JPEG Base64 string for `.vcf` sharing.
  static Future<String?> getVcfPhotoBase64(
    String? rawSource, {
    http.Client? httpClient,
  }) async {
    final source = normalizePhotoSource(rawSource);
    if (source == null) return null;
    final key = 'vcf::$source';
    if (httpClient == null && _encodedCache.containsKey(key)) {
      return _encodedCache[key];
    }

    final raw = await fetchPhotoBytes(source, httpClient: httpClient);
    if (raw == null) return null;

    final b64 = encodeJpegForVcf(raw);
    if (b64 != null && b64.isNotEmpty && httpClient == null) {
      _encodedCache[key] = b64;
    }
    return b64;
  }

  /// Resolves and caches a compact JPEG Base64 string for inline vCard QR codes.
  static Future<String?> getQrPhotoBase64(
    String? rawSource, {
    int maxBase64Chars = 1480,
    http.Client? httpClient,
  }) async {
    final source = normalizePhotoSource(rawSource);
    if (source == null || maxBase64Chars < 600) return null;
    final key = 'qr_$maxBase64Chars::$source';
    if (httpClient == null && _encodedCache.containsKey(key)) {
      return _encodedCache[key];
    }

    final raw = await fetchPhotoBytes(source, httpClient: httpClient);
    if (raw == null) return null;

    final b64 = encodeCompactJpegForQr(raw, maxBase64Chars: maxBase64Chars);
    if (b64 != null && b64.isNotEmpty && httpClient == null) {
      _encodedCache[key] = b64;
    }
    return b64;
  }

  /// Folds a long vCard property line per RFC 2426 (75 chars + CRLF + single space).
  static String foldVCardLine(String line, {String lineBreak = '\r\n'}) {
    if (line.length <= 75) return line;
    final buffer = StringBuffer();
    var start = 0;
    while (start < line.length) {
      final chunkLimit = start == 0 ? 75 : 74;
      final end = (start + chunkLimit < line.length) ? start + chunkLimit : line.length;
      if (start > 0) {
        buffer.write(lineBreak);
        buffer.write(' ');
      }
      buffer.write(line.substring(start, end));
      start = end;
    }
    return buffer.toString();
  }
}


import 'dart:math';

import 'package:smartcard_flutter/core/utils/upload_url_resolver.dart';

String _toText(dynamic value) => (value?.toString() ?? '').trim();

String? firstNonEmptyString(Iterable<dynamic> values) {
  for (final value in values) {
    final text = _toText(value);
    if (text.isNotEmpty) return text;
  }
  return null;
}

String normalizeHex(dynamic value, String fallback) {
  final normalized = _toText(value);
  return RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(normalized) ? normalized : fallback;
}

double normalizeOpacity(dynamic value, {double fallback = 0.5}) {
  final parsed = double.tryParse(_toText(value));
  if (parsed == null || !parsed.isFinite) return fallback;
  return min(1, max(0, parsed));
}

bool isWhiteLikeColor(String? value) {
  final clean = normalizeHex(value, '').replaceAll('#', '');
  if (clean.length != 6) return false;
  final red = int.tryParse(clean.substring(0, 2), radix: 16) ?? 0;
  final green = int.tryParse(clean.substring(2, 4), radix: 16) ?? 0;
  final blue = int.tryParse(clean.substring(4, 6), radix: 16) ?? 0;
  return red >= 245 && green >= 245 && blue >= 245;
}

bool isBlackLikeColor(String? value) {
  final clean = normalizeHex(value, '').replaceAll('#', '');
  if (clean.length != 6) return false;
  final red = int.tryParse(clean.substring(0, 2), radix: 16) ?? 0;
  final green = int.tryParse(clean.substring(2, 4), radix: 16) ?? 0;
  final blue = int.tryParse(clean.substring(4, 6), radix: 16) ?? 0;
  return red <= 16 && green <= 16 && blue <= 16;
}

bool isIgnoredPaletteColor(String? value) => isWhiteLikeColor(value) || isBlackLikeColor(value);

String toRgba(String? hex, double alpha) {
  final cleanHex = normalizeHex(hex, '#000000').replaceAll('#', '');
  final red = int.tryParse(cleanHex.substring(0, 2), radix: 16) ?? 0;
  final green = int.tryParse(cleanHex.substring(2, 4), radix: 16) ?? 0;
  final blue = int.tryParse(cleanHex.substring(4, 6), radix: 16) ?? 0;
  final opacity = alpha.isFinite ? alpha.clamp(0.0, 1.0) : 0.5;
  return 'rgba($red, $green, $blue, $opacity)';
}

String getReadableTextColor(String hex) {
  final normalized = normalizeHex(hex, '#FFFFFF').replaceAll('#', '');
  final red = int.tryParse(normalized.substring(0, 2), radix: 16) ?? 0;
  final green = int.tryParse(normalized.substring(2, 4), radix: 16) ?? 0;
  final blue = int.tryParse(normalized.substring(4, 6), radix: 16) ?? 0;
  final brightness = (red * 299 + green * 587 + blue * 114) / 1000;
  return brightness > 160 ? '#111827' : '#FFFFFF';
}

List<String> buildPalette(Iterable<dynamic> items, [List<String> fallbackPalette = const []]) {
  final palette = <String>[];
  final seen = <String>{};

  void addColor(dynamic value) {
    if (palette.length >= 5) return;
    final normalized = normalizeHex(value, '');
    if (normalized.isEmpty || isIgnoredPaletteColor(normalized)) return;
    final upper = normalized.toUpperCase();
    if (seen.contains(upper)) return;
    seen.add(upper);
    palette.add(upper);
  }

  for (final entry in items) {
    final colorCandidate = entry is String
        ? entry
        : (entry is Map
            ? (entry['hex'] ?? entry['color'] ?? entry['value'] ?? entry['bgimage'] ?? '')
            : entry);
    addColor(colorCandidate);
  }

  for (final color in fallbackPalette) {
    addColor(color);
  }

  return palette.take(5).toList();
}

String resolveBackgroundImageUrl(dynamic item) {
  if (item is Map) {
    final candidate = firstNonEmptyString([
      item['url'],
      item['image_url'],
      item['imageUrl'],
      item['path'],
      item['file_url'],
      item['fileUrl'],
    ]);
    if (candidate != null) {
      return UploadUrlResolver.resolve(candidate, type: 'card-bg', fallback: '');
    }
  }
  return UploadUrlResolver.resolve(_toText(item), type: 'card-bg', fallback: '');
}

String resolveBackgroundImageKey(dynamic item) {
  if (item is Map) {
    final candidate = firstNonEmptyString([
      item['bgimage'],
      item['bg_image'],
      item['filename'],
      item['file_name'],
      item['name'],
      item['id'],
      item['path'],
    ]);
    if (candidate != null) return candidate;
  }
  return _toText(item);
}

String resolveTemplateThumb(dynamic item) {
  if (item is Map) {
    final candidate = firstNonEmptyString([
      item['thumbnail_url'],
      item['thumbnail'],
      item['thumb'],
      item['image_url'],
      item['imageUrl'],
    ]);
    if (candidate != null) {
      return UploadUrlResolver.resolve(candidate, type: 'template', fallback: '');
    }
  }
  return '';
}

String resolveTemplateKey(dynamic item) {
  if (item is Map) {
    final candidate = firstNonEmptyString([
      item['file_name'],
      item['template_key'],
      item['templateKey'],
      item['name'],
      item['id'],
    ]);
    if (candidate != null) return candidate;
  }
  return _toText(item);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Safely decodes a base64 string (including data:image URIs) with automatic padding normalization.
/// Returns null if the input is null, empty, or invalid base64 data instead of throwing a FormatException.
final Map<String, Uint8List> _base64MemoryCache = {};
const int _maxCacheEntries = 200;

/// Safely decodes a base64 string (including data:image URIs) with automatic padding normalization.
/// Returns null if the input is null, empty, or invalid base64 data instead of throwing a FormatException.
Uint8List? safeBase64Decode(String? input) {
  if (input == null || input.trim().isEmpty) return null;

  final String rawInput = input.trim();
  final cached = _base64MemoryCache[rawInput];
  if (cached != null) return cached;

  try {
    String cleanInput = rawInput;
    if (cleanInput.contains(',')) {
      cleanInput = cleanInput.split(',').last.trim();
    }
    // Remove all whitespace/newlines
    cleanInput = cleanInput.replaceAll(RegExp(r'\s+'), '');

    if (cleanInput.isEmpty) return null;

    // Handle single-character remainder (invalid in Base64)
    if (cleanInput.length % 4 == 1) {
      cleanInput = cleanInput.substring(0, cleanInput.length - 1);
    }

    if (cleanInput.isEmpty) return null;

    // Try standard padded decoding first
    final remainder = cleanInput.length % 4;
    String paddedInput = cleanInput;
    if (remainder > 0) {
      paddedInput = paddedInput.padRight(paddedInput.length + (4 - remainder), '=');
    }

    Uint8List? decoded;
    try {
      decoded = base64Decode(paddedInput);
    } catch (_) {
      // If padded decoding failed due to invalid trailing bits (e.g. truncated base64 string from backend),
      // slice back to the last complete 4-character quantum and decode.
      final validLen = cleanInput.length - (cleanInput.length % 4);
      if (validLen > 0) {
        final truncatedClean = cleanInput.substring(0, validLen);
        try {
          decoded = base64Decode(truncatedClean);
        } catch (_) {
          decoded = null;
        }
      }
    }

    if (decoded != null) {
      if (_base64MemoryCache.length >= _maxCacheEntries) {
        _base64MemoryCache.remove(_base64MemoryCache.keys.first);
      }
      _base64MemoryCache[rawInput] = decoded;
      return decoded;
    }
  } catch (e) {
    debugPrint('⚠️ safeBase64Decode caught invalid base64 data: $e');
  }
  return null;
}

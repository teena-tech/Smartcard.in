import 'dart:typed_data';

import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import '../utils/phone_normalizer.dart';

/// Resolves the best available device-contact photo without using list thumbnails
/// as the source for full-screen viewing.
class ContactPhotoService {
  const ContactPhotoService._();

  static final Map<String, Uint8List?> _photoCache = {};

  static void clearCache() {
    _photoCache.clear();
  }

  static String? _idKey(String? contactId) =>
      (contactId != null && contactId.trim().isNotEmpty)
          ? 'id_${contactId.trim()}'
          : null;

  static String? _phoneKey(String? phone) {
    if (phone == null) return null;
    final tail = PhoneNormalizer.last10(phone);
    if (tail.isEmpty) return null;
    return 'phone_$tail';
  }

  /// Synchronously retrieve cached photo bytes if available in memory
  static Uint8List? getCachedPhoto({
    String? contactId,
    String? phone,
  }) {
    final idK = _idKey(contactId);
    if (idK != null && _photoCache.containsKey(idK) && _photoCache[idK] != null) {
      return _photoCache[idK];
    }
    final phoneK = _phoneKey(phone);
    if (phoneK != null && _photoCache.containsKey(phoneK)) {
      return _photoCache[phoneK];
    }
    return null;
  }

  /// Store photo bytes directly in the in-memory cache under both ID and phone keys
  static void cachePhoto({
    String? contactId,
    String? phone,
    required Uint8List? photoBytes,
  }) {
    final idK = _idKey(contactId);
    final phoneK = _phoneKey(phone);
    if (idK != null) {
      _photoCache[idK] = photoBytes;
    }
    if (phoneK != null) {
      _photoCache[phoneK] = photoBytes;
    }
  }

  static Future<Uint8List?> getBestPhoto({
    String? contactId,
    String? phone,
  }) async {
    final cached = getCachedPhoto(contactId: contactId, phone: phone);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    bool permitted = false;
    try {
      final status = await Permission.contacts.status;
      permitted = status.isGranted || status.isLimited;
      if (!permitted) {
        permitted = await fc.FlutterContacts.permissions.has(fc.PermissionType.readWrite) ||
            await fc.FlutterContacts.permissions.has(fc.PermissionType.read);
      }
    } catch (_) {}

    if (!permitted) {
      return null;
    }

    fc.Contact? contact;
    final id = contactId?.replaceFirst('phone_', '').replaceFirst('matched_', '');
    if (id != null && id.isNotEmpty && RegExp(r'^\d+$').hasMatch(id)) {
      contact = await fc.FlutterContacts.get(
        id,
        properties: fc.ContactProperties.all,
      );
    }

    if (contact == null && phone != null && phone.trim().isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final suffix = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      if (suffix.length >= 7) {
        final candidates = await fc.FlutterContacts.getAll(
          properties: {
            fc.ContactProperty.phone,
          },
        );
        for (final candidate in candidates) {
          final matches = candidate.phones.any((candidatePhone) {
            final candidateDigits = candidatePhone.number.replaceAll(RegExp(r'\D'), '');
            final candidateSuffix = candidateDigits.length >= 10
                ? candidateDigits.substring(candidateDigits.length - 10)
                : candidateDigits;
            return candidateSuffix == suffix ||
                candidateDigits.endsWith(suffix) ||
                digits.endsWith(candidateSuffix);
          });
          if (matches && candidate.id != null) {
            contact = await fc.FlutterContacts.get(
              candidate.id!,
              properties: fc.ContactProperties.all,
            );
            break;
          }
        }
      }
    }

    final photo = contact?.photo;
    final Uint8List? result = (photo?.fullSize != null && photo!.fullSize!.isNotEmpty)
        ? photo.fullSize
        : ((photo?.thumbnail != null && photo!.thumbnail!.isNotEmpty) ? photo.thumbnail : null);

    if (result != null && result.isNotEmpty) {
      cachePhoto(contactId: contactId, phone: phone, photoBytes: result);
    }
    return result;
  }
}
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../../models/card_model.dart';
import 'contact_photo_service.dart';
import '../utils/upload_url_resolver.dart';
import '../utils/safe_base64.dart';

/// Single Profile Image Source of Truth & Fallback Resolution Strategy
/// Strategy Order:
/// 1. Original local device contact photo bytes / full-size image (ContactPhotoService / AppContact.photo)
/// 2. Original synced local photo URI / image path (scannedContact.imagePath, profileImage)
/// 3. Existing SmartCard profile photo reference (profileImageName)
/// 4. Fallback letter initial
class ResolvedContactPhoto {
  final Uint8List? bytes;
  final String? urlOrPath;
  final String initial;

  const ResolvedContactPhoto({
    this.bytes,
    this.urlOrPath,
    required this.initial,
  });

  bool get hasImage => (bytes != null && bytes!.isNotEmpty) || (urlOrPath != null && urlOrPath!.isNotEmpty);
}

class ContactPhotoResolver {
  ContactPhotoResolver._();

  static String? firstValidSource(Iterable<String?> candidates) {
    for (final raw in candidates) {
      if (raw == null) continue;
      final trimmed = raw.trim();
      final lower = trimmed.toLowerCase();
      if (trimmed.isEmpty ||
          lower == 'null' ||
          lower == 'undefined' ||
          lower == 'none') {
        continue;
      }
      return trimmed;
    }
    return null;
  }

  /// Extracts the best available profile/card image reference from a [ScannedContactModel].
  static String? resolveScannedPhotoSource(ScannedContactModel? contact) {
    if (contact == null) return null;
    final direct = firstValidSource([
      contact.matchedProfileImage,
      contact.profileImage,
    ]);
    if (direct != null) return direct;

    if (contact.matchedCards != null) {
      for (final card in contact.matchedCards!) {
        final fromCard = firstValidSource([
          card['profileImageName']?.toString(),
          card['profile_image_name']?.toString(),
          card['profileImage']?.toString(),
          card['profile_image']?.toString(),
          card['user_image']?.toString(),
          card['userImage']?.toString(),
          card['user_photo']?.toString(),
          card['userPhoto']?.toString(),
          card['avatar']?.toString(),
        ]);
        if (fromCard != null) return fromCard;
      }
    }
    return firstValidSource([contact.imagePath]);
  }

  /// Resolve photo synchronously from available fields
  static ResolvedContactPhoto resolveSync({
    AppContact? appContact,
    ScannedContactModel? scannedContact,
    CardModel? cardModel,
    Map<String, dynamic>? rawMap,
    String? name,
    Uint8List? rawBytes,
    String? rawPathOrUrl,
  }) {
    final String displayName = name ??
        appContact?.displayName ??
        scannedContact?.name ??
        cardModel?.name ??
        rawMap?['name']?.toString() ??
        '';

    final String initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    // 1. Memory bytes (highest resolution original photo)
    if (rawBytes != null && rawBytes.isNotEmpty) {
      return ResolvedContactPhoto(bytes: rawBytes, initial: initial);
    }
    if (appContact?.photo != null && appContact!.photo!.isNotEmpty) {
      return ResolvedContactPhoto(bytes: appContact.photo, initial: initial);
    }

    // 2. Local File / Data URI / Direct Network URL
    String? candidate = firstValidSource([
      rawPathOrUrl,
      resolveScannedPhotoSource(scannedContact),
      cardModel?.profileImageName,
    ]);

    if (rawMap != null) {
      final fromMap = firstValidSource([
        rawMap['profileImageName']?.toString(),
        rawMap['profile_image_name']?.toString(),
        rawMap['profileImage']?.toString(),
        rawMap['profile_image']?.toString(),
        rawMap['user_image']?.toString(),
        rawMap['userImage']?.toString(),
        rawMap['image_path']?.toString(),
        rawMap['imagePath']?.toString(),
      ]);
      if (fromMap != null) {
        candidate = fromMap;
      }
    }

    if (candidate != null && candidate.isNotEmpty && candidate.toLowerCase() != 'null') {
      if (candidate.startsWith('data:image') || candidate.startsWith('data:')) {
        try {
          final decoded = safeBase64Decode(candidate);
          if (decoded != null && decoded.isNotEmpty) {
            return ResolvedContactPhoto(bytes: decoded, initial: initial);
          }
        } catch (_) {}
      }

      if (!kIsWeb && (candidate.startsWith('/') || candidate.startsWith('file://'))) {
        final cleanPath = candidate.replaceFirst('file://', '');
        if (File(cleanPath).existsSync()) {
          return ResolvedContactPhoto(urlOrPath: cleanPath, initial: initial);
        }
      }

      if (candidate.startsWith('http://') || candidate.startsWith('https://')) {
        return ResolvedContactPhoto(urlOrPath: candidate, initial: initial);
      }

      final resolvedUrl = UploadUrlResolver.resolve(candidate, type: 'profile');
      if (resolvedUrl.isNotEmpty) {
        return ResolvedContactPhoto(urlOrPath: resolvedUrl, initial: initial);
      }
    }

    return ResolvedContactPhoto(initial: initial);
  }

  /// Resolve photo asynchronously (fetches full-size native device photo if available)
  static Future<ResolvedContactPhoto> resolveAsync({
    AppContact? appContact,
    ScannedContactModel? scannedContact,
    CardModel? cardModel,
    Map<String, dynamic>? rawMap,
    String? name,
    String? contactId,
    String? phone,
  }) async {
    final syncRes = resolveSync(
      appContact: appContact,
      scannedContact: scannedContact,
      cardModel: cardModel,
      rawMap: rawMap,
      name: name,
    );

    if (syncRes.bytes != null && syncRes.bytes!.isNotEmpty) {
      return syncRes;
    }

    // Attempt fetching highest quality device photo via FlutterContacts
    final String? id = contactId ?? appContact?.id ?? scannedContact?.id;
    final String? phoneNumber = phone ?? appContact?.primaryPhone ?? scannedContact?.phone;

    try {
      final bestPhoto = await ContactPhotoService.getBestPhoto(
        contactId: id,
        phone: phoneNumber,
      );
      if (bestPhoto != null && bestPhoto.isNotEmpty) {
        return ResolvedContactPhoto(bytes: bestPhoto, initial: syncRes.initial);
      }
    } catch (_) {}

    return syncRes;
  }
}

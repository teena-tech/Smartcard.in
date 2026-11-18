import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../../models/app_contact.dart';
import '../../models/scanned_contact_model.dart';
import '../database/sqlite_database.dart';
import 'contact_photo_resolver.dart';
import 'contact_photo_service.dart';

class ContactSaverService {
  static const MethodChannel _nativeContactsChannel =
      MethodChannel('com.smartcard/native_contacts_helper');

  static bool get _isDesktopOrWeb =>
      kIsWeb || (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux));

  /// Encodes a compact 96x96 JPEG thumbnail for `ContactsContract.CommonDataKinds.Photo`
  /// alongside the full-resolution `DisplayPhoto`.
  static Uint8List _encodeThumbnailJpeg(Uint8List jpegBytes) {
    try {
      final decoded = img.decodeImage(jpegBytes);
      if (decoded != null) {
        final thumb = (decoded.width > 96 || decoded.height > 96)
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? 96 : null,
                height: decoded.height > decoded.width ? 96 : null,
                interpolation: img.Interpolation.average,
              )
            : decoded;
        return Uint8List.fromList(img.encodeJpg(thumb, quality: 78));
      }
    } catch (_) {}
    return jpegBytes;
  }

  /// Resolves the device's default contacts account, falling back to the primary
  /// `com.google` account on Android when no OS default is explicitly configured.
  static Future<fc.Account?> resolvePreferredWritableAccount() async {
    if (_isDesktopOrWeb) return null;
    try {
      final defaultAccount = await fc.FlutterContacts.accounts.getDefault();
      if (defaultAccount != null) return defaultAccount;
      if (Platform.isAndroid) {
        final accounts = await fc.FlutterContacts.accounts.getAll();
        for (final acc in accounts) {
          if (acc.type == 'com.google' && acc.name.trim().isNotEmpty) {
            return acc;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ContactSaverService] Account lookup fallback: $e');
    }
    return null;
  }

  /// Ensures Android writable/Google (`com.google`) raw contacts receive both
  /// `DisplayPhoto` and `Data` thumbnail `Photo` rows marked dirty for sync.
  static Future<void> syncNativePhotoToGoogleRawContacts(
    String contactId,
    Uint8List? photoBytes,
  ) async {
    if (kIsWeb ||
        !Platform.isAndroid ||
        contactId.trim().isEmpty ||
        photoBytes == null ||
        photoBytes.isEmpty) {
      return;
    }
    try {
      final normalized = normalizePhotoBytesForDevice(photoBytes);
      final thumb = _encodeThumbnailJpeg(normalized);
      await _nativeContactsChannel.invokeMethod<bool>('writeContactPhoto', {
        'contactId': contactId.trim(),
        'photoBytes': normalized,
        'thumbnailBytes': thumb,
      });
    } catch (e) {
      debugPrint('⚠️ [ContactSaverService] Native photo sync channel warning: $e');
    }
  }

  /// Transcodes WebP/PNG/oversized images to universal baseline JPEG bytes so
  /// Android OEM Contacts providers (Vivo, Samsung, Xiaomi, Google) and iOS
  /// reliably persist and render DisplayPhoto thumbnails.
  static Uint8List normalizePhotoBytesForDevice(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return rawBytes;
    final isCompactJpeg = rawBytes.length >= 4 &&
        rawBytes[0] == 0xFF &&
        rawBytes[1] == 0xD8 &&
        rawBytes.length <= 450 * 1024;
    if (isCompactJpeg) return rawBytes;

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final resized = (decoded.width > 512 || decoded.height > 512)
            ? img.copyResize(
                decoded,
                width: decoded.width >= decoded.height ? 512 : null,
                height: decoded.height > decoded.width ? 512 : null,
                interpolation: img.Interpolation.average,
              )
            : decoded;
        return Uint8List.fromList(img.encodeJpg(resized, quality: 88));
      }
    } catch (e) {
      debugPrint('⚠️ [ContactSaverService] Image JPEG transcode fallback: $e');
    }
    return rawBytes;
  }

  /// Downloads or reads profile photo bytes (URL, local file, or Base64)
  /// so saved device address book contacts include the scanned profile image.
  static Future<Uint8List?> resolvePhotoBytes(
    ScannedContactModel scanned, {
    http.Client? httpClient,
  }) async {
    try {
      final resolved = ContactPhotoResolver.resolveSync(scannedContact: scanned);
      if (resolved.bytes != null && resolved.bytes!.isNotEmpty) {
        return normalizePhotoBytesForDevice(resolved.bytes!);
      }

      final target = resolved.urlOrPath?.trim();
      if (target == null || target.isEmpty) return null;
      if (target.toLowerCase().endsWith('.svg')) return null;

      if (target.startsWith('http://') || target.startsWith('https://')) {
        final uri = Uri.tryParse(target);
        if (uri == null) return null;
        final response = await (httpClient != null
                ? httpClient.get(uri)
                : http.get(uri))
            .timeout(const Duration(seconds: 6));
        final contentType = (response.headers['content-type'] ?? '').toLowerCase();
        if (response.statusCode == 200 &&
            response.bodyBytes.isNotEmpty &&
            !contentType.contains('svg')) {
          return normalizePhotoBytesForDevice(response.bodyBytes);
        }
        return null;
      }

      if (!kIsWeb) {
        final cleanPath = target.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty) return normalizePhotoBytesForDevice(bytes);
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ContactSaverService] Could not resolve profile photo bytes: $e');
    }
    return null;
  }

  /// Checks and automatically requests system contacts write permission.
  static Future<bool> requestContactsPermission() async {
    if (_isDesktopOrWeb) return true;
    try {
      final status = await Permission.contacts.request();
      if (status.isGranted || status.isLimited) return true;
      return await fc.FlutterContacts.permissions.has(fc.PermissionType.readWrite);
    } catch (e) {
      debugPrint('Error requesting contacts permission: $e');
      return false;
    }
  }

  /// Checks contacts permission status WITHOUT requesting — use for background saves.
  static Future<bool> checkContactsPermission() async {
    if (_isDesktopOrWeb) return true;
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited) return true;
      return await fc.FlutterContacts.permissions.has(fc.PermissionType.readWrite);
    } catch (e) {
      debugPrint('Error checking contacts permission: $e');
      return false;
    }
  }

  static Future<String?> _updateNativeContact({
    required String contactId,
    required AppContact appContact,
    required ScannedContactModel scanned,
    required Uint8List? photoBytes,
  }) async {
    final realExisting = await fc.FlutterContacts.get(
      contactId,
      properties: fc.ContactProperties.all,
    );
    if (realExisting == null) return null;

    final updated = appContact.toDeviceContact(existing: realExisting);
    await fc.FlutterContacts.update(updated);
    final resolvedId = realExisting.id ?? contactId;
    if (photoBytes != null && photoBytes.isNotEmpty) {
      await syncNativePhotoToGoogleRawContacts(resolvedId, photoBytes);
      ContactPhotoService.cachePhoto(
        contactId: resolvedId,
        phone: scanned.phone,
        photoBytes: photoBytes,
      );
    }
    return resolvedId;
  }

  /// Saves a [ScannedContactModel] directly into the device’s native address book.
  /// Rule: 1 Profile → 1 Device Contact → Multiple Phone Numbers.
  /// Multiple companies using the same phone number are saved as SEPARATE device contacts.
  /// Returns the device contact ID if saved/updated, or null if failed.
  static Future<String?> saveToDevice(
    ScannedContactModel scanned, {
    bool requestPermission = false,
  }) async {
    if (_isDesktopOrWeb) {
      await SqliteDatabase.saveContact(scanned);
      return scanned.deviceContactId ?? 'device_${scanned.id}';
    }
    try {
      final permission = requestPermission
          ? await requestContactsPermission()
          : await checkContactsPermission();
      if (!permission) {
        debugPrint('Contacts permission not granted.');
        return null;
      }

      // Collect all phone numbers belonging to this profile without duplicates
      final phones = <ContactPhone>[];
      final Set<String> seenPhones = {};

      void addPhoneNumber(String? raw, String label, {bool isPrimary = false}) {
        if (raw == null) return;
        final trimmed = raw.trim();
        if (trimmed.isEmpty) return;
        final clean = trimmed.replaceAll(RegExp(r'\D'), '');
        final key = clean.length >= 7 ? (clean.length >= 10 ? clean.substring(clean.length - 10) : clean) : clean;
        if (seenPhones.add(key.isNotEmpty ? key : trimmed)) {
          phones.add(ContactPhone(number: trimmed, label: label, isPrimary: isPrimary));
        }
      }

      // 1. Primary phone
      addPhoneNumber(scanned.phone, 'Mobile', isPrimary: true);

      // 2. Alternative phone
      addPhoneNumber(scanned.alternativePhone, 'Other');

      // 3. Additional phones (multi-phone profile support)
      for (final ap in scanned.additionalPhones) {
        String num = ap;
        String lbl = 'Mobile';
        if (ap.contains(':')) {
          final parts = ap.split(':');
          lbl = parts.first.trim();
          num = parts.sublist(1).join(':').trim();
        }
        addPhoneNumber(num, lbl.isNotEmpty ? lbl : 'Mobile');
      }

      // 4. WhatsApp & Landline
      if (scanned.whatsApp != null && scanned.whatsApp!.isNotEmpty) {
        addPhoneNumber(scanned.whatsApp, 'WhatsApp');
      }
      if (scanned.landline != null && scanned.landline!.isNotEmpty) {
        addPhoneNumber(scanned.landline, 'Work');
      }

      final emails = <ContactEmail>[];
      if (scanned.email.isNotEmpty) {
        emails.add(ContactEmail(address: scanned.email, label: 'Work'));
      }

      final websites = <ContactWebsite>[];
      if (scanned.website.isNotEmpty) {
        websites.add(ContactWebsite(url: scanned.website, label: 'Work'));
      }

      final addresses = <ContactAddress>[];
      if (scanned.address.isNotEmpty || (scanned.pinCode != null && scanned.pinCode!.isNotEmpty)) {
        final clean = ContactAddress.sanitizeAddressString(scanned.address);
        if (clean.isNotEmpty) {
          addresses.add(ContactAddress(
            address: clean,
            label: 'Work',
            postalCode: scanned.pinCode ?? '',
          ));
        }
      }

      final photoBytes = await resolvePhotoBytes(scanned);

      AppContact buildAppContact({
        required String id,
        String? fallbackDisplayName,
        String? fallbackCompany,
        String? fallbackJobTitle,
      }) {
        final displayName = scanned.name.isNotEmpty
            ? scanned.name
            : (fallbackDisplayName?.isNotEmpty == true
                ? fallbackDisplayName!
                : scanned.company);
        return AppContact(
          id: id,
          displayName: displayName,
          company: scanned.company.isNotEmpty ? scanned.company : fallbackCompany,
          jobTitle:
              scanned.designation.isNotEmpty ? scanned.designation : fallbackJobTitle,
          photo: photoBytes,
          phones: phones,
          emails: emails,
          websites: websites,
          addresses: addresses,
        );
      }

      // If we already have a mapped device contact ID, attempt to update that specific contact
      if (scanned.deviceContactId != null && scanned.deviceContactId!.trim().isNotEmpty) {
        try {
          final targetId = scanned.deviceContactId!.trim();
          final updatedId = await _updateNativeContact(
            contactId: targetId,
            appContact: buildAppContact(id: targetId),
            scanned: scanned,
            photoBytes: photoBytes,
          );
          if (updatedId != null) {
            debugPrint('📱 [ContactSaverService] Updated existing device contact $updatedId (${scanned.name} - ${scanned.company})');
            return updatedId;
          }
        } catch (e) {
          debugPrint('⚠️ [ContactSaverService] Error updating device contact by ID: $e');
        }
      }

      // Check if an existing contact in the device address book matches SAME phone AND SAME company
      final existingMatchingContact = await findExistingDeviceContact(
        phone: scanned.phone,
        company: scanned.company,
        name: scanned.name,
      );

      if (existingMatchingContact != null) {
        try {
          final appContact = buildAppContact(
            id: existingMatchingContact.id,
            fallbackDisplayName: existingMatchingContact.displayName,
            fallbackCompany: existingMatchingContact.company,
            fallbackJobTitle: existingMatchingContact.jobTitle,
          );
          final updatedId = await _updateNativeContact(
            contactId: existingMatchingContact.id,
            appContact: appContact,
            scanned: scanned,
            photoBytes: photoBytes,
          );
          if (updatedId != null) {
            debugPrint('📱 [ContactSaverService] Linked and updated existing matching device contact $updatedId');
            return updatedId;
          }
        } catch (e) {
          debugPrint('⚠️ [ContactSaverService] Error updating matching device contact ${existingMatchingContact.id}: $e');
        }
        return existingMatchingContact.id;
      }

      // New company profile or new contact -> Create a brand-new separate device contact
      final appContact = buildAppContact(id: '');
      final deviceContact = appContact.toDeviceContact();
      final preferredAccount = await resolvePreferredWritableAccount();
      final newId = await fc.FlutterContacts.create(
        deviceContact,
        account: preferredAccount,
      );
      if (photoBytes != null && newId.isNotEmpty) {
        await syncNativePhotoToGoogleRawContacts(newId, photoBytes);
        ContactPhotoService.cachePhoto(
          contactId: newId,
          phone: scanned.phone,
          photoBytes: photoBytes,
        );
      }
      debugPrint('📱 [ContactSaverService] Created new device contact for "${scanned.name}" (${scanned.company}) with ID: $newId and ${phones.length} phones');
      return newId.isNotEmpty ? newId : null;
    } catch (e) {
      debugPrint('Failed to save contact to device contacts: $e');
      return null;
    }
  }

  /// Finds an existing device contact matching BOTH normalized phone and company name
  static Future<AppContact?> findExistingDeviceContact({
    required String phone,
    required String company,
    String? name,
  }) async {
    if (kIsWeb) return null;
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 7) return null;
    final tail10 = cleanPhone.length >= 10 ? cleanPhone.substring(cleanPhone.length - 10) : cleanPhone;
    final targetCompany = company.trim().toLowerCase();
    final targetName = (name ?? '').trim().toLowerCase();

    try {
      final permitted = await checkContactsPermission();
      if (!permitted) return null;

      final deviceContacts = await fc.FlutterContacts.getAll(
        properties: fc.ContactProperties.all,
      );

      for (final dev in deviceContacts) {
        bool phoneMatched = false;
        for (final p in dev.phones) {
          final pDigits = p.number.replaceAll(RegExp(r'\D'), '');
          if (pDigits.endsWith(tail10) || cleanPhone == pDigits) {
            phoneMatched = true;
            break;
          }
        }
        if (!phoneMatched) continue;

        final devComp = dev.organizations.isNotEmpty ? (dev.organizations.first.name ?? '').trim().toLowerCase() : '';
        final devName = (dev.displayName ?? '').trim().toLowerCase();

        // 1. If company is specified on both, match company
        if (targetCompany.isNotEmpty && devComp.isNotEmpty) {
          if (devComp == targetCompany || devComp.contains(targetCompany) || targetCompany.contains(devComp)) {
            return AppContact.fromDeviceContact(dev);
          }
          // Different companies sharing the same phone number -> DO NOT MATCH!
          continue;
        }

        // 2. If company is missing, match by name
        if (targetName.isNotEmpty && devName.isNotEmpty && (devName == targetName || devName.contains(targetName) || targetName.contains(devName))) {
          return AppContact.fromDeviceContact(dev);
        }
      }
    } catch (e) {
      debugPrint('Error finding existing device contact: $e');
    }
    return null;
  }

  /// Checks if an exact duplicate contact exists in the device address book (same phone AND same company/details).
  static Future<bool> isDuplicate(String phone, String email, {String? company, String? name}) async {
    final existing = await findExistingDeviceContact(phone: phone, company: company ?? '', name: name);
    return existing != null;
  }

  /// Permanently deletes a device contact strictly using its deviceContactId.
  static Future<bool> deleteDeviceContact(String? deviceContactId) async {
    if (kIsWeb || deviceContactId == null || deviceContactId.trim().isEmpty) return false;
    try {
      final permitted = await checkContactsPermission();
      if (!permitted) return false;
      await fc.FlutterContacts.delete(deviceContactId.trim());
      debugPrint('📱 [ContactSaverService] Successfully deleted native device contact: $deviceContactId');
      return true;
    } catch (e) {
      debugPrint('⚠️ [ContactSaverService] Error deleting device contact: $e');
      return false;
    }
  }

  /// Generates a standard vCard v3.0 string representation of the scanned contact.
  static String buildVCardString(ScannedContactModel scanned) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:${scanned.name}');
    buffer.writeln('ORG:${scanned.company}');
    buffer.writeln('TITLE:${scanned.designation}');

    if (scanned.phone.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,VOICE:${scanned.phone}');
    }
    if (scanned.alternativePhone != null && scanned.alternativePhone!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK,VOICE:${scanned.alternativePhone}');
    }
    if (scanned.landline != null && scanned.landline!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=WORK,LANDLINE:${scanned.landline}');
    }
    if (scanned.whatsApp != null && scanned.whatsApp!.isNotEmpty) {
      buffer.writeln('TEL;TYPE=CELL,WHATSAPP:${scanned.whatsApp}');
    }
    if (scanned.email.isNotEmpty) {
      buffer.writeln('EMAIL;TYPE=PREF,INTERNET:${scanned.email}');
    }
    if (scanned.website.isNotEmpty) {
      buffer.writeln('URL;TYPE=WORK:${scanned.website}');
    }
    if (scanned.address.isNotEmpty) {
      final escapedAddress = scanned.address.replaceAll(',', '\\,');
      final pin = scanned.pinCode ?? '';
      buffer.writeln('ADR;TYPE=WORK:;;$escapedAddress;;;;$pin');
    }

    for (var link in scanned.socialLinks) {
      buffer.writeln('X-SOCIALPROFILE;TYPE=other:$link');
    }

    buffer.writeln('END:VCARD');
    return buffer.toString();
  }
}

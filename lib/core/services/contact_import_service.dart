import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/scanned_contact_model.dart';

class ContactImportService {
  /// Request permissions and load phone contacts in progressive batches.
  static Future<List<ScannedContactModel>> importPhoneContacts(
    List<ScannedContactModel> existingContacts, {
    Function(int totalCount)? onTotalCountDiscovered,
    Function(List<ScannedContactModel> batch)? onBatchLoaded,
    int batchSize = 50,
  }) async {
    if (kIsWeb) return [];
    try {
      final status = await Permission.contacts.status;
      if (!status.isGranted && !status.isLimited) {
        return [];
      }

      final deviceContacts = await fc.FlutterContacts.getAll(
        properties: fc.ContactProperties.all,
      );

      if (onTotalCountDiscovered != null) {
        onTotalCountDiscovered(deviceContacts.length);
      }

      final List<ScannedContactModel> allNewContacts = [];
      final List<ScannedContactModel> currentBatch = [];

      for (final devContact in deviceContacts) {
        final appC = AppContact.fromDeviceContact(devContact);
        if (appC.phones.isEmpty && appC.emails.isEmpty) continue;

        final phone = appC.primaryPhone;
        final otherPhones = appC.phones.where((p) => p.number.trim() != phone.trim()).toList();
        final altPhone = otherPhones.isNotEmpty ? otherPhones.first.number : '';
        final extraPhones = otherPhones.length > 1
            ? otherPhones.skip(1).map((p) => '${p.label}:${p.number}').toList()
            : <String>[];
        final email = appC.primaryEmail;

        String? photoPath;
        if (appC.photo != null && appC.photo!.isNotEmpty) {
          try {
            final base64Str = base64Encode(appC.photo!);
            photoPath = 'data:image/jpeg;base64,$base64Str';
          } catch (e) {
            debugPrint('Error encoding phone contact photo: $e');
          }
        }

        final modelId = 'phone_${appC.id}';

        final model = ScannedContactModel(
          id: modelId,
          name: appC.displayName,
          company: appC.company ?? '',
          designation: appC.jobTitle ?? '',
          phone: phone,
          alternativePhone: altPhone.isNotEmpty ? altPhone : null,
          additionalPhones: extraPhones,
          email: email,
          website: appC.websites.isNotEmpty ? appC.websites.first.url : '',
          address: appC.addresses.isNotEmpty ? appC.addresses.first.address : '',
          profileImage: photoPath,
          socialLinks: const [],
          source: 'phone',
          syncStatus: 'synced',
          isFavorite: appC.isFavorite,
          createdAt: DateTime.now(),
        );

        currentBatch.add(model);
        allNewContacts.add(model);

        if (currentBatch.length >= batchSize) {
          if (onBatchLoaded != null) {
            onBatchLoaded(List.from(currentBatch));
          }
          currentBatch.clear();
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }

      if (currentBatch.isNotEmpty && onBatchLoaded != null) {
        onBatchLoaded(List.from(currentBatch));
        currentBatch.clear();
      }

      return allNewContacts;
    } catch (e) {
      debugPrint('Exception during contact import: $e');
      return [];
    }
  }

  /// Permanently delete a contact from the native device address book.
  static Future<bool> deleteDeviceContact(String contactId, {String? phone}) async {
    try {
      final status = await Permission.contacts.status;
      if (!status.isGranted && !status.isLimited) return false;

      String rawId = contactId.startsWith('phone_')
          ? contactId.replaceFirst('phone_', '')
          : contactId;

      if (rawId.isNotEmpty) {
        try {
          await fc.FlutterContacts.delete(rawId);
          return true;
        } catch (_) {}
      }
    } catch (_) {}
    return false;
  }
}

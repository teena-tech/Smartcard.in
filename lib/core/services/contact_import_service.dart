import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/scanned_contact_model.dart';

class ContactImportService {
  /// Request permissions and load phone contacts in batches of 50.
  /// Deduplicates based on exact phone number or email match with existing contacts.
  static Future<List<ScannedContactModel>> importPhoneContacts(
    List<ScannedContactModel> existingContacts, {
    Function(List<ScannedContactModel> batch)? onBatchLoaded,
    int batchSize = 50,
  }) async {
    try {
      // Only CHECK status — never REQUEST here. The Contacts screen handles asking the user.
      final status = await Permission.contacts.status;
      if (!status.isGranted && !status.isLimited) {
        debugPrint('⚠️ Contacts permission not granted. Skipping phone contact import.');
        return [];
      }

      final bool flutterContactsPerm = await FlutterContacts.requestPermission(readonly: true);
      if (!flutterContactsPerm) {
        debugPrint('⚠️ FlutterContacts permission denied. Skipping phone contact import.');
        return [];
      }

      // Get contacts with properties, photos & thumbnails
      final List<Contact> phoneContacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
        withThumbnail: true,
        withAccounts: false,
      );

    final List<ScannedContactModel> allNewContacts = [];
    final List<ScannedContactModel> currentBatch = [];

    final existingPhones = existingContacts.map((e) {
      final p = _cleanPhone(e.phone);
      return p.length >= 10 ? p.substring(p.length - 10) : p;
    }).where((p) => p.isNotEmpty).toSet();
    final existingEmails = existingContacts.map((e) => e.email.toLowerCase()).where((e) => e.isNotEmpty).toSet();

    for (final contact in phoneContacts) {
      if (contact.phones.isEmpty && contact.emails.isEmpty) continue; // Skip empty contacts

      final phone = contact.phones.isNotEmpty ? contact.phones.first.normalizedNumber : '';
      final altPhone = contact.phones.length > 1 ? contact.phones[1].normalizedNumber : '';
      final email = contact.emails.isNotEmpty ? contact.emails.first.address : '';
      
      final cleanedPhone = _cleanPhone(phone);
      final tailPhone = cleanedPhone.length >= 10 ? cleanedPhone.substring(cleanedPhone.length - 10) : cleanedPhone;
      final cleanedEmail = email.toLowerCase();

      final name = contact.displayName.isNotEmpty
          ? contact.displayName
          : '${contact.name.first} ${contact.name.last}'.trim();
      final company = contact.organizations.isNotEmpty ? contact.organizations.first.company : '';
      final designation = contact.organizations.isNotEmpty ? contact.organizations.first.title : '';
      final website = contact.websites.isNotEmpty ? contact.websites.first.url : '';
      final address = contact.addresses.isNotEmpty ? contact.addresses.first.address : '';

      String? photoPath;
      final photoBytes = contact.photo ?? contact.thumbnail ?? contact.photoOrThumbnail;
      if (photoBytes != null && photoBytes.isNotEmpty) {
        try {
          final base64Str = base64Encode(photoBytes);
          photoPath = 'data:image/jpeg;base64,$base64Str';
        } catch (e) {
          debugPrint('Error encoding phone contact photo: $e');
        }
      }

      final modelId = 'phone_${contact.id}';

      // Check if duplicate / existing contact already present
      final existingIndex = existingContacts.indexWhere((e) {
        if (e.id == modelId) return true;
        final p = _cleanPhone(e.phone);
        final tailP = p.length >= 10 ? p.substring(p.length - 10) : p;
        if (tailPhone.isNotEmpty && tailP.isNotEmpty && tailP == tailPhone) return true;
        if (cleanedEmail.isNotEmpty && e.email.toLowerCase() == cleanedEmail) return true;
        return false;
      });

      if (existingIndex != -1) {
        final existing = existingContacts[existingIndex];
        final updated = existing.copyWith(
          name: name.isNotEmpty ? name : existing.name,
          company: company.isNotEmpty ? company : existing.company,
          designation: designation.isNotEmpty ? designation : existing.designation,
          phone: phone.isNotEmpty ? phone : existing.phone,
          alternativePhone: altPhone.isNotEmpty ? altPhone : existing.alternativePhone,
          email: email.isNotEmpty ? email : existing.email,
          website: website.isNotEmpty ? website : existing.website,
          address: address.isNotEmpty ? address : existing.address,
          profileImage: photoPath ?? existing.profileImage,
        );
        currentBatch.add(updated);
        allNewContacts.add(updated);
      } else {
        final model = ScannedContactModel(
          id: modelId,
          name: name,
          company: company,
          designation: designation,
          phone: phone,
          alternativePhone: altPhone.isNotEmpty ? altPhone : null,
          email: email,
          website: website,
          address: address,
          profileImage: photoPath,
          socialLinks: const [],
          source: 'phone',
          syncStatus: 'pending',
          isFavorite: false,
          createdAt: DateTime.now(),
        );

        currentBatch.add(model);
        allNewContacts.add(model);
      }

      if (cleanedPhone.isNotEmpty) existingPhones.add(cleanedPhone);
      if (cleanedEmail.isNotEmpty) existingEmails.add(cleanedEmail);

      // Deliver first 50 contacts immediately, then subsequent 50-contact batches
      if (currentBatch.length >= batchSize) {
        if (onBatchLoaded != null) {
          onBatchLoaded(List.from(currentBatch));
        }
        currentBatch.clear();
        // Brief pause to allow Flutter UI thread to render first batch instantly
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // Deliver remaining contacts in final batch
    if (currentBatch.isNotEmpty && onBatchLoaded != null) {
      onBatchLoaded(List.from(currentBatch));
      currentBatch.clear();
    }

    return allNewContacts;
    } catch (e) {
      debugPrint('⚠️ Exception during contact import gracefully caught: $e');
      return [];
    }
  }

  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'\D'), ''); // Strip non-numeric
  }

  /// Permanently delete a contact from the native device address book.
  static Future<bool> deleteDeviceContact(String contactId, {String? phone}) async {
    try {
      final bool permissionGranted = await FlutterContacts.requestPermission(readonly: false);
      if (!permissionGranted) {
        return false;
      }

      String rawId = contactId.startsWith('phone_')
          ? contactId.replaceFirst('phone_', '')
          : contactId;

      Contact? target;
      if (rawId.isNotEmpty) {
        try {
          target = await FlutterContacts.getContact(rawId);
        } catch (_) {}
      }

      if (target == null && phone != null && phone.trim().isNotEmpty) {
        final cleanTarget = _cleanPhone(phone);
        if (cleanTarget.length >= 10) {
          final tailTarget = cleanTarget.substring(cleanTarget.length - 10);
          final allContacts = await FlutterContacts.getContacts(withProperties: true);
          for (final c in allContacts) {
            for (final p in c.phones) {
              final pClean = _cleanPhone(p.normalizedNumber);
              if (pClean.length >= 10 && pClean.endsWith(tailTarget)) {
                target = c;
                break;
              }
            }
            if (target != null) break;
          }
        }
      }

      if (target != null) {
        await FlutterContacts.deleteContact(target);
        return true;
      }
    } catch (_) {}
    return false;
  }
}


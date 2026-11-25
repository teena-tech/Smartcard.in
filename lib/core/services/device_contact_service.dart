import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:permission_handler/permission_handler.dart';
import 'package:smartcard_flutter/features/contacts_screen/data/models/app_contact.dart';
import 'package:smartcard_flutter/core/services/contact_saver_service.dart';

class DeviceContactService {
  /// Stream to listen for real-time contact database changes from the Android OS
  Stream<void> get onDatabaseChange => fc.FlutterContacts.onDatabaseChange;

  /// Check contacts permission — NEVER shows OS dialog.
  /// Permission must be requested exclusively from ContactsScreen.
  Future<bool> requestPermission() async {
    return hasPermission();
  }

  /// Check if contacts permission is currently granted
  Future<bool> hasPermission() async {
    if (kIsWeb || (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux))) {
      return false;
    }
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }
      return await fc.FlutterContacts.permissions.has(fc.PermissionType.readWrite) ||
          await fc.FlutterContacts.permissions.has(fc.PermissionType.read);
    } catch (_) {
      return false;
    }
  }

  /// Fetch all contacts directly from Android Contacts Provider.
  /// Uses photoThumbnail only to prevent memory spikes on large contact lists.
  Future<List<AppContact>> fetchDeviceContacts({
    Map<String, List<String>> contactGroupNamesMap = const {},
    Map<String, List<String>> contactGroupIdsMap = const {},
  }) async {
    try {
      final bool permitted = await hasPermission();
      if (!permitted) {
        return [];
      }

      // Fetch contacts directly from Android Contacts Provider
      final deviceContacts = await fc.FlutterContacts.getAll(
        properties: fc.ContactProperties.all,
      );

      final List<AppContact> appContacts = deviceContacts.map((c) {
        final gNames = contactGroupNamesMap[c.id] ?? const [];
        final gIds = contactGroupIdsMap[c.id] ?? const [];
        return AppContact.fromDeviceContact(
          c,
          groupNames: gNames,
          groupIds: gIds,
        );
      }).toList();

      // Sort alphabetically
      appContacts.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      return appContacts;
    } catch (e) {
      debugPrint('Error fetching device contacts: $e');
      return [];
    }
  }

  /// Create a new contact directly in Android Contacts Provider
  Future<AppContact?> createContact(
    AppContact contact, {
    List<String> assignGroupIds = const [],
  }) async {
    try {
      final bool permitted = await hasPermission();
      if (!permitted) return null;

      final normalizedPhoto = (contact.photo != null && contact.photo!.isNotEmpty)
          ? ContactSaverService.normalizePhotoBytesForDevice(contact.photo!)
          : null;
      final normalizedContact = normalizedPhoto != null
          ? contact.copyWith(photo: normalizedPhoto)
          : contact;
      final fc.Contact newDeviceContact = normalizedContact.toDeviceContact();
      final preferredAccount = await ContactSaverService.resolvePreferredWritableAccount();
      final String newId = await fc.FlutterContacts.create(
        newDeviceContact,
        account: preferredAccount,
      );

      if (newId.isNotEmpty) {
        if (normalizedPhoto != null) {
          await ContactSaverService.syncNativePhotoToGoogleRawContacts(newId, normalizedPhoto);
        }
        // Assign to groups if requested
        if (assignGroupIds.isNotEmpty) {
          for (final gId in assignGroupIds) {
            try {
              await fc.FlutterContacts.groups.addContacts(
                groupId: gId,
                contactIds: [newId],
              );
            } catch (ge) {
              debugPrint('Error assigning contact $newId to group $gId: $ge');
            }
          }
        }

        // Retrieve created contact with fresh ID and details
        return await getContactById(newId) ?? contact.copyWith(id: newId, isDeviceContact: true);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating contact on Android: $e');
      return null;
    }
  }

  /// Update an existing contact directly in Android Contacts Provider
  Future<AppContact?> updateContact(
    AppContact contact, {
    List<String>? newGroupIds,
    List<String>? previousGroupIds,
  }) async {
    try {
      final bool permitted = await hasPermission();
      if (!permitted) return null;

      final existing = await fc.FlutterContacts.get(contact.id, properties: fc.ContactProperties.all);
      if (existing != null) {
        final normalizedPhoto = (contact.photo != null && contact.photo!.isNotEmpty)
            ? ContactSaverService.normalizePhotoBytesForDevice(contact.photo!)
            : null;
        final normalizedContact = normalizedPhoto != null
            ? contact.copyWith(photo: normalizedPhoto)
            : contact;
        final updated = normalizedContact.toDeviceContact(existing: existing);
        await fc.FlutterContacts.update(updated);
        if (normalizedPhoto != null) {
          await ContactSaverService.syncNativePhotoToGoogleRawContacts(contact.id, normalizedPhoto);
        }

        // Update group memberships if provided
        if (newGroupIds != null && previousGroupIds != null) {
          final toAdd = newGroupIds.where((id) => !previousGroupIds.contains(id)).toList();
          final toRemove = previousGroupIds.where((id) => !newGroupIds.contains(id)).toList();

          for (final gId in toAdd) {
            try {
              await fc.FlutterContacts.groups.addContacts(groupId: gId, contactIds: [contact.id]);
            } catch (_) {}
          }

          for (final gId in toRemove) {
            try {
              await fc.FlutterContacts.groups.removeContacts(groupId: gId, contactIds: [contact.id]);
            } catch (_) {}
          }
        }

        return await getContactById(contact.id) ?? contact;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating contact on Android: $e');
      return null;
    }
  }

  /// Delete contact directly from Android Contacts Provider
  Future<bool> deleteContact(String contactId) async {
    if (contactId.isEmpty) return false;

    try {
      final bool permitted = await hasPermission();
      if (!permitted) return false;

      await fc.FlutterContacts.delete(contactId);
      return true;
    } catch (e) {
      debugPrint('Error deleting contact from Android: $e');
      return false;
    }
  }

  /// Get single contact by ID with all properties and high-res photo directly from Android Contacts Provider
  Future<AppContact?> getContactById(String id) async {
    if (id.isEmpty) return null;

    try {
      final device = await fc.FlutterContacts.get(id, properties: fc.ContactProperties.all);
      if (device != null) {
        // Fetch groups for this contact
        List<fc.Group> groups = [];
        try {
          groups = await fc.FlutterContacts.groups.getOf(id);
        } catch (_) {}

        return AppContact.fromDeviceContact(
          device,
          groupNames: groups.map((g) => g.name).toList(),
          groupIds: groups.map((g) => g.id ?? '').where((gid) => gid.isNotEmpty).toList(),
        );
      }
    } catch (e) {
      debugPrint('Error getting contact $id: $e');
    }
    return null;
  }

  /// Launch native Android system contact editor dialog as a fallback
  Future<AppContact?> openNativeContactCreator({AppContact? initialData}) async {
    try {
      fc.Contact? initialContact;
      if (initialData != null) {
        initialContact = initialData.toDeviceContact();
      }

      final createdId = await fc.FlutterContacts.native.showCreator(contact: initialContact);
      if (createdId != null && createdId.isNotEmpty) {
        return await getContactById(createdId);
      }
    } catch (e) {
      debugPrint('Error opening native contact creator: $e');
    }
    return null;
  }
}

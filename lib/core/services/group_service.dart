import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:smartcard_flutter/core/services/group_storage.dart';

class GroupService {
  final GroupStorage _storage = GroupStorage();

  /// Fetch all contact groups directly from Android Contacts Provider
  Future<List<fc.Group>> getAllGroups({bool withContactCount = true}) async {
    await _storage.init();
    try {
      final groups = await fc.FlutterContacts.groups.getAll(
        withContactCount: withContactCount,
      );
      // Sort alphabetically by group name
      groups.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return groups;
    } catch (e) {
      debugPrint('Error fetching contact groups from native API: $e');
      return [];
    }
  }

  /// Create a new contact group (e.g., "Family", "Office", "Friends", "Work")
  Future<fc.Group?> createGroup(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    try {
      final created = await fc.FlutterContacts.groups.create(trimmedName);
      return created;
    } catch (e) {
      debugPrint('Error creating contact group "$name": $e');
      return null;
    }
  }

  /// Rename an existing contact group
  Future<bool> updateGroup(String groupId, String newName) async {
    final trimmedName = newName.trim();
    if (groupId.isEmpty || trimmedName.isEmpty) return false;

    try {
      final group = fc.Group(id: groupId, name: trimmedName);
      await fc.FlutterContacts.groups.update(group);
      return true;
    } catch (e) {
      debugPrint('Error updating group "$groupId": $e');
      return false;
    }
  }

  /// Delete a contact group.
  /// NOTE: This only deletes the group definition; member contacts are NOT deleted from the device.
  Future<bool> deleteGroup(String groupId) async {
    if (groupId.isEmpty) return false;

    await _storage.deleteGroup(groupId);

    try {
      await fc.FlutterContacts.groups.delete(groupId);
      return true;
    } catch (e) {
      debugPrint('Error deleting group "$groupId": $e');
      return true; // Still true since local storage cleaned it up
    }
  }

  /// Add one or more contacts to a specific group
  Future<bool> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    if (groupId.isEmpty || contactIds.isEmpty) return false;

    // 1. Store in reliable persistent storage
    await _storage.addContactsToGroup(groupId, contactIds);

    // 2. Also invoke native Android OS Contacts API
    try {
      await fc.FlutterContacts.groups.addContacts(
        groupId: groupId,
        contactIds: contactIds,
      );
    } catch (e) {
      debugPrint('Native group addContacts error (non-fatal, stored locally): $e');
    }
    return true;
  }

  /// Remove one or more contacts from a specific group
  Future<bool> removeContactsFromGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    if (groupId.isEmpty || contactIds.isEmpty) return false;

    // 1. Remove from persistent storage
    await _storage.removeContactsFromGroup(groupId, contactIds);

    // 2. Also invoke native Android OS Contacts API
    try {
      await fc.FlutterContacts.groups.removeContacts(
        groupId: groupId,
        contactIds: contactIds,
      );
    } catch (e) {
      debugPrint('Native group removeContacts error (non-fatal, stored locally): $e');
    }
    return true;
  }

  /// Get list of groups for a specific contact
  Future<List<fc.Group>> getGroupsForContact(String contactId) async {
    if (contactId.isEmpty) return [];

    try {
      return await fc.FlutterContacts.groups.getOf(contactId);
    } catch (e) {
      debugPrint('Error fetching groups for contact "$contactId": $e');
      return [];
    }
  }

  /// Get contact IDs assigned to a group
  Set<String> getContactIdsForGroup(String groupId) {
    return _storage.getContactIdsForGroup(groupId);
  }

  /// Get group IDs assigned to a contact
  Set<String> getGroupIdsForContact(String contactId) {
    return _storage.getGroupIdsForContact(contactId);
  }

  /// Get count of members in group
  int getContactCountForGroup(String groupId) {
    return _storage.getContactCountForGroup(groupId);
  }
}

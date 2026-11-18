import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../models/app_contact.dart';
import '../core/services/group_service.dart';
import '../core/services/group_storage.dart';

class GroupProvider extends ChangeNotifier {
  final GroupService _groupService = GroupService();
  final GroupStorage _groupStorage = GroupStorage();

  List<fc.Group> _groups = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<fc.Group> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalGroupsCount => _groups.length;

  /// Load all groups directly from Android Contacts Provider & persistent storage
  Future<void> loadGroups() async {
    if (_groups.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      await _groupStorage.init();
      _groups = await _groupService.getAllGroups(withContactCount: true);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load groups: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a new native contact group on the device
  Future<fc.Group?> createGroup(String name) async {
    try {
      final created = await _groupService.createGroup(name);
      if (created != null) {
        await loadGroups();
        return created;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Failed to create group: $e';
      notifyListeners();
      return null;
    }
  }

  /// Rename an existing group on the device
  Future<bool> renameGroup(String groupId, String newName) async {
    try {
      final success = await _groupService.updateGroup(groupId, newName);
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to rename group: $e';
      notifyListeners();
      return false;
    }
  }

  /// Delete a group from the device. Contacts are NOT deleted.
  Future<bool> deleteGroup(String groupId) async {
    try {
      final success = await _groupService.deleteGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        notifyListeners();
        await loadGroups();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to delete group: $e';
      notifyListeners();
      return false;
    }
  }

  /// Add contacts to a specific group
  Future<bool> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    try {
      final success = await _groupService.addContactsToGroup(
        groupId: groupId,
        contactIds: contactIds,
      );
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to add contacts to group: $e';
      notifyListeners();
      return false;
    }
  }

  /// Remove contacts from a specific group
  Future<bool> removeContactsFromGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    try {
      final success = await _groupService.removeContactsFromGroup(
        groupId: groupId,
        contactIds: contactIds,
      );
      if (success) {
        await loadGroups();
      }
      return success;
    } catch (e) {
      _errorMessage = 'Failed to remove contacts from group: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get list of groups for a specific contact
  Future<List<fc.Group>> getGroupsForContact(String contactId) async {
    return await _groupService.getGroupsForContact(contactId);
  }

  /// Filter all contacts belonging to a specific group ID
  List<AppContact> getMembersForGroup(String groupId, List<AppContact> allContacts) {
    final memberIds = _groupStorage.getContactIdsForGroup(groupId);
    return allContacts.where((c) => c.groupIds.contains(groupId) || memberIds.contains(c.id)).toList();
  }

  /// Get total count of contacts in a group
  int getMemberCount(String groupId, List<AppContact> allContacts) {
    return getMembersForGroup(groupId, allContacts).length;
  }

  /// Find group by ID
  fc.Group? findGroupById(String groupId) {
    try {
      return _groups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }
}
